# 优化背景

## 存在大表

| 库名           | 表名                          | 大小       | 清理逻辑     |
| ------------ | --------------------------- | -------- | -------- |
| repayengine  | deduct_bill                 | 2.661 TB | 终态数据保留两年 |
| repayengine  | repay_apply                 | 718 GB   | 终态数据保留两年 |
| repayengine  | repayment_bill              | 445 GB   | 保留两年     |
| repayengine  | repay_apply_stage_plan_item | 410 GB   | 保留两年     |
| repayengine  | repayment_stage_plan_item   | 369 GB   | 保留两年     |
| repayengine  | repay_trial_bill            | 295 GB   | 保留15天    |
| repayengine  | repay_apply_pay_item        | 273 GB   | 保留两年     |
| repayengine  | repayengine.clearing_bill   | 211 GB   | -        |
| repayengine  | repayment_income_bill       | 240 GB   | -        |
| repayengine  | refund_bill                 | 40 GB    | -        |
| repayenginea | deduct_bill                 | 644.6 GB | 失败保留60天  |
| repayenginea | repay_trial_bill            | 417.8 GB | -        |
| repayenginea | repay_apply                 | 240.7 GB | 失败保留60天  |
| repayenginea | repayment_bill              | 105.4 GB | 保留60天    |
| repayenginea | repay_apply_stage_plan_item | 70.1 GB  | 保留60天    |
| repayenginea | repayment_stage_plan_item   | 66.4 GB  | 保留60天    |
| repayenginea | repay_apply_pay_item        | 57.9 GB  | -        |
| repayenginea | repayment_income_bill       | 10.2 GB  | -        |

**大表危害:**
- OnlineDDL 困难，影响线上业务
- 存储空间大，成本高

## 大表使用情况

| 接口                                        | 数据库表                                                                                                                           |
| ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| **DataManageController.queryDeductBill**  | `deduct_bill`<br>`repayment_stage_plan_item` (通过 RepaymentBill 关联查询)                                                           |
| **DataManageController.queryRebackInfo**  | `refund_bill`<br>`rebate_bill`                                                                                                 |
| **DataManageController.queryRefundBill**  | `refund_bill`                                                                                                                  |
| **DataManageController.queryRepayApply**  | `repay_apply`<br>`repay_apply_stage_plan_item` (关联查询)                                                                          |
| **RepayApplyController.repayApplyResult** | `repay_apply`<br>`repay_apply_stage_plan_item`<br>`repay_apply_pay_item`<br>`refund_bill` (查询返现信息)<br>`rebate_bill` (查询优惠返现信息) |

## 接口调用分析

### RepayApplyController.repayApplyResult
| requestUri | r_e | total_req | month_req_in_3 | month_req_in_3_6 | month_req_out_6 |
| --- | --- | --- | --- | --- | --- |
| "/repayengine/repay/apply_result" | "autodeduct" | 11898 | 11898 | 0 | 0 |
| "/repayengine/repay/apply_result" | "accountingoperation" | 2954044 | 2938034 | 478 | 1043 |
| "/repayengine/repay/apply_result" | "channelcore" | 243219 | 171071 | 66351 | 0 |
| "/repayengine/repay/apply_result" | "tradeorder" | 1789 | 1277 | 211 | 301 |
| "/repayengine/repay/apply_result" | "hbloandeal" | 10079 | 10079 | 0 | 0 |

**接口路径:** `/repayengine/repay/apply_result`
**请求方法:** GET
**接口状态:** 已上线 (ONLINE)

**请求参数 (Query):**
```json
{
  "bizSerial": "提交流水号(还款申请传入)",
  "repayApplyNo": "流水号(repayEngine生成)"
}
```

**根据参数分析改动点:**
- ❌ **没有 uid 参数** - 无法直接通过 uid 进行高效查询
- ❌ **没有时间范围参数** - 无法通过时间范围判断是否需要查询归档数据
- ⚠️ **需要通过 bizSerial/repayApplyNo 关联 repay_apply 表获取 uid** - 建议增加 uid 参数或上游改造传递 uid
- ✅ **调用量集中在3个月内数据** - 通过日志分析，大部分请求都是热数据，可先查询热数据，未命中再查归档

---

### DataManageController.queryRepayApply
| requestUri                                 | r_e               | total_req | req_with_time | req_with_out_time | month_in_req_3 | month_in_req_6 | month_out_req_6 |
| ------------------------------------------ | ----------------- | --------- | ------------- | ----------------- | -------------- | -------------- | --------------- |
| /repayengine/data_manage/query/repay_apply | tradeorder        | 1300877   | 0             | 1300877           | 0              | 0              | 0               |
| /repayengine/data_manage/query/repay_apply | collectionchannel | 298233    | 51            | 298182            | 7              | 23             | 21              |
| /repayengine/data_manage/query/repay_apply | telmarketcore     | 72256     | 0             | 72256             | 0              | 0              | 0               |
| /repayengine/data_manage/query/repay_apply | customersystem    | 3980      | 468           | 3512              | 460            | 1              | 7               |
| /repayengine/data_manage/query/repay_apply | channelcore       | 86931     | 86931         | 0                 | 86931          | 0              | 0               |
| /repayengine/data_manage/query/repay_apply | spiegel           | 931       | 931           | 0                 | 931            | 0              | 0               |
| /repayengine/data_manage/query/repay_apply | collection        | 5162      | 0             | 5162              | 0              | 0              | 0               |
**接口路径:** `/repayengine/data_manage/query/repay_apply`
**请求方法:** POST
**接口状态:** 已上线 (ONLINE)

**请求参数:**
```json
{
  "pageNum": 1,                    // 当前页码，从1开始 (必填)
  "pageSize": 10,                  // 每页的记录数 (必填)
  "uid": "用户ID",                 // uid (必填)
  "timeStart": "查询时间范围起始",  // date-time
  "timeEnd": "查询时间范围截止",    // date-time
  "order": "DESC",                 // 排序规则: ASC/DESC
  "orderParam": "create_at",       // 排序参数
  "repayType": "BY_STAGE_PLAN",    // 还款类型: BY_STAGE_PLAN/BY_AMOUNT
  "repayCategoryList": ["STAGE"],  // 还款类型数组: STAGE/BILL/ORDER
  "repayStatus": "SUCCESS",        // 还款状态: INIT/INIT_ABORT/PRE_LOCK/PROCESSING/SUCCESS/PART_SUCCESS/FAILURE
  "stageOrderNo": "订单号",
  "stageOrderNoList": ["订单1"],   // 订单号列表
  "repayWayList": ["MANUAL_REPAY"],// 还款方式: AUTO_DEDUCT/MANUAL_REPAY/MANUAL_DEDUCT/AO_OFFLINE
  "repayStatusList": ["SUCCESS"],  // 还款状态列表
  "lastId": 100,                   // 仅查询小于此id的数据
  "unRequestSourceList": [],       // 排除请求来源
  "requestSourceList": []          // 请求来源列表
}
```

**根据参数分析改动点:**
- ✅ **必填参数包含 uid** - 可以通过 uid 进行高效查询
- ✅ **支持 timeStart/timeEnd 时间范围查询** - 可根据时间范围判断是否需要查询归档数据
- ✅ **支持 lastId 游标分页** - 适合大数据量分页查询
- ⚠️ **大部分上游未传时间范围参数** - 从日志分析来看，tradeorder(129万次)、telmarketcore(7万次)、collectionchannel(29万次)等主要调用方基本都不传时间参数，无法通过参数区分热/冷数据
- ✅ **带时间范围的请求主要查询3个月内数据** - channelcore(8.7万次全部3个月内)、spiegel(931次全部3个月内)、customersystem(468次中460次3个月内)，说明即使传时间参数也主要是查询热数据

---

### DataManageController.queryDeductBill
|requestUri|r_e|total_req|req_with_time|req_with_out_time|
|---|---|---|---|---|
|/repayengine/data_manage/query/deduct_bill|collectionchannel|49666|0|49666|
|/repayengine/data_manage/query/deduct_bill|accountingoperation|1343|0|1343|
|/repayengine/data_manage/query/deduct_bill|customersystem|5023|0|5023|
|/repayengine/data_manage/query/deduct_bill|channelcore|7675|0|7675|
|/repayengine/data_manage/query/deduct_bill|telmarketcore|1098459|0|1098459|
|/repayengine/data_manage/query/deduct_bill|tradeorder|569064|0|569064|
|/repayengine/data_manage/query/deduct_bill|hbloandeal|24730|0|24730|
**接口路径:** `/repayengine/data_manage/query/deduct_bill`
**请求方法:** POST
**接口状态:** 已上线 (ONLINE)

**请求参数:**
```json
{
  "pageNum": 1,                    // 当前页码，从1开始 (必填)
  "pageSize": 10,                  // 每页的记录数 (必填)
  "timeStart": "查询时间范围起始",  // date-time
  "timeEnd": "查询时间范围截止",    // date-time
  "order": "DESC",                 // 排序规则: ASC/DESC
  "orderParam": "create_at",       // 排序参数
  "repayApplyNo": "还款申请流水号", // repayengine生成
  "repayApplyNoList": ["流水1"]    // 流水号列表，repayApplyNo为空时有效，有效时分页参数无效
}
```

**根据参数分析改动点:**
- ❌ **没有 uid 参数** - 仅通过 repayApplyNo 无法区分用户数据归档情况
- ✅ **支持 timeStart/timeEnd 时间范围查询** - 可根据时间范围判断
- ✅ **支持 repayApplyNoList 批量查询** - 可批量判断归档状态
- ⚠️ **需要通过 repayApplyNo 关联 repay_apply 表获取 uid** - 建议改造增加 uid 参数
- ⚠️ **所有上游调用都未传时间范围参数** - 从日志分析来看，telmarketcore(109万次)、tradeorder(56万次)、collectionchannel(4.9万次)等所有调用方都没有传时间参数

---

### DataManageController.queryRebackInfo
|requestUri|r_e|total_req|
|---|---|---|
|/repayengine/data_manage/query/rebackInfo|hbloandeal|1772|
|/repayengine/data_manage/query/rebackInfo|tradeorder|75008|
**接口路径:** `/repayengine/data_manage/query/rebackInfo`
**请求方法:** POST
**接口状态:** 已上线 (ONLINE)

**请求参数:**
```json
{
  "uid": "用户id",                  // (必填)
  "repayApplyNoList": ["申请1"],    // 还款申请编号列表 (必填)
  "stageOrderNo": "订单号",
  "refundStatus": "REFUND_SUCCESS"  // 清还款返现状态: INIT/PRE_REFUND/REFUNDING/ABORTED/REFUND_SUCCESS/REFUND_FAILED
}
```

**根据参数分析改动点:**
- ✅ **必填参数包含 uid** - 可以通过 uid 进行高效查询
- ✅ **通过 repayApplyNoList 批量查询** - 可批量判断归档状态
- ⚠️ **没有时间范围参数** - 无法通过时间范围判断是否查询归档数据

---

### DataManageController.queryRefundBill
|requestUri|r_e|total_req|req_with_time|req_with_out_time|
|---|---|---|---|---|
|/repayengine/data_manage/query/refund_bill|customersystem|4087|0|4087|
|/repayengine/data_manage/query/refund_bill|accountingoperation|183|0|183|
**接口路径:** `/repayengine/data_manage/query/refund_bill`
**请求方法:** POST
**接口状态:** 已上线 (ONLINE)

**请求参数:**
```json
{
  "pageNum": 1,                        // 当前页码，从1开始 (必填)
  "pageSize": 10,                      // 每页的记录数 (必填)
  "uid": "用户id",                     // (必填)
  "stageOrderNo": "订单号",            // (必填)
  "timeStart": "查询时间范围起始",      // date-time
  "timeEnd": "查询时间范围截止",        // date-time
  "order": "DESC",                     // 排序规则: ASC/DESC
  "orderParam": "create_at",           // 排序参数
  "repayApplyNo": "还款申请编号",
  "repayApplyNoList": ["申请1"],       // 还款申请编号列表，如repayApplyNo有值则该参数失效
  "refundBillNo": "提前结清还款返现单编号",
  "refundType": "REPAY_REFUND",        // 提前结清还款返现类型
  "refundStatus": "REFUND_SUCCESS",    // 提前结清还款返现状态
  "refundSubmitDatetimeStart": "",     // 返现发起时间-开始
  "refundSubmitDatetimeEnd": ""        // 返现发起时间-结束
}
```

**根据参数分析改动点:**
- ✅ **必填参数包含 uid 和 stageOrderNo** - 可以通过 uid 进行高效查询
- ✅ **支持 timeStart/timeEnd 时间范围查询** - 可根据时间范围判断
- ✅ **支持 refundSubmitDatetimeStart/End 返现时间范围** - 更精确的时间过滤
- ⚠️ **所有上游调用都未传时间范围参数** - 从日志分析来看，customersystem(4087次)、accountingoperation(183次)等所有调用方都没有传时间参数

---

# 优化方案

## 接口分析总结

| 接口                | 是否有 uid | 支持时间参数 | 实际传时间   | 改造方案                               |
| ----------------- | ------- | ------ | ------- | ---------------------------------- |
| `apply_result`    | ❌       | ❌      | -       | **方案A**: 新增 uid(必传)，先查热数据，未命中再查冷数据 |
| `queryRepayApply` | ✅       | ✅      | ❌ 大部分不传 | **方案B**: uid+时间必传，判断后并发查询          |
| `queryDeductBill` | ❌       | ✅      | ❌ 都不传   | **方案B**: 新增 uid(必传)+时间(必传)，判断后并发查询 |
| `queryRebackInfo` | ✅       | ❌      | -       | **方案B**: 新增时间(必传)，判断后并发查询          |
| `queryRefundBill` | ✅       | ✅      | ❌ 都不传   | **方案B**: uid+时间必传，判断后并发查询          |

**核心结论：**
- `apply_result` 接口采用 **先查热数据，未命中再查归档** 的串行方案
- 其他接口采用 **uid+时间必传，判断后并发查询** 的并行方案
- 建议分阶段执行，降低风险

---

## 分阶段执行方案

### 阶段0：清理未被引用的大表
**目标：** 清理未被查询引用的大表，快速释放存储空间

#### 0.1 大表使用情况分析

| 大表 | 大小 | 是否被引用 | 引用接口 |
|------|------|-----------|---------|
| **被引用的大表** |
| `deduct_bill` | 2.661 TB | ✅ | queryDeductBill |
| `repay_apply` | 718 GB | ✅ | queryRepayApply, repayApplyResult |
| `repay_apply_stage_plan_item` | 410 GB | ✅ | queryRepayApply, repayApplyResult |
| `repayment_stage_plan_item` | 369 GB | ✅ | queryDeductBill (关联) |
| `repay_apply_pay_item` | 273 GB | ✅ | repayApplyResult |
| `refund_bill` | 40 GB | ✅ | queryRebackInfo, queryRefundBill |
| **未被引用的大表** |
| `repayment_bill` | 445 GB | ⚠️ | 需确认是否通过关联查询使用 |
| `repay_trial_bill` | 295 GB | ❌ | 无查询接口 |
| `clearing_bill` | 211 GB | ❌ | 无查询接口 |
| `repayment_income_bill` | 240 GB | ❌ | 无查询接口 |
| **小计** | **~1.2 TB** | | |
| **repayenginea 库** |
| 各类大表 | ~1.6 TB | ⚠️ | 待确认 |

#### 0.2 清理计划

**立即清理（无引用）：**

| 表名 | 大小 | 清理逻辑 | 说明 |
|------|------|---------|------|
| `repay_trial_bill` | 295 GB | 保留15天 | 按时间删除15天前数据 |
| `clearing_bill` | 211 GB | 待业务确认 | 与业务确认后清理 |
| `repayment_income_bill` | 240 GB | 待业务确认 | 与业务确认后清理 |
| **合计** | **~746 GB** | | |

**待确认后清理：**

| 表名 | 大小 | 确认事项 |
|------|------|---------|
| `repayment_bill` | 445 GB | 是否通过关联查询被使用 |
| `repayenginea` 各表 | ~1.6 TB | 归档库用途确认 |

#### 0.3 执行步骤
1. **梳理表用途** - 与业务方确认未被引用表的用途
2. **评估风险** - 确认无业务依赖后再执行清理
3. **新增 DMS 工单** - 按清理逻辑执行数据删除
4. **验证清理结果** - 确认存储空间释放

**预期收益：** 快速释放 ~746GB 存储空间（待确认表清理后可达 ~2.7 TB）

---

### 阶段1：接口入参改造
**目标：** 为缺失 uid 和时间参数的接口增加参数支持

**执行内容：**

#### 1.1 接口参数改造

| 接口                | 方案    | uid参数  | 时间参数   | 改造内容                             |
| ----------------- | ----- | ------ | ------ | -------------------------------- |
| `apply_result`    | A（串行） | 新增（必传） | 不需要    | 新增 uid 参数，先查热数据，未命中再查冷数据         |
| `queryRepayApply` | B（并发） | 改为必传   | 改为必传   | uid+timeStart/timeEnd 都改为必传      |
| `queryDeductBill` | B（并发） | 新增（必传） | 改为必传   | 新增 uid 参数，timeStart/timeEnd 改为必传 |
| `queryRebackInfo` | B（并发） | 已有（必传） | 新增（必传） | 新增 timeStart/timeEnd 参数          |
| `queryRefundBill` | B（并发） | 已有（必传） | 改为必传   | timeStart/timeEnd 改为必传           |

**改造说明：**
- **方案A（串行）**：适用于主要查询热数据的接口，实现简单
- **方案B（并发）**：适用于可能查询冷数据的接口，需要上游传递时间参数

#### 1.2 查询策略对比

| 方案 | 适用接口 | 查询策略 | 优点 | 缺点 |
|------|---------|---------|------|------|
| **方案A** | `apply_result` | 串行：先查热数据→未命中查冷数据 | 实现简单，调用量集中热数据 | 查冷数据时延迟增加 |
| **方案B** | 其他4个接口 | 并发：判断需要→并发查询冷热数据 | 查冷数据时性能好 | 需要上游传递时间参数 |

**预期收益：** 为后续区分热/冷数据查询打下基础

---

### 阶段2：查询接口代码逻辑改造
**目标：** 支持冷热数据分离查询，但底层数据源暂不切换

**执行内容：**

#### 2.1 方案A：apply_result 接口（串行查询）

```java
// 伪代码示例
public RepayApplyResultResp applyResult(ApplyResultReq req) {
    // 1. 先查 MySQL 热数据
    RepayApplyResultResp result = queryFromMySQL(req);

    // 2. 未命中且可能存在归档数据时，查冷数据
    if (result == null && mayHaveArchiveData(req)) {
        log.info("热数据未命中，查询冷数据, req={}", req);
        result = queryFromArchive(req); // 暂时指向 MySQL
        logArchiveQuery(req, true);
    } else {
        logArchiveQuery(req, false);
    }

    return result;
}
```

#### 2.2 方案B：其他接口（并发查询）

```java
// 伪代码示例
public PageResult query(QueryReq req) {
    // 1. 判断是否需要查询归档数据（根据时间范围）
    boolean needQueryArchive = checkNeedQueryArchive(req);
    logArchiveQuery(req, needQueryArchive);

    // 2. 查询逻辑
    if (!needQueryArchive) {
        // 只查热数据
        return queryFromMySQL(req);
    }

    // 3. 并发查询冷热数据
    CompletableFuture<PageResult> hotFuture = CompletableFuture.supplyAsync(() -> queryFromMySQL(req));
    CompletableFuture<PageResult> archiveFuture = CompletableFuture.supplyAsync(() -> queryFromArchiveByUid(req));

    // 4. 合并结果
    PageResult hotResult = hotFuture.join();
    PageResult archiveResult = archiveFuture.join();
    return merge(hotResult, archiveResult);
}

// 判断是否需要查询归档数据
private boolean checkNeedQueryArchive(QueryReq req) {
    // 根据 timeStart/timeEnd 判断是否跨越归档时间点
    if (req.getTimeStart() == null || req.getTimeEnd() == null) {
        return true; // 无时间参数，默认查归档
    }
    return isTimeRangeOverlapArchive(req.getTimeStart(), req.getTimeEnd());
}

// StarRocks 查询优化：先按 uid 查询，再在内存中过滤其他条件
private PageResult queryFromArchiveByUid(QueryReq req) {
    // 1. StarRocks 按 uid 分桶，必须带上 uid 查询才能命中分区
    // 2. 其他过滤条件在应用内存中进行，避免全表扫描
    List<Record> records = starRocksMapper.queryByUid(req.getUid());

    // 3. 在应用内存中过滤其他参数
    List<Record> filtered = records.stream()
        .filter(r -> matchTimeRange(r, req.getTimeStart(), req.getTimeEnd()))
        .filter(r -> matchOtherConditions(r, req))
        .collect(Collectors.toList());

    // 4. 内存分页
    return paginateInMemory(filtered, req.getPageNum(), req.getPageSize());
}
```

#### 2.3 新增归档数据源配置
```yaml
archive:
  datasource:
    url: ${mysql.url}  # 暂时指向原 MySQL 库
    username: ${mysql.username}
    password: ${mysql.password}
```

#### 2.4 日志统计
- 记录请求参数、是否命中归档判断
- 产出日志报表，评估实际归档查询量

**预期收益：**
- 验证归档判断逻辑准确性
- 评估实际归档查询调用量
- 预留切换开关，方便一键切换

---

### 阶段3：推动上游传递参数
**目标：** 推动上游改造，传递 uid 和时间参数

**执行内容：**

#### 3.1 接口改造推动优先级

| 接口                | 上游调用方                                                              | 推动内容          | 优先级 |
| ----------------- | ------------------------------------------------------------------ | ------------- | --- |
| `apply_result`    | accountingoperation(295万次)<br>channelcore(24万次)                    | 传递 uid（必传）    | 高   |
| `queryRepayApply` | tradeorder(129万次)<br>telmarketcore(7万次)<br>collectionchannel(29万次) | 传递 uid+时间（必传） | 高   |
| `queryDeductBill` | telmarketcore(109万次)<br>tradeorder(56万次)                           | 传递 uid+时间（必传） | 高   |
| `queryRebackInfo` | tradeorder(7.5万次)<br>hbloandeal(1.7千次)                             | 传递时间（必传）      | 中   |
| `queryRefundBill` | customersystem(4千次)                                                | 传递时间（必传）      | 中   |

#### 3.2 推动计划
1. 按调用量分优先级推动
2. 提供接口文档更新说明
3. 协助上游进行联调测试

**预期收益：** 提升接口区分热/冷数据的能力

---

### 阶段4：冷数据同步与双读验证
**目标：** 冷数据同步到 StarRocks，抽样双读验证

**执行内容：**

#### 4.1 冷数据归档方案选择
**方案1：Flink → Paimon → StarRocks**
- 标准方案，需要额外费用
- 适合长期使用场景

**方案2：DP 数据源 → StarRocks**
- 兼容方案，节省 Flink 和 Paimon 费用
- 可能需要数仓改造

#### 4.2 数据同步
- 按 uid 分区分桶归档冷数据
- 同步历史冷数据到 StarRocks

#### 4.3 抽样双读验证
```java
// 伪代码示例
public Result query(QueryReq req) {
    Result mysqlResult = queryFromMySQL(req);
    Result srResult = queryFromStarRocks(req);

    // logmonitor 对比报告
    compareAndLog(mysqlResult, srResult);

    return mysqlResult; // 暂时还是返回 MySQL 结果
}
```

#### 4.4 产出对比报告
- 通过 logmonitor 产出数据一致性报告
- 验证 StarRocks 查询性能和正确性

**预期收益：** 验证 StarRocks 数据源可用性

---

### 阶段5：切换到 StarRocks 数据源
**目标：** 正式切换归档数据查询到 StarRocks

**执行内容：**

#### 5.1 数据源配置切换
```yaml
archive:
  datasource:
    url: ${starrocks.url}  # 切换到 StarRocks
    # ...其他配置
```

#### 5.2 查询逻辑调整
```java
public Result query(QueryReq req) {
    if (needQueryArchive(req)) {
        return queryFromStarRocks(req); // 切换到 StarRocks
    }
    return queryFromMySQL(req);
}
```

#### 5.3 增加保护机制
- 限制 StarRocks 并发查询量
- 增加熔断和告警机制
- 监控查询性能

**预期收益：** 释放 MySQL 存储压力，提升查询效率

---

### 阶段6：冷数据清理
**目标：** MySQL 中已归档的冷数据清理

**执行内容：**
1. 新增 DMS 数据清理工单
2. 按时间范围删除已归档的冷数据
3. 验证清理后业务正常

**预期收益：** 释放 MySQL 存储空间

---

## 冷数据归档方案（详细）

### 方案1：Flink → Paimon → StarRocks
- 按 uid 分区分桶归档冷数据
- 使用 Flink 订阅 MySQL Binlog → Paimon 存储
- StarRocks 外表关联 Paimon 查询

**优点：** 标准方案，社区成熟
**缺点：** 需要额外费用（Flink + Paimon）

### 方案2：DP 数据源 → StarRocks
- StarRocks 外表关联 DP 表
- 可能需要数仓改造

**优点：** 兼容方案，节省费用
**缺点：** 可能需要数仓配合改造

---

## 冷数据查询方案

### 1. StarRocks 点查优化
**重要：** 由于 StarRocks 按 uid 分桶存储归档数据，为保证查询效率，必须遵循以下策略：

#### 1.1 查询策略
```
┌─────────────────────────────────────────────────────────┐
│  StarRocks 查询优化流程                                  │
├─────────────────────────────────────────────────────────┤
│  1. 必须带上 uid 查询 → 命中分区，避免全表扫描          │
│  2. 按 uid 查询所有数据                                 │
│  3. 在应用内存中过滤其他参数（时间、状态等）             │
│  4. 在应用内存中进行分页                                │
└─────────────────────────────────────────────────────────┘
```

#### 1.2 为什么采用这种策略
| 原因 | 说明 |
|------|------|
| **分区命中** | StarRocks 按 uid 分桶，带 uid 才能命中分区 |
| **避免全表扫描** | 不带 uid 会导致全表扫描，性能极差 |
| **内存过滤高效** | 单个 uid 的数据量有限，内存过滤成本低 |
| **减少网络传输** | 只传输必要的数据，降低网络开销 |

#### 1.3 代码示例
```java
// ❌ 错误做法：直接在 StarRocks 中过滤所有条件
// SELECT * FROM archive WHERE uid = ? AND time >= ? AND status = ?
// 问题：可能不走分区索引，性能差

// ✅ 正确做法：先按 uid 查询，再在内存中过滤
List<Record> records = starRocksMapper.queryByUid(uid); // 只用 uid 查询
List<Record> filtered = records.stream()
    .filter(r -> r.getTime() >= startTime)
    .filter(r -> r.getStatus() == status)
    .collect(Collectors.toList());
```

### 2. 并发保护机制
```java
// 限流配置
@RateLimit(qps = 100, dataSource = "archive")
public Result queryFromArchive(QueryReq req) {
    // ...
}

// 熔断配置
@CircuitBreaker(failureThreshold = 10, resetTimeout = 60s)
public Result queryFromStarRocks(QueryReq req) {
    // ...
}
```

### 3. 查询策略

#### 3.1 StarRocks 查询优化（重要）
由于 StarRocks 按 uid 分桶，必须遵循以下查询策略：

| 步骤  | 说明           | 原因                 |
| --- | ------------ | ------------------ |
| 1   | 必须带上 uid 查询  | 命中分区，避免全表扫描        |
| 2   | 按 uid 查询所有数据 | 利用分区索引，提高查询效率      |
| 3   | 在应用内存中过滤其他参数 | 单 uid 数据量有限，内存过滤高效 |
| 4   | 在应用内存中分页     | 减少网络传输，降低开销        |

#### 3.2 不同场景的查询策略
| 场景 | 查询策略 |
|------|---------|
| **有 uid + 有时间参数** | StarRocks 按 uid 查询 → 内存过滤时间及其他条件 → 内存分页 |
| **有 uid + 无时间参数** | StarRocks 按 uid 查询 → 内存过滤其他条件 → 内存分页 |
| **无 uid** | ❌ 不支持查询归档数据，返回提示"请提供 uid 参数" |

#### 3.3 错误示例对比
```java
// ❌ 错误做法：直接在 StarRocks 中过滤所有条件
SELECT * FROM archive
WHERE uid = ? AND create_time >= ? AND status = ?
-- 问题：复合索引可能不生效，导致查询效率低

// ✅ 正确做法：先按 uid 查询，再在内存中过滤
SELECT * FROM archive WHERE uid = ?
-- 然后在应用内存中过滤时间、状态等条件
```

---

## 接口内部兼容方案

基于接口调用分析，针对不同接口采用不同的兼容方案：

---

### 方案A：串行查询（apply_result 接口）

**适用接口：** `RepayApplyController.repayApplyResult`

**改造内容：**
- 新增 uid 参数（可选）
- 不增加时间参数

**查询策略：**
```java
public RepayApplyResultResp applyResult(ApplyResultReq req) {
    // 1. 先查 MySQL 热数据
    RepayApplyResultResp result = queryFromMySQL(req);

    // 2. 未命中且可能存在归档数据时，查冷数据
    if (result == null && mayHaveArchiveData(req)) {
        result = queryFromArchive(req);
    }

    return result;
}
```

**为什么采用串行方案：**
- 调用量集中在3个月内热数据（accountingoperation 295万次中99%是热数据）
- 串行查询对热数据请求无性能影响
- 实现简单，风险低

---

### 方案B：并发查询（其他4个接口）

**适用接口：**
- `DataManageController.queryRepayApply`
- `DataManageController.queryDeductBill`
- `DataManageController.queryRebackInfo`
- `DataManageController.queryRefundBill`

**改造内容：**
- uid 和时间参数都改为必传
- 根据时间范围判断是否需要查询冷数据

**查询策略：**
```java
public PageResult query(QueryReq req) {
    // 参数校验
    if (req.getUid() == null || req.getTimeStart() == null || req.getTimeEnd() == null) {
        throw new IllegalArgumentException("uid 和时间参数必传");
    }

    // 判断是否需要查询归档数据
    boolean needQueryArchive = isTimeRangeOverlapArchive(req.getTimeStart(), req.getTimeEnd());

    if (!needQueryArchive) {
        return queryFromMySQL(req);
    }

    // 并发查询冷热数据
    CompletableFuture<PageResult> hotFuture = CompletableFuture.supplyAsync(() -> queryFromMySQL(req));
    CompletableFuture<PageResult> archiveFuture = CompletableFuture.supplyAsync(() -> queryFromArchiveByUid(req));

    // 合并结果
    return merge(hotFuture.join(), archiveFuture.join());
}

// StarRocks 查询优化：先按 uid 查询，再在内存中过滤其他条件
private PageResult queryFromArchiveByUid(QueryReq req) {
    // 1. StarRocks 按 uid 分桶，必须带上 uid 查询才能命中分区
    List<Record> records = starRocksMapper.queryByUid(req.getUid());

    // 2. 在应用内存中过滤其他参数（时间、状态等）
    List<Record> filtered = records.stream()
        .filter(r -> matchTimeRange(r, req.getTimeStart(), req.getTimeEnd()))
        .filter(r -> matchOtherConditions(r, req))
        .collect(Collectors.toList());

    // 3. 在应用内存中分页
    return paginateInMemory(filtered, req.getPageNum(), req.getPageSize());
}
```

**为什么采用并发方案：**
- 大部分上游不传时间参数，需要强制要求传递
- 通过时间范围可以明确判断是否需要查询冷数据
- 并发查询保证查询效率

---

### 方案对比总结

| 对比项 | 方案A（串行） | 方案B（并发） |
|--------|-------------|-------------|
| **适用接口** | `apply_result` | 其他4个接口 |
| **uid参数** | 必传 | 必传 |
| **时间参数** | 不需要 | 必传 |
| **查询策略** | 先热后冷 | 判断后并发 |
| **StarRocks查询** | 按 uid 查询 → 内存过滤 | 按 uid 查询 → 内存过滤 |
| **优点** | 实现简单，热数据无影响 | 查冷数据性能好 |
| **缺点** | 查冷数据延迟增加 | 需要上游改造 |
| **适用场景** | 主要查询热数据 | 可能查询冷数据 |

---

### StarRocks 查询优化说明

**重要：** 由于 StarRocks 按 uid 分桶存储归档数据，所有接口查询归档数据时必须遵循以下策略：

```
┌─────────────────────────────────────────────────────────────┐
│  StarRocks 归档数据查询流程                                  │
├─────────────────────────────────────────────────────────────┤
│  1. 必须带上 uid → 命中分区，避免全表扫描                    │
│  2. SELECT * FROM archive WHERE uid = ?                     │
│  3. 在应用内存中过滤其他参数（时间、状态等）                   │
│  4. 在应用内存中进行分页                                    │
└─────────────────────────────────────────────────────────────┘
```

**为什么采用这种策略：**
- ✅ StarRocks 按 uid 分桶，带 uid 查询才能命中分区
- ✅ 避免不带 uid 导致的全表扫描
- ✅ 单个 uid 的数据量有限，内存过滤成本低
- ✅ 减少网络传输数据量
