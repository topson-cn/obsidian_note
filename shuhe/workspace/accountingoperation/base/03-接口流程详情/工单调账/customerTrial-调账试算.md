# 工单调账-调账试算

## 基本信息

| 属性 | 值 |
|------|-----|
| 接口路径 | `POST /customerAccountAdjust/trial` |
| Controller | `CustomerAccountAdjustController#customerTrial` |
| Service | `CustomerAccountAdjustService#customerTrial` |
| 功能描述 | 客户维度调账试算，在正式发起调账工单前预计算调账结果，返回各订单/分期/成分的可减免金额及试算明细 |

---

## 请求参数

**类路径：** `cn.caijiajia.accountingoperation.common.req.accountadjust.customer.CustomerTrialReq`

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `requestType` | `RequestTypeEnum` | 是 | 请求来源类型，见枚举说明 |
| `adjustExceed` | `AdjustExceedEnum` | 是 | 调整范围（逾期/逾期+M0/全部），见枚举说明 |
| `handledId` | `Long` | 否 | 经办ID（Ares/客服系统传入，用于查询贷后策略） |
| `internalHandleId` | `String` | 否 | 内部经办ID |
| `availableAdjustAmount` | `Integer` | 否 | 剩余可用额度（分，限额控制） |
| `exceedStatusAmount` | `Integer` | 否 | 调整范围对应的金额（分） |
| `orderType` | `AjustOrderTypeEnum` | 否 | 调整产品类型，见枚举说明 |
| `adjustDirection` | `DirectionEnum` | 是 | 调账方向：`UP`（调增）/`DOWN`（调减） |
| `adjustType` | `String` | 是 | 调整分类（如 SPECIAL_REDUCE、CUST_REDUCE 等） |
| `adjustTotalAmount` | `Integer` | 否 | 本次调整总金额（分），不传则查询最大可减免 |
| `orderInfoList` | `List<AdjustOrderTrialReq>` | 是 | 调整的订单信息列表 |

**AdjustOrderTrialReq（内部类）：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `orderNo` | `String` | 订单号（billNo） |
| `stagePlanInfoList` | `List<String>` | 分期计划号列表（指定哪些分期参与试算） |

**枚举说明：**

`RequestTypeEnum`（请求来源）：
- `O` - O系统请求
- `R` - 从贷后阿瑞斯系统请求
- `C` - 客服系统请求
- `RD` - 贷后阿瑞斯直连请求
- `N` - 协商还款请求

`AdjustExceedEnum`（调整范围）：
- `O` - 只查询逾期的分期
- `U` - 逾期计划及M0当期
- `A` - 全部

`AjustOrderTypeEnum`（调整产品）：
- `ORDER` - 订单制
- `STMT` - 账单制
- `ALL` - 全部

---

## 响应参数

**类路径：** `cn.caijiajia.accountingoperation.common.resp.accountadjust.customer.QueryCustomerOrderInfoResp`

| 字段 | 类型 | 说明 |
|------|------|------|
| `uid` | `String` | 用户ID |
| `uidMaxAdjustAmount` | `Integer` | 用户最高可调减金额（分）；客服请求且无逾期订单时不返回 |
| `orderMaxAdjustAmount` | `Integer` | 所有订单最高可调减金额汇总（分） |
| `expireDayAutoAdjust` | `Integer` | 约定期内未还款自动调增天数（配置值） |
| `riskAmountRate` | `Integer` | 推荐金额比例（百分比整数，来自贷后策略） |
| `riskExceedAmount` | `Integer` | 调整范围对应的金额（O系统时为空） |
| `containExceedPlan` | `Boolean` | 是否包含逾期订单 |
| `orderInfoList` | `List<OrderInfoResp>` | 订单信息列表 |

**OrderInfoResp：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `orderNo` | `String` | 订单号 |
| `bankName` | `String` | 资金方名称（中文） |
| `assetId` | `String` | 资产包ID |
| `orderOverDueStatus` | `String` | 订单逾期状态 |
| `applyTime` | `Date` | 订单借款时间 |
| `orderType` | `String` | 产品类型：`ORDER-订单制`/`STMT-账单制` |
| `feeTotal` | `Integer` | 总息费（分） |
| `maxAdjustAmount` | `Integer` | 订单最高可减免金额（分） |
| `adjustAmount` | `Integer` | 订单减免金额（分，试算结果） |
| `totalLeftFee` | `Integer` | 剩余应还总利息（分） |
| `totalLeftWarrantyFee` | `Integer` | 剩余应还总担保费（分） |
| `totalLeftPrepaymentFee` | `Integer` | 剩余应还总提前结清手续费（分） |
| `totalLeftLateFee` | `Integer` | 剩余应还总违约金（分） |
| `totalLeftInterest` | `Integer` | 剩余应还总罚息（分） |
| `totalLeftAmcFee` | `Integer` | 剩余应还总资产管理咨询费（分） |
| `totalLeftPrincipal` | `Integer` | 剩余应还总本金（分） |
| `stagePlanInfoList` | `List<StagePlanInfoResp>` | 分期列表 |

**StagePlanInfoResp（分期信息）：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `stageNo` | `String` | 期数 |
| `stagePlanNo` | `String` | 分期计划号 |
| `exceedStatus` | `String` | 分期逾期状态 |
| `obtainedLabel` | `String` | 获取标 |
| `leftAmount` | `Integer` | 调整前剩余应还金额（分） |
| `preAdjustComponentInfos` | `List<PreAdjustComponentInfo>` | 调整前成分明细（剩余应还） |
| `adjustComponentInfos` | `List<AdjustComponentInfo>` | 调账成分明细（调整金额） |
| `postAdjustComponentInfos` | `List<PostAdjustComponentInfo>` | 调账后成分明细（调整后应还） |

**PreAdjustComponentInfo：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `components` | `ComponentsEnum` | 成分类型 |
| `leftAmount` | `Integer` | 调整前剩余应还金额（分） |
| `downAmount` | `Integer` | 该成分已调减金额（分） |

**AdjustComponentInfo：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `components` | `ComponentsEnum` | 成分类型 |
| `amount` | `Integer` | 调整金额（分） |
| `direction` | `String` | 调账方向：`DOWN`调减/`UP`调增 |

**PostAdjustComponentInfo：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `components` | `ComponentsEnum` | 成分类型 |
| `amount` | `Integer` | 调整后应还金额（分） |

---

## 调用关系

### 外部系统调用

| 系统 | 调用方式 | 说明 |
|------|------|------|
| TnqBill（账单系统） | `TnqBillClientProxy#findByUidBillsV2` | 查询订单、分期、成分数据 |
| 贷后系统（Ares） | `ReductionProx#getFrontDataAndCheckCustomer` | 获取贷后减免前置数据（仅 R/RD/C 部分请求类型） |
| 算费服务 | `AccountAdjustV1Service#getDownAdjustRule` | 获取调减规则（成分百分比） |
| 算费服务 | `AccountAdjustV1Service#getAdjustRuleAndTrail` | 调用试算接口，计算各分期减免金额 |
| 资金配置中心 | `AccountAdjustService#filterCapitalRuleByCustomer` | 过滤资金规则，确定哪些成分不可调减 |

### 数据库交互

本接口为**纯查询/计算接口**，不写入数据库。所有数据通过外部服务获取。

---

## 关键业务规则

1. **调增不支持多笔订单**：`adjustDirection=UP` 时，`orderInfoList` 只允许传一笔订单
2. **客服请求特殊逻辑**：`requestType=C` 且 `adjustType=CUST_REDUCE` 时不依赖贷后策略
3. **特殊减免不依赖贷后策略**：`adjustType=SPECIAL_REDUCE` 时直接使用前端传入的 `exceedStatusAmount`
4. **客服+无逾期订单场景**：`requestType=C` 且订单无逾期分期时，响应中不返回 `uidMaxAdjustAmount`
5. **调账金额边界**：`adjustTotalAmount` 不得超过 `realMaxDeductibleAmount`，不传时取最大可减免值
6. **订单过滤逻辑**：按调整范围（逾期/逾期+M0/全部）、产品类型、协商还款状态过滤分期
7. **订单排序**：响应中按逾期阶段降序、借款时间升序排列

---

## 流程图

```mermaid
flowchart TD
    A[POST /customerAccountAdjust/trial] --> B[customerTrialValidate 入参校验]

    B --> B1[checkParamTrailReq 参数格式校验]
    B --> B2[getDepartmentAuthority 部门权限校验]
    B --> B3[checkAdjustDirection 调增不支持多笔]

    B --> C[filterCustomerTrialOrderList 获取试算订单]
    C --> C1["TnqBillClientProxy.findByUidBillsV2\n按订单号查询账单数据"]
    C --> C2[filterPlanNo 过滤前端指定的分期]

    C --> D[convert 请求参数转换为Bo]

    D --> E{checkIfEnhanceAresCustomerInfoByRequestType\n是否需要贷后策略增强}

    E -->|R/RD 且非特殊减免\n且非客服调账| F["ReductionProx.getFrontDataAndCheckCustomer\n获取贷后减免前置数据"]
    F --> F1[checkRiskAdjustExceed 校验调整范围]
    F --> F2[setExceedStatusAmount 设置调整范围金额]
    F --> F3[setRiskAmountRate 设置推荐金额比例]

    E -->|不需要| G
    F3 --> G[handleOrderAndAdjustTrial 处理订单信息与调账试算]

    G --> G1[checkHandleOrderAndAdjustParam 参数二次校验]
    G --> G2[filterOrder 订单过滤]
    G2 --> G2a[filterPayOff 过滤已结清分期]
    G2 --> G2b[filterExceedStatus 过滤调整范围]
    G2 --> G2c[filterOrderType 过滤产品类型]
    G2 --> G2d[filterNegotiating 过滤协商还款中订单]

    G2 --> H{adjustDirection=UP?}

    H -->|调增| I[handleUpOrder 返回订单基本信息]

    H -->|调减| J[getMaxOverDueDays 获取客户最大逾期天数]
    J --> K[getAdjustRuleAndFilterCapitalRule 获取调减规则并过滤资金规则]
    K --> K1["AccountAdjustService.filterCapitalRuleByCustomer\n过滤资金配置中心规则"]
    K --> K2["AccountAdjustV1Service.getDownAdjustRule\n获取成分百分比调减规则"]

    K --> L[buildQueryCustomerOrderInfoResp 构建响应对象]
    L --> L1[buildStagePlanInfoResp 组装分期信息]
    L --> L2[calculationOrderMaxAdjustAmount 计算订单最高可减免]

    L --> M[calRealMaxDeductibleAmount 计算用户最高可减免]

    M --> N{adjustTotalAmount > 0?}
    N -->|有调整金额| O["AccountAdjustV1Service.getAdjustRuleAndTrail\n调用试算接口计算各分期减免"]
    O --> P[buildOrderAdjust 分配各订单减免金额]

    N -->|无调整金额| Q
    P --> Q[设置 expireDayAutoAdjust riskAmountRate riskExceedAmount]
    I --> R[返回 QueryCustomerOrderInfoResp]
    Q --> R

    style A fill:#4a90d9,color:#fff
    style R fill:#27ae60,color:#fff
    style F fill:#e67e22,color:#fff,stroke:#d35400
    style O fill:#e67e22,color:#fff,stroke:#d35400
    style K1 fill:#e67e22,color:#fff,stroke:#d35400
    style K2 fill:#e67e22,color:#fff,stroke:#d35400
    style C1 fill:#e67e22,color:#fff,stroke:#d35400
    style B3 fill:#e74c3c,color:#fff
    style G2d fill:#e74c3c,color:#fff
```

---

## 代码位置

| 层次 | 文件路径 | 关键行 |
|------|---------|--------|
| Controller | `accountingoperation/src/main/java/cn/caijiajia/accountingoperation/controller/CustomerAccountAdjustController.java` | L63-67 |
| Service 入口 | `accountingoperation/src/main/java/cn/caijiajia/accountingoperation/service/accountadjust/customer/CustomerAccountAdjustService.java` | L465-479 |
| 入参校验 | 同上 | L485-492 |
| 订单获取过滤 | 同上 | L494-503 |
| 贷后策略增强 | 同上 | L514-538 |
| 核心处理 | 同上 | L548-589 |
| 获取调减规则 | 同上 | L659-678 |
| 构建响应 | 同上 | L1577-1619 |
| 请求 DTO | `accountingoperation-common/src/main/java/cn/caijiajia/accountingoperation/common/req/accountadjust/customer/CustomerTrialReq.java` | L1-70 |
| 响应 DTO | `accountingoperation-common/src/main/java/cn/caijiajia/accountingoperation/common/resp/accountadjust/customer/QueryCustomerOrderInfoResp.java` | L1-165 |
| Feign 客户端 | `accountingoperation-feignclient/src/main/java/cn/caijiajia/accountingoperation/feignclient/CustomerAccountAdjustFeignClient.java` | L42-43 |