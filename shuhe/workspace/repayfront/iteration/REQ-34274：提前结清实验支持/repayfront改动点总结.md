# repayfront应用改动点总结

> 基于PRD文档《提前结清实验支持需求》（v3.0）
> 文档ID: 414291549
> 需求优先级: P0
> 预计上线时间: 2026-Q2

---

## 一、核心改动概述

本次需求主要针对**提前结清流程**进行优化，核心目标：
1. 降低提前结清损失率
2. 支持AB实验和精细化运营
3. 增强风控能力和数据追踪能力

涉及**3个核心模块**，共**10+个改动点**

---

## 二、数据库改动（4个表）

### 2.1 白名单表优化（biz_map）

**表名**: `repayfront.biz_map`

**改动类型**: 字段新增

**新增字段**:
```sql
ALTER TABLE repayfront.biz_map
ADD COLUMN status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' COMMENT '白名单状态：ACTIVE-生效中，EXPIRED-已失效',
ADD COLUMN expired_at TIMESTAMP NULL COMMENT '失效时间',
ADD COLUMN expired_reason VARCHAR(200) NULL COMMENT '失效原因';
```

**新增索引**:
```sql
CREATE INDEX idx_status ON repayfront.biz_map(status);
CREATE INDEX idx_expired_at ON repayfront.biz_map(expired_at);
```

**改动点**:
- ✅ 支持白名单失效机制（status字段）
- ✅ 记录失效时间（expired_at）
- ✅ 记录失效原因（expired_reason）

---

### 2.2 白名单变更记录表（新建）

**表名**: `repayfront.biz_map_change_log`

**改动类型**: 新建表

**DDL**:
```sql
CREATE TABLE repayfront.biz_map_change_log (
    id BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
    user_id VARCHAR(50) NOT NULL COMMENT '用户ID',
    order_id VARCHAR(50) NOT NULL COMMENT '订单ID',
    change_type VARCHAR(20) NOT NULL COMMENT '变更类型：ADD-新增，EXPIRE-失效',
    change_reason VARCHAR(200) NOT NULL COMMENT '变更原因',
    source_system VARCHAR(50) NOT NULL COMMENT '来源系统',
    operator VARCHAR(50) NOT NULL COMMENT '操作人',
    created_by VARCHAR(150) NOT NULL DEFAULT 'SYS' COMMENT '创建人',
    updated_by VARCHAR(150) NOT NULL DEFAULT 'SYS' COMMENT '更新人',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (id),
    INDEX idx_user_order (user_id, order_id),
    INDEX idx_change_type (change_type),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='白名单变更记录表';
```

**改动点**:
- ✅ 记录白名单新增操作
- ✅ 记录白名单失效操作
- ✅ 支持变更历史追溯
- ✅ 包含失效原因字段，便于数据分析

---

### 2.3 预审规则表（新建）

**表名**: `repayfront.pre_audit_policy`

**改动类型**: 新建表

**DDL**:
```sql
CREATE TABLE repayfront.pre_audit_policy (
    id BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
    rule_id VARCHAR(50) NOT NULL COMMENT '规则ID（唯一标识）',
    rule_name VARCHAR(100) NOT NULL COMMENT '规则名称',
    rule_type VARCHAR(20) NOT NULL COMMENT '规则类型：FIXED-固定规则，CUSTOM-可配置规则',
    priority INT NOT NULL COMMENT '优先级（数字越小优先级越高，固定规则优先级1-10，可配置规则优先级11-100）',
    rule_condition TEXT NOT NULL COMMENT '规则条件（JSON格式，存储规则特征配置）',
    status VARCHAR(20) NOT NULL DEFAULT 'ONLINE' COMMENT '规则状态：ONLINE-上线，OFFLINE-下线',
    description VARCHAR(500) NULL COMMENT '规则描述',
    created_by VARCHAR(150) NOT NULL DEFAULT 'SYS' COMMENT '创建人',
    updated_by VARCHAR(150) NOT NULL DEFAULT 'SYS' COMMENT '更新人',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (id),
    UNIQUE KEY uk_rule_id (rule_id),
    INDEX idx_rule_type (rule_type),
    INDEX idx_priority (priority),
    INDEX idx_status (status),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='预审规则表';
```

**改动点**:
- ✅ 参考审核规则表（audit_policy）设计
- ✅ 支持固定规则和可配置规则
- ✅ 支持优先级排序
- ✅ 规则条件使用JSON格式存储
- ✅ 提供接口给外部维护预审规则
- ✅ 简化状态管理：只有ONLINE和OFFLINE两种状态
- ✅ 创建时默认ONLINE，删除时更新为OFFLINE（不需要单独的上线下线接口）

**预置固定规则数据**:
```sql
-- 规则1：白名单匹配
INSERT INTO repayfront.pre_audit_policy (rule_id, rule_name, rule_type, priority, rule_condition, description) VALUES
('WHITELIST', '白名单匹配', 'FIXED', 1, '{"field":"whitelist","operator":"in","value":"whitelist_table"}', '白名单状态为ACTIVE或NULL的用户，无需审核');

-- 规则2：轻资产订单
INSERT INTO repayfront.pre_audit_policy (rule_id, rule_name, rule_type, priority, rule_condition, description) VALUES
('SEAMLESS_V2', '轻资产订单', 'FIXED', 2, '{"field":"assetBank","operator":"in","value":["seamless_v2"]}', '符合轻资产订单特征的用户，无需审核');

-- 规则3：随借随还订单
INSERT INTO repayfront.pre_audit_policy (rule_id, rule_name, rule_type, priority, rule_condition, description) VALUES
('ANY_REPAY', '随借随还订单', 'FIXED', 3, '{"field":"product","operator":"equals","value":"ANY_REPAY"}', '随借随还订单类型的用户，无需审核');

-- 规则4：当天订单审核通过后二次发起
INSERT INTO repayfront.pre_audit_policy (rule_id, rule_name, rule_type, priority, rule_condition, description) VALUES
('SAME_DAY_APPROVED', '当天订单审核通过后二次发起', 'FIXED', 4, '{"field":"auditRecord","operator":"sameDayApproved"}', '当天订单提前结清审核通过后，二次发起提前结清，无需审核');
```

---

### 2.4 预审记录表（新建）

**表名**: `repayfront.pre_audit_record`

**改动类型**: 新建表

**DDL**:
```sql
CREATE TABLE repayfront.pre_audit_record (
    id BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
    flow_id VARCHAR(50) NOT NULL COMMENT '业务流水号',
    user_id VARCHAR(50) NOT NULL COMMENT '用户ID',
    order_id VARCHAR(50) NOT NULL COMMENT '订单ID',
    audit_result VARCHAR(20) NOT NULL COMMENT '预审结果：NEED_AUDIT-需要审核，NO_NEED-无需审核',
    match_rule_id VARCHAR(50) NULL COMMENT '匹配的规则ID',
    match_type VARCHAR(20) NOT NULL COMMENT '匹配类型：WHITELIST-白名单，RULE-规则',
    created_by VARCHAR(150) NOT NULL DEFAULT 'SYS' COMMENT '创建人',
    updated_by VARCHAR(150) NOT NULL DEFAULT 'SYS' COMMENT '更新人',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (id),
    UNIQUE KEY uk_flow_id (flow_id),
    INDEX idx_user_order (user_id, order_id),
    INDEX idx_audit_result (audit_result),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='预审记录表';
```

**改动点**:
- ✅ 记录预审结果（需要审核/无需审核）
- ✅ 关联业务流水号flowId
- ✅ 记录匹配的规则ID
- ✅ 记录匹配类型（白名单/规则）
- ✅ 支持AB实验数据追踪

---

### 2.5 审核记录表优化（audit_record）

**涉及文件**:
- `RepayAuditServiceImpl.java`
- `RepayAuditSubmitService.java`

**改动点**:

#### 3.1.1 白名单失效机制
- ✅ **新增功能**: 支持白名单失效（逻辑删除）
- ✅ **触发方式**: 业务通过`/whiteList/update`接口通知repayfront
- ✅ **数据来源**: 业务系统主动推送失效名单
- ✅ **执行逻辑**:
  1. 业务系统调用`/whiteList/update`接口，传入`contained=false`
  2. 接口将白名单记录状态更新为"已失效"（status=EXPIRED）
  3. 记录失效时间（expiredAt）和失效原因（expiredReason）
  4. 记录变更信息到白名单变更表（biz_map_change_log）

#### 3.1.2 /whiteList/update接口改造（核心改动）

**当前实现**（物理删除）:
```java
// RepayAuditServiceImpl.java:169-188
@Override
public void whiteListUpdate(String uid, boolean contained, String operator, String whiteType) {
    BizMapCode bizMapCode = BizMapCode.UID_WHITE_LIST;
    if(StringUtils.isNotBlank(whiteType)){
        bizMapCode = BizMapCode.valueOf(whiteType);
    }
    if (checkWhiteListContained(uid,bizMapCode) == contained) {
        return;
    }
    if (contained) {
        bizMapRepository.insertOne(BizMapPo.builder()
                .keyCode(bizMapCode)
                .value(uid)
                .updatedBy(operator)
                .build()
        );
    } else {
        bizMapRepository.deleteOneByKeyAndValue(bizMapCode, uid); // ❌ 物理删除
    }
}
```

**改造后实现**（逻辑删除）:
```java
@Override
public void whiteListUpdate(String uid, boolean contained, String operator, String whiteType) {
    BizMapCode bizMapCode = BizMapCode.UID_WHITE_LIST;
    if(StringUtils.isNotBlank(whiteType)){
        bizMapCode = BizMapCode.valueOf(whiteType);
    }

    // ✅ 查询当前状态（兼容历史数据：status为NULL也视为ACTIVE）
    Optional<BizMapPo> currentOpt = bizMapRepository.selectOneByKeyAndValue(
        BizMapPo.builder().keyCode(bizMapCode).value(uid).build());
    boolean currentContained = currentOpt.isPresent() &&
        (currentOpt.get().getStatus() == null || currentOpt.get().getStatus() == BizMapStatus.ACTIVE);

    if (currentContained == contained) {
        return; // 状态未变化，无需处理
    }

    if (contained) {
        // ✅ 新增白名单，状态为ACTIVE
        bizMapRepository.insertOne(BizMapPo.builder()
                .keyCode(bizMapCode)
                .value(uid)
                .status(BizMapStatus.ACTIVE) // ✅ 新增状态字段
                .updatedBy(operator)
                .build());

        // ✅ 记录变更日志
        bizMapChangeLogRepository.insertOne(BizMapChangeLogPo.builder()
                .userId(uid)
                .changeType(BizMapChangeType.ADD)
                .changeReason("手动操作")
                .sourceSystem(SourceSystem.MANUAL)
                .operator(operator)
                .build());
    } else {
        // ✅ 逻辑删除：更新状态为EXPIRED
        bizMapRepository.updateStatus(BizMapPo.builder()
                .keyCode(bizMapCode)
                .value(uid)
                .status(BizMapStatus.EXPIRED)
                .expiredAt(new Date())
                .expiredReason("手动操作")
                .updatedBy(operator)
                .build());

        // ✅ 记录变更日志
        bizMapChangeLogRepository.insertOne(BizMapChangeLogPo.builder()
                .userId(uid)
                .changeType(BizMapChangeType.EXPIRE)
                .changeReason("手动操作")
                .sourceSystem(SourceSystem.MANUAL)
                .operator(operator)
                .build());
    }
}
```

**涉及改动**:
1. `RepayAuditServiceImpl.java:169-188` - 修改`whiteListUpdate`方法（物理删除→逻辑删除）
2. `BizMapDao.java:87-93` - 新增`updateStatus`方法替代`deleteOneByKeyAndValue`
3. `TBizMap.java` - 新增`status`、`expiredAt`、`expiredReason`字段
4. `biz_map`表 - 新增`status`、`expired_at`、`expired_reason`字段（见2.1）
5. 新增`BizMapChangeLogRepository`和`BizMapChangeLogService`处理变更日志
6. 新增枚举类：`BizMapStatus`、`BizMapChangeType`、`SourceSystem`

#### 3.1.3 白名单状态判断优化
- ✅ **优化点**: 预审时需判断白名单状态（ACTIVE/EXPIRED）
- ✅ **历史数据兼容**: status为NULL时，默认为ACTIVE（兼容历史数据）
- ✅ **判断逻辑**:
  ```java
  // 现有逻辑（RepayAuditServiceImpl.buildCommonRepayAuditConfig:193-197）
  // 只判断白名单是否存在，未判断状态
  boolean uidWhiteList = bizMapRepository.selectOneByKeyAndValue(BizMapCode.UID_WHITE_LIST, uid).isPresent();

  // 新增逻辑（兼容历史数据）
  // 1. 查询白名单时，status为NULL的记录也包含在内（兼容历史数据）
  // 2. biz_map表中已失效的白名单（status=EXPIRED）不再自动通过审核
  Optional<BizMapPo> optional = bizMapRepository.selectOneByKeyAndValue(
      BizMapPo.builder()
          .keyCode(BizMapCode.UID_WHITE_LIST)
          .value(uid)
          .build());

  // ✅ 兼容历史数据：status为NULL时，默认为ACTIVE
  boolean uidWhiteList = optional.isPresent() &&
      (optional.get().getStatus() == null || optional.get().getStatus() == BizMapStatus.ACTIVE);
  ```

**SQL查询优化**:
```sql
-- 查询白名单时需兼容历史数据（status为NULL）
SELECT * FROM biz_map
WHERE key = 'UID_WHITE_LIST'
  AND value = 'uid'
  AND (status = 'ACTIVE' OR status IS NULL);  -- ✅ 兼容历史数据
```

**代码改动位置**:
- `RepayAuditServiceImpl.java:193-197` - `buildCommonRepayAuditConfig`方法
- `BizMapDao.java:60-75` - `selectOneByKeyAndValue`方法需兼容status为NULL的情况
- `IBizMapRepository.java` - 方法保持不变，查询逻辑兼容NULL值

---

### 3.2 预审规则配置化模块

**改动类型**: 功能新增（逻辑优化）

**改动点**:

#### 3.2.1 固定规则（不可删除、不可调整顺序）
- ✅ **规则1**: 白名单匹配（status=ACTIVE或status为NULL的用户，无需审核）
- ✅ **规则2**: 轻资产订单（符合轻资产订单特征的用户，无需审核）
- ✅ **规则3**: 随借随还订单（随借随还订单类型的用户，无需审核）
- ✅ **规则4**: 当天订单审核通过后二次发起（当天订单提前结清审核通过后，二次发起提前结清，无需审核）

#### 3.2.2 可配置规则（支持自定义）
- ✅ **规则特征**: 信用评分、订单金额、逾期天数、账期、定价等
- ✅ **规则动作**: 无需审核、需要审核
- ✅ **顺序调整**: 支持拖拽调整匹配顺序（在固定规则之后）
- ✅ **配置约束**:
  - 可配置规则数量上限：20条
  - 每条规则只支持单个特征条件
  - 如需多个条件判断，可创建多条规则并按优先级匹配

#### 3.2.3 规则匹配逻辑
- ✅ **匹配顺序**: 固定规则1 → 固定规则2 → 固定规则3 → 可配置规则1 → 可配置规则2 → ...
- ✅ **匹配策略**: 匹配到第一条规则后停止匹配，执行该规则的动作
- ✅ **默认逻辑**: 所有规则都不匹配 → 默认需要审核

**代码改动位置**:
- `RepayAuditSubmitService.java:77-108` - `preSubmitStatusByPreSubmit`方法
- 需要新增规则匹配引擎（读取配置中心的预审规则配置）

**核心伪代码**:
```java
public RepayElementPreSubmitOutput.PreSubmitStatus preSubmitStatusByPreSubmit(
    String uid, RepayAuditElementInfo info, CommonRepayAuditConfig config) {

    // 0. ✅ 初始化预审记录上下文（包含flowId）
    String flowId = info.getFlowId(); // 从请求参数中获取

    // 1. 固定规则1：白名单匹配（需判断status=ACTIVE或NULL）
    if (isWhitelistActive(uid)) {
        // ✅ 保存预审记录到pre_audit_record表
        savePreAuditRecord(flowId, uid, info, "WHITELIST", "NO_NEED", "WHITELIST");
        return PreSubmitStatus.AUTO_PASS;
    }

    // 2. 固定规则2：轻资产订单
    if (isSeamlessV2(assetBank)) {
        // ✅ 保存预审记录到pre_audit_record表
        savePreAuditRecord(flowId, uid, info, "SEAMLESS_V2", "NO_NEED", "WHITELIST");
        return PreSubmitStatus.AUTO_PASS;
    }

    // 3. 固定规则3：随借随还订单
    if (ProductEnum.ANY_REPAY.name().equals(product)) {
        // ✅ 保存预审记录到pre_audit_record表
        savePreAuditRecord(flowId, uid, info, "ANY_REPAY", "NO_NEED", "WHITELIST");
        return PreSubmitStatus.AUTO_PASS;
    }

    // 4. ✅ 固定规则4：当天订单审核通过后二次发起（新增）
    if (isSameDayApproved(uid, info.getRepayElementNo())) {
        // ✅ 保存预审记录到pre_audit_record表
        savePreAuditRecord(flowId, uid, info, "SAME_DAY_APPROVED", "NO_NEED", "RULE");
        return PreSubmitStatus.AUTO_PASS;
    }

    // 5. 可配置规则（从pre_audit_policy表读取）
    List<PreAuditPolicy> rules = loadPreAuditRulesFromDB();
    for (PreAuditPolicy rule : rules) {
        if (matchRule(uid, info, rule)) {
            // ✅ 保存预审记录到pre_audit_record表
            savePreAuditRecord(flowId, uid, info, rule.getRuleId(),
                rule.getRuleAction(), "RULE");
            return rule.getRuleAction() == PreAuditRuleAction.AUTO_PASS
                ? PreSubmitStatus.AUTO_PASS
                : PreSubmitStatus.MANUAL_AUDIT;
        }
    }

    // 6. ✅ 默认逻辑：需要审核（保存预审记录）
    savePreAuditRecord(flowId, uid, info, null, "NEED_AUDIT", "DEFAULT");
    return PreSubmitStatus.MANUAL_AUDIT;
}

/**
 * ✅ 保存预审记录到pre_audit_record表
 */
private void savePreAuditRecord(String flowId, String uid, RepayAuditElementInfo info,
                                 String matchRuleId, String auditResult, String matchType) {
    PreAuditRecordPo record = PreAuditRecordPo.builder()
        .flowId(flowId)
        .userId(uid)
        .orderId(info.getRepayElementNo())
        .auditResult(auditResult) // NEED_AUDIT or NO_NEED
        .matchRuleId(matchRuleId) // 匹配的规则ID
        .matchType(matchType) // WHITELIST, RULE, DEFAULT
        .build();

    preAuditRecordRepository.insert(record);
}
```

---

### 3.3 审核记录表改造模块

**改动类型**: 字段新增 + 逻辑改造

**改动点**:

#### 3.3.1 实体类改造

**TAuditRecord.java** - 新增字段：
```java
@Data
@Builder
public class TAuditRecord {
    private Long id;

    // ✅ 新增字段
    private String flowId;          // 业务流水号

    private String userId;
    private String orderId;         // 还款元素号
    private AuditStatus auditStatus; // PENDING, ACCEPTED, REJECTED

    // ✅ 新增字段
    private String matchRuleId;     // 匹配的审核规则ID

    private String auditor;         // 审核人
    private Date auditTime;         // 审核时间
    private Date auditFinishTime;   // 审核完成时间
    private String auditComment;    // 审核意见

    private String createdBy;
    private String updatedBy;
    private Date createdAt;
    private Date updatedAt;
}
```

#### 3.3.2 审核提交接口改造

**RepayAuditController.java**:
```java
@PostMapping("/submit")
@ApiOperation("还款审核提交")
public RepayAuditSubmitResp repayAuditSubmit(@RequestBody @Valid RepayAuditSubmitReq req) {

    String flowId = req.getFlowId(); // ✅ 从请求参数获取flowId

    // 审核判断（✅传递flowId）
    RepayAuditResult result = repayAuditService.repayAuditSubmit(
        req.getUid(),
        flowId,  // ✅ 传递flowId
        req.getRepayElementNo(),
        req.getAuditAction(),
        req.getAuditComment()
    );

    return buildSuccessResp(result);
}
```

**RepayAuditSubmitReq.java**:
```java
public class RepayAuditSubmitReq {
    private String uid;             // 用户ID
    private String flowId;          // ✅ 业务流水号（必填）
    private String repayElementNo;  // 还款元素号
    private AuditAction auditAction; // 审核动作：ACCEPT-通过，REJECT-拒绝
    private String auditComment;    // 审核意见
}
```

#### 3.3.3 审核Service层改造

**RepayAuditServiceImpl.java**:
```java
@Override
public RepayAuditResult repayAuditSubmit(String uid, String flowId, String repayElementNo,
                                         AuditAction auditAction, String auditComment) {

    // 1. 查询审核规则（现有逻辑）
    AuditPolicyPo policy = auditPolicyService.matchPolicy(uid, repayElementNo);

    // 2. 构建审核记录
    TAuditRecord record = TAuditRecord.builder()
        .flowId(flowId)                      // ✅ 设置flowId
        .userId(uid)
        .orderId(repayElementNo)
        .auditStatus(AuditStatus.PENDING)
        .matchRuleId(policy != null ? policy.getRuleId() : null)  // ✅ 设置匹配的规则ID
        .auditor(getCurrentUserId())
        .auditTime(new Date())
        .build();

    // 3. 根据审核动作更新状态
    if (auditAction == AuditAction.ACCEPT) {
        record.setAuditStatus(AuditStatus.ACCEPTED);
        record.setAuditFinishTime(new Date());
    } else if (auditAction == AuditAction.REJECT) {
        record.setAuditStatus(AuditStatus.REJECTED);
        record.setAuditFinishTime(new Date());
    }
    record.setAuditComment(auditComment);

    // 4. 保存审核记录
    auditRecordRepository.insert(record);

    return buildResult(record);
}
```

**核心改动点**:
- ✅ 新增flowId参数，传递到Service层
- ✅ 审核记录中保存flowId字段
- ✅ 审核记录中保存matchRuleId字段（从匹配的审核规则中获取）
- ✅ 实现预审→审核全流程数据关联

**详细设计文档**: [审核记录表改造说明.md](./审核记录表改造说明.md)

---

## 四、数据流转图（更新版）

```
用户点击提前结清按钮
    ↓
前端生成flowId
    ↓
前端：调用/repayAudit/preSubmit接口（✅传递flowId）
    ↓
后端：预审判断
    ↓
后端：✅ 保存预审记录到pre_audit_record表（含flowId）
    ↓
    ├─ 无需审核 → 挽留判断 → 还款支付
    └─ 需要审核 → 用户确认提交审核
                 ↓
                 前端：调用/repayAudit/submit接口（✅传递flowId）
                 ↓
                 后端：审核判断
                 ↓
                 后端：✅ 保存审核记录到audit_record表（含flow_id + match_rule_id）
                 ↓
                 ├─ 审核通过 → 挽留判断 → 还款支付
                 └─ 审核拒绝 → 结束
还款支付
    ↓
完成提前结清
```

---

## 五、枚举值新增

### 5.1 白名单状态枚举（BizMapStatus）
```java
public enum BizMapStatus {
    ACTIVE("生效中"),
    EXPIRED("已失效");
}
```

### 5.2 变更类型枚举（BizMapChangeType）
```java
public enum BizMapChangeType {
    ADD("新增"),
    EXPIRE("失效");
}
```

### 5.3 预审结果枚举（PreAuditResult）
```java
public enum PreAuditResult {
    NEED_AUDIT("需要审核"),
    NO_NEED("无需审核");
}
```

### 5.4 匹配类型枚举（MatchType）
```java
public enum MatchType {
    WHITELIST("白名单"),
    RULE("规则");
}
```

### 5.5 来源系统枚举（SourceSystem）
```java
public enum SourceSystem {
    BUSINESS_PLAN("经营计划系统"),
    MANUAL("手动操作"),
    SYSTEM("系统自动");
}
```

---

## 五、接口改动

### 5.1 新增接口（预审规则管理）

参考审核规则接口，提供预审规则的CRUD接口：

| 接口名称      | 请求方式                            | 说明                                    | 优先级 |
| --------- | ------------------------------- | ------------------------------------- | --- |
| 预审规则列表查询  | GET /preAuditPolicy/list        | 查询预审规则列表（支持分页、状态筛选，包含规则详情）            | P0  |
| 预审规则新增/更新 | POST /preAuditPolicy/save       | 新增或更新预审规则（仅限可配置规则，通过operation_type区分） | P0  |
| 预审规则删除    | DELETE /preAuditPolicy/{ruleId} | 删除预审规则（仅限可配置规则，删除时更新为OFFLINE）         | P0  |
| 预审记录查询    | GET /preAuditRecord/list        | 查询预审记录结果（支持分页）                        | P0  |
| 白名单变更记录查询 | GET /whiteListChangeLog/list    | 查询白名单变更历史                             | P0  |

**接口说明**：
- ✅ 创建规则时默认status=ONLINE（上线）
- ✅ 删除规则时实际是更新status=OFFLINE（下线），不是物理删除
- ✅ 不需要单独的上线/下线接口
- ✅ 列表查询接口返回展开的规则条件（feature_key、compare_op、tag_value）
- ✅ 新增/更新接口合并为一个接口，通过operation_type字段区分操作类型
- ✅ 新增/更新接口支持批量操作（rules列表）
- ✅ 优先级调整通过更新接口的priority字段实现
- ✅ 运算符字段名：compareOp（Compare Operator）

**接口示例**：

```java
/**
 * 预审规则Controller
 */
@RestController
@RequestMapping("/preAuditPolicy")
public class PreAuditPolicyController {

    /**
     * 查询预审规则列表（包含规则详情）
     */
    @GetMapping("/list")
    public PreAuditPolicyListResp list(@RequestBody PreAuditPolicyListReq req) {
        // 查询逻辑
        // 1. 支持按rule_type筛选（FIXED/CUSTOM）
        // 2. 支持按status筛选（ONLINE/OFFLINE）
        // 3. 按priority升序排序返回
        // 4. ✅ 返回展开的规则条件（feature_key、operator、tag_value）
    }

    /**
     * 新增/更新预审规则（合并接口）
     */
    @PostMapping("/save")
    public PreAuditPolicySaveResp save(@RequestBody @Valid PreAuditPolicySaveReq req) {
        // 1. 根据operation_type判断是CREATE还是UPDATE
        // 2. CREATE: 校验rule_type必须为CUSTOM，priority必须>=11
        // 3. UPDATE: 校验rule_id对应的rule_type必须为CUSTOM
        // 4. ✅ 支持更新priority字段实现优先级调整
        // 5. 插入或更新pre_audit_policy表
    }

    /**
     * 删除预审规则（仅限可配置规则）
     */
    @DeleteMapping("/{ruleId}")
    public PreAuditPolicyDeleteResp delete(@PathVariable String ruleId) {
        // 1. 校验rule_id对应的rule_type必须为CUSTOM
        // 2. 固定规则（FIXED）不允许删除
        // 3. 物理删除pre_audit_policy表记录
    }
}
```

### 5.2 修改接口

#### 5.2.1 /repayAudit/preSubmit 接口改造

**接口路径**: `POST /repayAudit/preSubmit`

**改动点**:
1. ✅ 新增flowId参数（必填）
2. ✅ 新增账务校验逻辑（在预审之前）
3. ✅ **新增预审记录落库（pre_audit_record表）**

**请求示例**:
```java
POST /repayAudit/preSubmit
{
  "uid": "123456",
  "bizSerial": "TQJQ_20260228120000_abc123", // ✅ flowId
  "repayElementPreSubmitReqList": [
    {
      "repayCategory": "STAGE",
      "repayElementNo": "order_001"
    }
  ]
}
```

**响应示例**:
```java
{
  "repayElementPreSubmitRespList": [
    {
      "repayCategory": "STAGE",
      "repayElementNo": "order_001",
      "status": "AUTO_PASS" // 或 MANUAL_AUDIT
    }
  ]
}
```

**核心实现**:
```java
@PostMapping("/preSubmit")
@ApiOperation("还款审核预提交")
public RepayAuditPreSubmitResp repayAuditPreSubmit(@RequestBody @Valid RepayAuditPreSubmitReq req) {

    String flowId = req.getBizSerial(); // ✅ flowId

    // 1. ✅ 账务校验（在预审之前）
    RepayCheckResult checkResult = repayCheckService.check(req.getUid(), req.getRepayElementNo());
    if (!checkResult.isSuccess()) {
        // 记录账务校验埋点
        saveRepayCheckLog(flowId, req.getUid(), req.getRepayElementNo(), checkResult);
        // 返回校验失败
        return buildFailResp(checkResult.getFailReason());
    }
    // 记录账务校验成功埋点
    saveRepayCheckLog(flowId, req.getUid(), req.getRepayElementNo(), checkResult);

    // 2. 预审判断（现有逻辑+✅新增预审记录落库）
    List<RepayAuditElementInfo> repayAuditElementInfoList = req.getRepayElementPreSubmitReqList().stream()
        .map(item -> modelMapper.map(item, RepayAuditElementInfo.class))
        .collect(Collectors.toList());

    List<RepayElementPreSubmitOutput> outputList = repayAuditService.repayAuditPreSubmit(
        req.getUid(),
        flowId, // ✅ 传递flowId
        repayAuditElementInfoList
    );

    // 3. ✅ 注意：预审记录已在repayAuditPreSubmit方法中保存到pre_audit_record表

    return buildSuccessResp(outputList);
}
```

**Service层实现**:
```java
@Service
public class RepayAuditServiceImpl implements IRepayAuditService {

    @Autowired
    private PreAuditRecordRepository preAuditRecordRepository; // ✅ 新增

    @Override
    public List<RepayElementPreSubmitOutput> repayAuditPreSubmit(
        String uid, String flowId, List<RepayAuditElementInfo> repayAuditElementInfoList) {

        CommonRepayAuditConfig config = buildCommonRepayAuditConfig(uid);

        return repayAuditElementInfoList.stream()
            .map(info -> {
                // 预审判断
                PreSubmitStatus status = repayAuditSubmitService.preSubmitStatusByPreSubmit(
                    uid, info, config);

                // ✅ 保存预审记录到pre_audit_record表
                savePreAuditRecord(flowId, uid, info, status);

                return RepayElementPreSubmitOutput.builder()
                    .repayCategory(info.getRepayCategory())
                    .repayElementNo(info.getRepayElementNo())
                    .status(status)
                    .build();
            })
            .collect(Collectors.toList());
    }

    /**
     * ✅ 保存预审记录
     */
    private void savePreAuditRecord(String flowId, String uid, RepayAuditElementInfo info, PreSubmitStatus status) {
        PreAuditRecordPo record = PreAuditRecordPo.builder()
            .flowId(flowId)
            .userId(uid)
            .orderId(info.getRepayElementNo())
            .auditResult(status == PreSubmitStatus.AUTO_PASS ? "NO_NEED" : "NEED_AUDIT")
            .matchRuleId(determineMatchRuleId(info)) // 根据预审结果确定匹配的规则ID
            .matchType(determineMatchType(info)) // WHITELIST or RULE or DEFAULT
            .build();

        preAuditRecordRepository.insert(record);
    }
}
```

#### 5.2.2 /repayAudit/submit 接口改造

---

## 六、关键改动点总结

### 6.1 核心改动（P0）

| 序号 | 改动项 | 改动类型 | 优先级 | 涉及表/文件 |
|------|--------|----------|--------|------------|
| 1 | 白名单接口逻辑删除 | 接口改造 | P0 | RepayAuditServiceImpl.java, BizMapDao.java |
| 2 | 白名单变更记录 | 功能新增 | P0 | biz_map_change_log |
| 3 | 预审规则表 | 新建表 | P0 | pre_audit_policy |
| 4 | 预审规则管理接口 | 接口新增 | P0 | PreAuditPolicyController.java |
| 5 | 预审记录表 | 新建表 | P0 | pre_audit_record |
| 6 | 预审规则配置化 | 功能新增 | P0 | RepayAuditSubmitService.java |
| 7 | flowId全流程关联 | 功能新增 | P0 | audit_record, repayment_flow, pre_audit_record |
| 8 | 账务校验流程调整 | 流程优化 | P0 | RepayAuditController.java |
| 9 | 全流程数据埋点 | 功能新增 | P0 | 多个表 |

### 6.2 次要改动（P1）

| 序号 | 改动项 | 改动类型 | 优先级 | 涉及表/文件 |
|------|--------|----------|--------|------------|
| 1 | 挽留分支记录 | 功能新增 | P1 | 后端埋点表 |

---

## 七、风险评估与注意事项

### 7.1 风险点

| 风险项 | 风险等级 | 影响 | 应对措施 |
|--------|----------|------|----------|
| flowId生成重复 | 中 | 数据追踪混乱 | 前端生成规则保证唯一性 |
| 预审规则配置错误 | 高 | 审核流程异常 | 配置校验+灰度发布+规则测试 |
| 账务校验接口性能问题 | 中 | 用户体验下降 | 接口性能优化+超时控制 |
| 白名单接口逻辑删除异常 | 中 | 失效失败 | 接口异常处理+日志监控 |
| 预审规则优先级冲突 | 中 | 规则匹配异常 | 优先级唯一性校验+界面提示 |

### 7.2 兼容性说明

- ✅ 现有审核逻辑保持不变，仅新增字段
- ✅ 现有挽留逻辑保持不变，仅新增埋点
- ✅ 现有支付流程保持不变
- ⚠️ 需要前端配合：flowId生成、前端埋点

### 7.3 测试要点

1. **白名单接口逻辑删除测试**
   - 新增白名单功能正常
   - 失效白名单（逻辑删除）功能正常
   - 白名单状态判断正确（ACTIVE/EXPIRED）
   - 变更记录正确落库

2. **预审规则测试**
   - 固定规则正确匹配
   - 可配置规则正确匹配
   - 规则顺序正确执行

3. **flowId追踪测试**
   - flowId正确生成
   - 全流程数据正确关联
   - 数据完整性校验

4. **账务校验测试**
   - 校验流程正确执行
   - 失败场景正确处理
   - 埋点数据正确记录

---

## 八、开发排期建议

| 阶段 | 任务 | 预计工时 | 依赖 |
|------|------|----------|------|
| 第一阶段 | 数据库表创建与迁移 | 2人日 | - |
| 第二阶段 | 白名单接口逻辑删除改造 | 2人日 | 数据库表 |
| 第三阶段 | 预审规则配置化开发 | 5人日 | 配置中心 |
| 第四阶段 | flowId全流程关联 | 4人日 | 数据库表 |
| 第五阶段 | 账务校验流程调整 | 3人日 | - |
| 第六阶段 | 数据埋点开发 | 3人日 | - |
| 第七阶段 | 联调测试 | 5人日 | 前端配合 |
| 第八阶段 | 灰度发布与验证 | 3人日 | 测试完成 |

**总计**: 约27人日（约5.5周）

---

## 九、文档状态

✅ 改动点总结完成
📝 文档版本: v1.1
📅 创建时间: 2026-02-28
📅 更新时间: 2026-03-02
👤 创建人: AI助手
🔄 更新内容: 接口优化 - 预审规则接口调整（删除2个接口，合并2个接口，改造1个接口）

---

## 附录A：现有代码分析

根据现有代码分析，**当天订单提前结清审核通过后，二次发起提前结清无需审核的控制逻辑**是在**【预审】阶段**实现的，具体位置：

**文件**: `RepayAuditSubmitService.java:77-108`
**方法**: `preSubmitStatusByPreSubmit`
**关键逻辑**:
```java
// 第89行：查询最新审核记录
Optional<AuditRecordPo> optional = auditRecordRepositoryProxy.selectOneUpToDate(uid, info.getRepayElementNo());

// 第94-96行：核心判断逻辑
if (po.getAuditStatus() != AuditStatus.REJECTED) {
    return calcPreSubmitStatus(po.getAuditStatus());
}

// 第158-169行：审核状态映射
// ACCEPTED（审核通过）→ AUTO_PASS（自动通过）
```

**本次需求**: 保持该逻辑不变，但需在预审记录表中记录flowId，实现全流程追踪。

---

## 附录B：白名单失效机制详细说明

### B.1 实现方案

**采用方案**: 业务系统通过`/whiteList/update`接口主动失效白名单

**核心改动**: 将接口从**物理删除**改造为**逻辑删除**

**方案优势**:
1. ✅ **实时性更好**: 业务系统可以实时失效白名单
2. ✅ **实现更简单**: 无需开发定时任务，只需改造现有接口
3. ✅ **可靠性更高**: 直接依赖业务系统调用
4. ✅ **追溯性更强**: 每次接口调用都记录操作人和原因

### B.2 接口改造详细说明

**改造前（物理删除）**:
```java
// RepayAuditServiceImpl.java:186
bizMapRepository.deleteOneByKeyAndValue(bizMapCode, uid); // ❌ 直接删除记录
```

**改造后（逻辑删除）**:
```java
// 1. 更新白名单状态为EXPIRED
bizMapRepository.updateStatus(BizMapPo.builder()
    .keyCode(bizMapCode)
    .value(uid)
    .status(BizMapStatus.EXPIRED)
    .expiredAt(new Date())
    .expiredReason("手动操作")
    .updatedBy(operator)
    .build());

// 2. 记录变更日志
bizMapChangeLogRepository.insertOne(BizMapChangeLogPo.builder()
    .userId(uid)
    .changeType(BizMapChangeType.EXPIRE)
    .changeReason("手动操作")
    .sourceSystem(SourceSystem.MANUAL)
    .operator(operator)
    .build());
```

### B.3 接口调用示例

**新增白名单**:
```bash
POST /repayAudit/whiteList/update
{
  "uid": "123456",
  "contained": true,
  "operator": "admin",
  "whiteType": "UID_WHITE_LIST"
}
# 结果：
# 1. biz_map表：插入新记录，status=ACTIVE
# 2. biz_map_change_log表：记录ADD变更
```

**失效白名单**:
```bash
POST /repayAudit/whiteList/update
{
  "uid": "123456",
  "contained": false,
  "operator": "admin",
  "whiteType": "UID_WHITE_LIST"
}
# 结果：
# 1. biz_map表：更新status=EXPIRED, expired_at=当前时间, expired_reason="手动操作"
# 2. biz_map_change_log表：记录EXPIRE变更
```

### B.4 数据一致性保障

**状态判断优化（兼容历史数据）**:
```java
// 现有逻辑：只判断白名单是否存在
boolean uidWhiteList = bizMapRepository.selectOneByKeyAndValue(
    BizMapPo.builder()
        .keyCode(BizMapCode.UID_WHITE_LIST)
        .value(uid)
        .build()).isPresent();

// 优化后：判断白名单是否存在且状态为ACTIVE或NULL（兼容历史数据）
Optional<BizMapPo> optional = bizMapRepository.selectOneByKeyAndValue(
    BizMapPo.builder()
        .keyCode(BizMapCode.UID_WHITE_LIST)
        .value(uid)
        .build());

// ✅ 兼容历史数据：status为NULL时，默认为ACTIVE
boolean uidWhiteList = optional.isPresent() &&
    (optional.get().getStatus() == null || optional.get().getStatus() == BizMapStatus.ACTIVE);
```

**SQL查询优化**:
```sql
-- 查询白名单时需兼容历史数据（status为NULL）
SELECT * FROM biz_map
WHERE key = 'UID_WHITE_LIST'
  AND value = ?
  AND (status = 'ACTIVE' OR status IS NULL);  -- ✅ 兼容历史数据
```

---

## 附录B：数据流图

```
用户点击提前结清按钮
    ↓
前端生成flowId
    ↓
前端：记录点击埋点
    ↓
🆕 后端：还款账务校验
    ↓ (校验通过)
🆕 后端：记录账务校验埋点
    ↓
预审环节
    ↓
🆕 后端：记录预审结果到pre_audit_record表
    ↓
    ├─ 无需审核 → 挽留判断
    └─ 需要审核 → 用户确认提交审核
                 ↓
                 审核环节
                 ↓
                 🆕 后端：记录审核结果到audit_record表（含flowId）
                 ↓
                 ├─ 审核通过 → 挽留判断
                 └─ 审核拒绝 → 结束
挽留判断
    ↓
🆕 前端：记录挽留分支名称
    ↓
还款支付页
    ↓
🆕 前端：记录页面曝光埋点
    ↓
用户提交还款
    ↓
🆕 前端：记录提交按钮埋点
    ↓
🆕 后端：记录还款流水到repayment_flow表（含flowId）
    ↓
完成提前结清
```

---

**END**