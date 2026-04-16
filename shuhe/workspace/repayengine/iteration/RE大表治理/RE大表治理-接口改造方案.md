# Paimon分区策略调整及接口改造方案

## 文档信息

| 项目名称 | RE大表治理 - Paimon分区策略调整 |
|---------|-------------------------------|
| 文档版本 | v1.0 |
| 创建日期 | 2026-02-06 |
| 作者 | Claude Code |
| 状态 | 设计阶段 |

---

## 变更概述

### 核心变更

1. **Paimon表分区策略调整**
   - ❌ 原方案: 按时间分区 `PARTITIONED BY (DATE_FORMAT(create_time, 'yyyy-MM-dd'))`
   - ✅ 新方案: 按uid前8位分区 `PARTITIONED BY (SUBSTRING(uid, 1, 8))`

2. **接口参数调整**
   - ✅ 所有需要查询归档数据的接口,uid必须为必传参数
   - ✅ queryArchivedData=true时,强制校验uid不能为空

---

## 一、Paimon表分区设计调整

### 1.1 分区策略变更

#### 原方案(按时间分区)

```sql
-- ❌ 原设计方案(废弃)
CREATE TABLE paimon_catalog.repayengine.deduct_bill (
    id BIGINT,
    uid VARCHAR(64),
    ...
    create_time TIMESTAMP(3),

    PRIMARY KEY (id, create_time) NOT ENFORCED
) PARTITIONED BY (DATE_FORMAT(create_time, 'yyyy-MM-dd'))
WITH (
    'file.format' = 'parquet',
    'compression.codec' = 'zstd',
    'bucket' = '16'
);
```

**问题分析**:
- 按时间分区,查询时需要扫描所有时间分区
- uid查询场景占90%+,时间分区不匹配查询模式
- 无法利用分区裁剪优化

#### 新方案(按uid前8位分区)

```sql
-- ✅ 新设计方案
CREATE TABLE paimon_catalog.repayengine.deduct_bill (
    id BIGINT,
    uid VARCHAR(64),
    ...
    create_time TIMESTAMP(3),

    PRIMARY KEY (id, uid) NOT ENFORCED
) PARTITIONED BY (SUBSTRING(uid, 1, 8))
WITH (
    'file.format' = 'parquet',
    'compression.codec' = 'zstd',
    'bucket' = '16',
    'changelog-producer' = 'input',
    'full-compaction.delta-commits' = '10'
);
```

**优势**:
- ✅ 查询时直接定位到单个分区(按uid查询)
- ✅ 分区裁剪效率高,查询性能优
- ✅ 符合业务查询模式(uid查询占90%+)

### 1.2 分区数量估算

**uid前8位分区数量**:
- uid格式: `timestamp(13位) + random(4位)` = 17位
- 前8位: 时间戳前8位(秒级时间戳)
- 理论分区数: 最多 `99999999` 个(实际远小于此)
- 实际活跃分区: 约 `365天 × 86400秒 = 31,536,000` 个(理论最大值)

**实际评估**:
- 按当前用户量(uid去重): 约 1000万用户
- 前8位重复率: 约 10-100个uid共享同一前8位
- 实际分区数: 约 10万 - 100万个分区

### 1.3 分区管理策略

#### 分区创建
```sql
-- Paimon自动创建分区,无需手动创建
-- 插入数据时自动根据uid前8位分配到对应分区
```

#### 分区过期
```sql
-- 删除2年前的分区
ALTER TABLE paimon_catalog.repayengine.deduct_bill
DROP PARTITIONS WHERE partition < SUBSTRING(DATE_FORMAT(NOW() - INTERVAL 24 MONTH, 'yyyyMMdd'), 1, 8);
```

---

## 二、接口改造方案

### 2.1 接口改造总览

| 接口 | Controller | Request | uid必传 | queryArchivedData | 改造优先级 |
|------|-----------|---------|---------|-------------------|-----------|
| 1. 查询还款申请记录 | DataManageController.queryRepayApply | QueryRepayApplyReq | ✅ 已有 | 新增 | P0 |
| 2. 查询扣款处理记录 | DataManageController.queryDeductBill | QueryDeductBillReq | ❌ 无 | 新增 | P0 |
| 3. 查询提前结清返现记录 | DataManageController.queryRefundBill | QueryRefundBillReq | ✅ 已有 | 新增 | P1 |
| 4. 查询返现信息 | DataManageController.queryRebackInfo | QueryRebackInfoReq | ✅ 已有 | 新增 | P1 |
| 5. 查询还款申请结果 | RepayApplyController.repayApplyResult | RepayApplyQueryRequest | ❌ 无 | 新增 | P2 |

### 2.2 接口详细改造设计

#### 接口1: queryRepayApply (还款申请记录查询)

**当前状态**:
```java
// ✅ uid已经必传
@ApiModelProperty("uid")
@NotNull(message = "uid 不能为空")
private String uid;
```

**改造方案**:
```java
@EqualsAndHashCode(callSuper = true)
@Getter
@Setter
@ApiModel(description = "还款申请记录查询请求定义")
public class QueryRepayApplyReq extends BasePagingReq {

    @ApiModelProperty("uid")
    @NotNull(message = "uid 不能为空")
    private String uid;

    // ... 其他原有字段 ...

    /**
     * 是否查询归档数据
     * true: 查询MySQL + StarRocks(Paimon)
     * false: 仅查询MySQL
     */
    @ApiModelProperty(value = "是否查询归档数据", example = "false")
    private Boolean queryArchivedData = false;
}
```

**接口评估**:
- ✅ uid已是必传,无需额外校验
- ✅ 新增queryArchivedData参数,默认false
- ⚠️ 需修改Service层,根据queryArchivedData参数路由查询

---

#### 接口2: queryDeductBill (扣款处理记录查询) ⚠️ **重点改造**

**当前状态**:
```java
// ❌ uid非必传(无uid字段)
@Getter
@Setter
@ApiModel(description = "扣款处理记录查询请求定义")
public class QueryDeductBillReq extends BasePagingReq {

    @ApiModelProperty("流水号「repayengine生成」")
    private String repayApplyNo;

    @ApiModelProperty("流水号list，repayApplyNo参数为空时有效，有效时分页相关参数无效")
    private List<String> repayApplyNoList;

    // ❌ 无uid字段
}
```

**改造方案**:
```java
@EqualsAndHashCode(callSuper = true)
@Getter
@Setter
@ApiModel(description = "扣款处理记录查询请求定义")
public class QueryDeductBillReq extends BasePagingReq {

    @ApiModelProperty("用户id(查询归档数据时必传)")
    private String uid;  // ✅ 新增uid字段

    @ApiModelProperty("流水号「repayengine生成」")
    private String repayApplyNo;

    @ApiModelProperty("流水号list，repayApplyNo参数为空时有效，有效时分页相关参数无效")
    private List<String> repayApplyNoList;

    /**
     * 是否查询归档数据
     * ⚠️ 当queryArchivedData=true时,uid必须传值
     */
    @ApiModelProperty(value = "是否查询归档数据(queryArchivedData=true时uid必传)", example = "false")
    private Boolean queryArchivedData = false;
}
```

**Service层校验逻辑**:
```java
public PagingResult<DeductBillVo> queryDeductBill(QueryDeductBillReq req) {
    // ✅ 校验: queryArchivedData=true时,uid必传
    if (Boolean.TRUE.equals(req.getQueryArchivedData()) && StringUtils.isBlank(req.getUid())) {
        throw new IllegalArgumentException("查询归档数据时,uid不能为空");
    }

    // 根据queryArchivedData参数路由查询
    if (Boolean.FALSE.equals(req.getQueryArchivedData())) {
        // 仅查询MySQL
        return queryFromMySQL(req);
    } else {
        // 查询MySQL + StarRocks(Paimon)
        return queryFromBothSources(req);
    }
}
```

**兼容性说明**:
- ✅ 默认queryArchivedData=false,不影响现有调用方
- ✅ 仅通过repayApplyNo查询时,可不传uid
- ⚠️ queryArchivedData=true时,必须传uid

---

#### 接口3: queryRefundBill (提前结清返现记录查询)

**当前状态**:
```java
// ✅ uid已经必传
@ApiModelProperty(value = "用户id", required = true)
@NonNull
private String uid;
```

**改造方案**:
```java
@Data
@ApiModel(description = "提前结清还款返现记录查询请求定义")
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class QueryRefundBillReq extends BasePagingReq {
    @ApiModelProperty(value = "用户id", required = true)
    @NonNull
    private String uid;

    // ... 其他原有字段 ...

    /**
     * 是否查询归档数据
     */
    @ApiModelProperty(value = "是否查询归档数据", example = "false")
    private Boolean queryArchivedData = false;
}
```

**接口评估**:
- ✅ uid已是必传,无需额外校验
- ✅ 新增queryArchivedData参数,默认false

---

#### 接口4: queryRebackInfo (返现信息查询)

**当前状态**:
```java
// ✅ uid已经必传
@ApiModelProperty(value = "用户id" , required = true)
@NotBlank(message = "用户标识不能为空")
private String uid;
```

**改造方案**:
```java
@Setter
@Getter
@Builder
@ApiModel(description = "还款返现记录查询请求定义")
@NoArgsConstructor
@AllArgsConstructor
public class QueryRebackInfoReq {

    @ApiModelProperty(value = "用户id" , required = true)
    @NotBlank(message = "用户标识不能为空")
    private String uid;

    // ... 其他原有字段 ...

    /**
     * 是否查询归档数据
     */
    @ApiModelProperty(value = "是否查询归档数据", example = "false")
    private Boolean queryArchivedData = false;
}
```

**接口评估**:
- ✅ uid已是必传,无需额外校验
- ✅ 新增queryArchivedData参数,默认false

---

#### 接口5: RepayApplyController.repayApplyResult (查询还款申请结果)

**当前状态**:
```java
// ❌ 需要查看RepayApplyQueryRequest定义
// 需确认是否有uid字段
```

**改造建议**:
- 需要查看RepayApplyQueryRequest定义
- 如果无uid字段,需新增uid字段
- queryArchivedData=true时,uid必传

---

### 2.3 Service层查询路由逻辑

#### 统一查询路由器

```java
@Service
public class ArchiveQueryService {

    @Autowired
    @Qualifier("mysqlJdbcTemplate")
    private JdbcTemplate mysqlJdbcTemplate;

    @Autowired
    @Qualifier("starRocksJdbcTemplate")
    private JdbcTemplate starRocksJdbcTemplate;

    /**
     * 查询扣款账单(支持归档数据)
     */
    public PagingResult<DeductBillVo> queryDeductBill(QueryDeductBillReq req) {

        // ✅ 校验: queryArchivedData=true时,uid必传
        if (Boolean.TRUE.equals(req.getQueryArchivedData()) && StringUtils.isBlank(req.getUid())) {
            throw new IllegalArgumentException("查询归档数据时,uid不能为空");
        }

        if (Boolean.FALSE.equals(req.getQueryArchivedData())) {
            // 只查MySQL (热数据)
            return queryFromMySQL(req);
        }

        // 查询MySQL + StarRocks (热数据 + 归档数据)
        return queryFromBothSources(req);
    }

    /**
     * 从MySQL查询热数据(90天内)
     */
    private PagingResult<DeductBillVo> queryFromMySQL(QueryDeductBillReq req) {
        String sql = buildMySQLQuery(req);
        // 查询逻辑...
    }

    /**
     * 从MySQL和StarRocks查询并合并
     */
    private PagingResult<DeductBillVo> queryFromBothSources(QueryDeductBillReq req) {

        // 1. 查询MySQL热数据 (90天内)
        List<DeductBillVo> hotData = queryHotDataFromMySQL(req);

        // 2. 查询StarRocks归档数据 (90天前, 按uid前8位分区裁剪)
        List<DeductBillVo> archiveData = queryArchiveDataFromStarRocks(req);

        // 3. 合并去重
        Map<String, DeductBillVo> merged = new LinkedHashMap<>();
        hotData.forEach(vo -> merged.put(vo.getDeductBillNo(), vo));
        archiveData.forEach(vo -> merged.putIfAbsent(vo.getDeductBillNo(), vo));

        // 4. 排序分页
        List<DeductBillVo> result = new ArrayList<>(merged.values()).stream()
            .sorted(Comparator.comparing(DeductBillVo::getCreateTime).reversed())
            .collect(Collectors.toList());

        // 分页逻辑...
        return PagingResult.of(result);
    }

    /**
     * 构建StarRocks查询SQL (利用分区裁剪)
     */
    private String buildStarRocksQuery(QueryDeductBillReq req) {
        // ✅ 关键: 利用uid前8位进行分区裁剪
        String uidPrefix = req.getUid().substring(0, 8);

        StringBuilder sql = new StringBuilder(
            "SELECT * FROM paimon_catalog.repayengine.deduct_bill " +
            "WHERE SUBSTRING(uid, 1, 8) = '" + uidPrefix + "'"  // ✅ 分区裁剪
        );

        if (StringUtils.isNotBlank(req.getRepayApplyNo())) {
            sql.append(" AND repay_apply_no = ?");
        }

        return sql.toString();
    }
}
```

---

## 三、查询性能优化

### 3.1 分区裁剪效果

#### 查询场景1: 按uid查询

```sql
-- ✅ 直接定位到单个分区,性能最优
SELECT * FROM paimon_catalog.repayengine.deduct_bill
WHERE SUBSTRING(uid, 1, 8) = '20240206'  -- 分区裁剪
  AND uid = '202402061234567abcd';
```

**性能**:
- 扫描分区数: 1个
- 查询延迟: < 100ms

#### 查询场景2: 按时间范围查询

```sql
-- ⚠️ 需要扫描多个分区,性能较差
SELECT * FROM paimon_catalog.repayengine.deduct_bill
WHERE create_time >= '2024-01-01'
  AND create_time < '2024-02-01';
```

**性能**:
- 扫描分区数: 约100万个(所有可能的前8位组合)
- 查询延迟: > 5秒
- ⚠️ 不推荐这种查询方式

**建议**:
- 按时间范围查询时,强制要求uid参数
- 或者在MySQL中查询,不使用归档数据

### 3.2 查询路由策略

| 查询条件 | 路由策略 | 说明 |
|---------|---------|------|
| uid存在 + queryArchivedData=true | MySQL + StarRocks | 利用分区裁剪,性能优 |
| uid存在 + queryArchivedData=false | MySQL only | 仅查询热数据 |
| uid不存在 + queryArchivedData=true | ❌ 抛异常 | 强制要求uid |
| 按时间范围查询(无uid) | MySQL only | ⚠️ 不查归档数据 |

---

## 四、实施计划

### 4.1 Phase 1: Request对象改造 (1周)

**任务清单**:
- [ ] QueryDeductBillReq 新增uid字段
- [ ] 所有Request对象新增queryArchivedData字段
- [ ] 更新Swagger文档

### 4.2 Phase 2: Service层改造 (2周)

**任务清单**:
- [ ] 实现ArchiveQueryService
- [ ] 实现queryArchivedData参数校验逻辑
- [ ] 实现MySQL + StarRocks联合查询
- [ ] 实现结果合并去重逻辑

### 4.3 Phase 3: Paimon表创建 (1周)

**任务清单**:
- [ ] 创建Paimon表(按uid前8位分区)
- [ ] 配置Flink CDC同步
- [ ] 验证分区裁剪效果

### 4.4 Phase 4: 测试与灰度 (2周)

**任务清单**:
- [ ] 单元测试
- [ ] 集成测试
- [ ] 性能测试
- [ ] 灰度发布

---

## 五、风险与缓解

### 5.1 风险点

| 风险 | 影响 | 概率 | 缓解措施 |
|------|------|------|----------|
| uid前8位分区过多,管理复杂 | 高 | 中 | 定期清理旧分区,监控分区数量 |
| 按时间范围查询性能差 | 中 | 高 | queryArchivedData=true时强制要求uid |
| uid必传导致调用方改造 | 中 | 中 | 提供迁移期,queryArchivedData默认false |
| 分区裁剪不生效 | 高 | 低 | POC阶段充分测试 |

### 5.2 兼容性保证

**向后兼容**:
- ✅ queryArchivedData默认false,不影响现有调用方
- ✅ 新增uid字段为可选(仅queryArchivedData=true时必传)
- ✅ 仅查询MySQL时,逻辑不变

**向前兼容**:
- ✅ 预留扩展字段
- ✅ 支持未来按其他维度分区

---

## 六、附录

### 6.1 Paimon表DDL脚本

```sql
-- deduct_bill (按uid前8位分区)
CREATE TABLE paimon_catalog.repayengine.deduct_bill (
    id BIGINT,
    repay_apply_no VARCHAR(64),
    uid VARCHAR(64),
    deduct_amount DECIMAL(10,2),
    deduct_status VARCHAR(20),
    create_time TIMESTAMP(3),
    update_time TIMESTAMP(3),
    ext_info STRING,

    PRIMARY KEY (id, uid) NOT ENFORCED
) PARTITIONED BY (SUBSTRING(uid, 1, 8))
WITH (
    'file.format' = 'parquet',
    'compression.codec' = 'zstd',
    'compression.level' = '1',
    'bucket' = '16',
    'changelog-producer' = 'input',
    'full-compaction.delta-commits' = '10'
);

-- repay_apply (按uid前8位分区)
CREATE TABLE paimon_catalog.repayengine.repay_apply (
    id BIGINT,
    repay_apply_no VARCHAR(64),
    uid VARCHAR(64),
    repay_amount DECIMAL(10,2),
    repay_status VARCHAR(20),
    create_time TIMESTAMP(3),
    update_time TIMESTAMP(3),
    ext_info STRING,

    PRIMARY KEY (id, uid) NOT ENFORCED
) PARTITIONED BY (SUBSTRING(uid, 1, 8))
WITH (
    'file.format' = 'parquet',
    'compression.codec' = 'zstd',
    'compression.level' = '1',
    'bucket' = '16',
    'changelog-producer' = 'input',
    'full-compaction.delta-commits' = '10'
);

-- 其他表同理...
```

### 6.2 接口改造检查清单

- [ ] QueryDeductBillReq 新增uid + queryArchivedData
- [ ] QueryRepayApplyReq 新增queryArchivedData
- [ ] QueryRefundBillReq 新增queryArchivedData
- [ ] QueryRebackInfoReq 新增queryArchivedData
- [ ] RepayApplyQueryRequest 新增uid + queryArchivedData
- [ ] Service层校验逻辑实现
- [ ] 查询路由逻辑实现
- [ ] 单元测试编写

---

**文档结束**