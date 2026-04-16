-- ============================================================
-- 测试表：联合贷开票查询（替代视图 v_invoice_query_joint_loan_term_repayment_detail_v2）
-- 用于本地环境直接查表测试
-- ============================================================

-- 1. 建表语句
DROP TABLE IF EXISTS t_invoice_query_joint_loan_term_repayment_detail_v2;

CREATE TABLE t_invoice_query_joint_loan_term_repayment_detail_v2 (
    ds                  VARCHAR(10)     COMMENT '分区日期 yyyyMMdd',
    uid                 VARCHAR(64)     COMMENT '用户ID',
    cus_nam             VARCHAR(128)    COMMENT '客户姓名',
    order_no            VARCHAR(64)     COMMENT '订单号(bill_no)',
    term_no             VARCHAR(10)     COMMENT '期次编号',
    term_id             VARCHAR(64)     COMMENT '期次ID',
    loan_asset_id       VARCHAR(64)     COMMENT '资方资产ID',
    asset_name          VARCHAR(128)    COMMENT '资方资产名称',
    paid_prin           DECIMAL(18,2)   COMMENT '已还本金',
    paid_int            DECIMAL(18,2)   COMMENT '已还利息',
    paid_guarantee_fee  DECIMAL(18,2)   COMMENT '已还担保费',
    paid_amc_fee        DECIMAL(18,2)   COMMENT '已还AMC费用',
    paid_late_fee       DECIMAL(18,2)   COMMENT '已还滞纳金',
    paid_pen            DECIMAL(18,2)   COMMENT '已还罚息',
    paid_pre_fee        DECIMAL(18,2)   COMMENT '已还提前还款手续费',
    paid_amt            DECIMAL(18,2)   COMMENT '已还总金额',
    paid_out_date       VARCHAR(20)     COMMENT '还款日期',
    refund_amt          DECIMAL(18,2)   COMMENT '退款金额(结清返现+补偿退款+返利退款)',
    act_rep_tot_amt     DECIMAL(18,2)   COMMENT '资方实还总额',
    act_rep_pri         DECIMAL(18,2)   COMMENT '资方实还本金',
    guarantee_rate      INT             COMMENT '担保比例(固定值1)',
    lead_name           VARCHAR(128)    COMMENT '主贷方名称(固定:重庆市分众小额贷款有限公司)',
    lead_amt            DECIMAL(18,2)   COMMENT '主贷方(FOCUS_LOAN)利息金额',
    fund_name           VARCHAR(128)    COMMENT '资方名称',
    fund_amt            DECIMAL(18,2)   COMMENT '资方利息金额',
    ind_gua_owner       VARCHAR(128)    COMMENT '担保公司',
    ind_gua_amt         DECIMAL(18,2)   COMMENT '担保金额(paid_amt - act_rep_tot_amt - refund_amt)',
    PRIMARY KEY (ds, order_no, term_no)
) COMMENT = '联合贷开票查询测试表';


-- ============================================================
-- 2. 初始化测试数据
-- ============================================================
INSERT INTO t_invoice_query_joint_loan_term_repayment_detail_v2
(ds, uid, cus_nam, order_no, term_no, term_id, loan_asset_id, asset_name,
 paid_prin, paid_int, paid_guarantee_fee, paid_amc_fee, paid_late_fee, paid_pen, paid_pre_fee, paid_amt,
 paid_out_date, refund_amt, act_rep_tot_amt, act_rep_pri,
 guarantee_rate, lead_name, lead_amt, fund_name, fund_amt, ind_gua_owner, ind_gua_amt)
VALUES
-- ==================== 用户A：正常还款场景 ====================
-- 订单1，期次1-3，正常按期还款，无退款
('20260326', 'UID_A001', '张三', 'BILL_20260101_001', '1', 'TERM_001_1', 'ASSET_XY_001', '兴业银行信托',
 1000.00, 80.00, 15.00, 5.00, 0.00, 0.00, 0.00, 1100.00,
 '2026-01-15', 0.00, 900.00, 850.00,
 1, '重庆市分众小额贷款有限公司', 30.00, '兴业银行', 50.00, '中合担保', 200.00),

('20260326', 'UID_A001', '张三', 'BILL_20260101_001', '2', 'TERM_001_2', 'ASSET_XY_001', '兴业银行信托',
 1000.00, 75.00, 14.00, 5.00, 0.00, 0.00, 0.00, 1094.00,
 '2026-02-15', 0.00, 890.00, 845.00,
 1, '重庆市分众小额贷款有限公司', 28.00, '兴业银行', 47.00, '中合担保', 204.00),

('20260326', 'UID_A001', '张三', 'BILL_20260101_001', '3', 'TERM_001_3', 'ASSET_XY_001', '兴业银行信托',
 1000.00, 70.00, 13.00, 5.00, 0.00, 0.00, 0.00, 1088.00,
 '2026-03-15', 0.00, 880.00, 840.00,
 1, '重庆市分众小额贷款有限公司', 26.00, '兴业银行', 44.00, '中合担保', 208.00),

-- ==================== 用户B：含退款场景 ====================
-- 订单2，期次1-2，有结清返现退款
('20260326', 'UID_B002', '李四', 'BILL_20260201_002', '1', 'TERM_002_1', 'ASSET_MS_002', '民生银行直连',
 2000.00, 150.00, 30.00, 10.00, 0.00, 0.00, 0.00, 2190.00,
 '2026-02-20', 50.00, 1800.00, 1700.00,
 1, '重庆市分众小额贷款有限公司', 55.00, '民生银行', 95.00, '华安担保', 340.00),

('20260326', 'UID_B002', '李四', 'BILL_20260201_002', '2', 'TERM_002_2', 'ASSET_MS_002', '民生银行直连',
 2000.00, 140.00, 28.00, 10.00, 0.00, 0.00, 0.00, 2178.00,
 '2026-03-20', 50.00, 1780.00, 1680.00,
 1, '重庆市分众小额贷款有限公司', 52.00, '民生银行', 88.00, '华安担保', 348.00),

-- ==================== 用户C：含逾期罚息场景 ====================
-- 订单3，期次1，有滞纳金和罚息
('20260326', 'UID_C003', '王五', 'BILL_20260115_003', '1', 'TERM_003_1', 'ASSET_ZS_003', '招商银行ABS',
 1500.00, 120.00, 22.00, 8.00, 30.00, 15.00, 0.00, 1695.00,
 '2026-02-28', 0.00, 1400.00, 1350.00,
 1, '重庆市分众小额贷款有限公司', 45.00, '招商银行', 75.00, '中合担保', 295.00),

-- ==================== 用户D：提前还款场景 ====================
-- 订单4，期次1，有提前还款手续费
('20260326', 'UID_D004', '赵六', 'BILL_20260120_004', '1', 'TERM_004_1', 'ASSET_PA_004', '平安银行信托',
 5000.00, 200.00, 50.00, 20.00, 0.00, 0.00, 100.00, 5370.00,
 '2026-02-10', 30.00, 4500.00, 4300.00,
 1, '重庆市分众小额贷款有限公司', 75.00, '平安银行', 125.00, '华安担保', 840.00),

-- ==================== 用户E：债转场景（资方变更） ====================
-- 订单5，期次1-2，债转后资方ID变更
('20260326', 'UID_E005', '孙七', 'BILL_20260210_005', '1', 'TERM_005_1', 'ASSET_GS_005', '工商银行信托',
 3000.00, 200.00, 45.00, 15.00, 0.00, 0.00, 0.00, 3260.00,
 '2026-03-10', 0.00, 2700.00, 2600.00,
 1, '重庆市分众小额贷款有限公司', 70.00, '工商银行', 130.00, '中合担保', 560.00),

('20260326', 'UID_E005', '孙七', 'BILL_20260210_005', '2', 'TERM_005_2', 'ASSET_GS_005_NEW', '工商银行信托(承接)',
 3000.00, 185.00, 42.00, 15.00, 0.00, 0.00, 0.00, 3242.00,
 '2026-04-05', 0.00, 2680.00, 2580.00,
 1, '重庆市分众小额贷款有限公司', 65.00, '工商银行', 120.00, '中合担保', 562.00),

-- ==================== 用户F：含AMC费用 + 退款综合场景 ====================
-- 订单6，期次1，含较大AMC费用和退款
('20260326', 'UID_F006', '周八', 'BILL_20260305_006', '1', 'TERM_006_1', 'ASSET_ZX_006', '中信银行直连',
 800.00, 60.00, 12.00, 25.00, 0.00, 0.00, 0.00, 897.00,
 '2026-03-25', 20.00, 700.00, 660.00,
 1, '重庆市分众小额贷款有限公司', 22.00, '中信银行', 38.00, '华安担保', 177.00),

-- ==================== 不同日期分区数据（验证 ds 过滤） ====================
('20260327', 'UID_A001', '张三', 'BILL_20260101_001', '1', 'TERM_001_1', 'ASSET_XY_001', '兴业银行信托',
 1000.00, 80.00, 15.00, 5.00, 0.00, 0.00, 0.00, 1100.00,
 '2026-01-15', 0.00, 900.00, 850.00,
 1, '重庆市分众小额贷款有限公司', 30.00, '兴业银行', 50.00, '中合担保', 200.00)
;


-- ============================================================
-- 3. 验证查询（模拟原视图使用方式）
-- ============================================================

-- 按日期查询全量
SELECT * FROM t_invoice_query_joint_loan_term_repayment_detail_v2 WHERE ds = '20260326';

-- 按订单号查询
SELECT * FROM t_invoice_query_joint_loan_term_repayment_detail_v2 WHERE ds = '20260326' AND order_no = 'BILL_20260101_001';

-- 按用户ID查询
SELECT * FROM t_invoice_query_joint_loan_term_repayment_detail_v2 WHERE ds = '20260326' AND uid = 'UID_B002';

-- 验证担保金额计算：ind_gua_amt = paid_amt - act_rep_tot_amt - refund_amt
SELECT order_no, term_no, paid_amt, act_rep_tot_amt, refund_amt, ind_gua_amt,
       ROUND(paid_amt - act_rep_tot_amt - refund_amt, 2) AS calc_ind_gua_amt,
       CASE WHEN ind_gua_amt = ROUND(paid_amt - act_rep_tot_amt - refund_amt, 2) THEN 'PASS' ELSE 'FAIL' END AS check_result
FROM t_invoice_query_joint_loan_term_repayment_detail_v2
WHERE ds = '20260326';
