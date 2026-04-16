-- ============================================================
-- 测试表：非联合贷开票查询（替代视图 v_invoice_query_not_joint_loan_term_repayment_detail_v2）
-- 包含：标准助贷 + AMC 两类数据（对应原视图 t5 UNION ALL t6）
-- 用于本地环境直接查表测试
-- ============================================================

-- 1. 建表语句
DROP TABLE IF EXISTS t_invoice_query_not_joint_loan_term_repayment_detail_v2;

CREATE TABLE t_invoice_query_not_joint_loan_term_repayment_detail_v2 (
    ds                    VARCHAR(10)     COMMENT '分区日期 yyyyMMdd',
    uid                   VARCHAR(64)     COMMENT '用户ID',
    cus_nam               VARCHAR(128)    COMMENT '客户姓名',
    order_no              VARCHAR(64)     COMMENT '订单号(bill_no)',
    term_no               VARCHAR(10)     COMMENT '期次编号',
    term_id               VARCHAR(64)     COMMENT '期次ID',
    loan_asset_id         VARCHAR(64)     COMMENT '资方资产ID',
    asset_name            VARCHAR(128)    COMMENT '资方资产名称',
    paid_prin             DECIMAL(18,2)   COMMENT '已还本金',
    paid_int              DECIMAL(18,2)   COMMENT '已还利息',
    paid_guarantee_fee    DECIMAL(18,2)   COMMENT '已还担保费',
    paid_amc_fee          DECIMAL(18,2)   COMMENT '已还AMC费用',
    paid_late_fee         DECIMAL(18,2)   COMMENT '已还滞纳金',
    paid_pen              DECIMAL(18,2)   COMMENT '已还罚息',
    paid_pre_fee          DECIMAL(18,2)   COMMENT '已还提前还款手续费',
    paid_amt              DECIMAL(18,2)   COMMENT '已还总金额',
    paid_out_date         VARCHAR(20)     COMMENT '还款日期',
    refund_amt            DECIMAL(18,2)   COMMENT '退款金额(结清返现+补偿退款+返利退款)',
    act_rep_tot_amt       DECIMAL(18,2)   COMMENT '资方实还总额',
    act_rep_pri           DECIMAL(18,2)   COMMENT '资方实还本金',
    guarantee_rate        DECIMAL(10,4)   COMMENT '担保比例(已除100)',
    ord_typ               VARCHAR(20)     COMMENT '订单类型: 标准助贷 / AMC',
    fund_name             VARCHAR(128)    COMMENT '资方名称(小贷时为重庆市分众小额贷款有限公司)',
    bank_amt              DECIMAL(18,2)   COMMENT '资方/银行金额',
    ind_gua_owner         VARCHAR(128)    COMMENT '独立担保公司',
    ind_gua_amt           DECIMAL(18,2)   COMMENT '独立担保金额',
    uni_gua_main_owner    VARCHAR(128)    COMMENT '联合担保-主担保公司',
    uni_gua_main_amt      DECIMAL(18,2)   COMMENT '联合担保-主担保金额',
    uni_gua_follow_owner  VARCHAR(128)    COMMENT '联合担保-跟随担保公司',
    uni_gua_follow_amt    DECIMAL(18,2)   COMMENT '联合担保-跟随担保金额',
    amc_name              VARCHAR(128)    COMMENT 'AMC公司名称(标准助贷为空)',
    amc_amt               DECIMAL(18,2)   COMMENT 'AMC金额(标准助贷为空)',
    PRIMARY KEY (ds, order_no, term_no)
) COMMENT = '非联合贷开票查询测试表(标准助贷+AMC)';


-- ============================================================
-- 2. 初始化测试数据
-- ============================================================
INSERT INTO t_invoice_query_not_joint_loan_term_repayment_detail_v2
(ds, uid, cus_nam, order_no, term_no, term_id, loan_asset_id, asset_name,
 paid_prin, paid_int, paid_guarantee_fee, paid_amc_fee, paid_late_fee, paid_pen, paid_pre_fee, paid_amt,
 paid_out_date, refund_amt, act_rep_tot_amt, act_rep_pri,
 guarantee_rate, ord_typ, fund_name, bank_amt, ind_gua_owner, ind_gua_amt,
 uni_gua_main_owner, uni_gua_main_amt, uni_gua_follow_owner, uni_gua_follow_amt,
 amc_name, amc_amt)
VALUES

-- ======================================================================
-- 标准助贷 - bank_type='小贷' (FOCUS_LOAN不含ZHX)
-- fund_name = 重庆市分众小额贷款有限公司
-- bank_amt = paid_amt - paid_prin - refund_amt
-- 无担保信息
-- ======================================================================
('20260326', 'UID_S001', '张小贷', 'BILL_SL_001', '1', 'TERM_SL_001_1', 'FOCUS_LOAN_ABC', '分众小贷ABC',
 1000.00, 80.00, 0.00, 0.00, 0.00, 0.00, 0.00, 1080.00,
 '2026-01-20', 0.00, NULL, NULL,
 NULL, '标准助贷', '重庆市分众小额贷款有限公司', 80.00, NULL, NULL,
 NULL, NULL, NULL, NULL,
 NULL, NULL),

('20260326', 'UID_S001', '张小贷', 'BILL_SL_001', '2', 'TERM_SL_001_2', 'FOCUS_LOAN_ABC', '分众小贷ABC',
 1000.00, 75.00, 0.00, 0.00, 0.00, 0.00, 0.00, 1075.00,
 '2026-02-20', 0.00, NULL, NULL,
 NULL, '标准助贷', '重庆市分众小额贷款有限公司', 75.00, NULL, NULL,
 NULL, NULL, NULL, NULL,
 NULL, NULL),

-- ======================================================================
-- 标准助贷 - bank_type='小贷+担保' (FOCUS_LOAN且含ZHX)
-- fund_name = 重庆市分众小额贷款有限公司
-- bank_amt = act_rep_tot_amt - act_rep_pri
-- ind_gua_owner = 中禾信融资担保(福建)有限公司
-- ind_gua_amt = paid_amt - refund_amt - act_rep_tot_amt
-- ======================================================================
('20260326', 'UID_S002', '李小担', 'BILL_SL_002', '1', 'TERM_SL_002_1', 'FOCUS_LOAN_ZHX_001', '分众小贷ZHX',
 2000.00, 160.00, 30.00, 0.00, 0.00, 0.00, 0.00, 2190.00,
 '2026-02-15', 10.00, 1800.00, 1700.00,
 0.80, '标准助贷', '重庆市分众小额贷款有限公司', 100.00, '中禾信融资担保(福建)有限公司', 380.00,
 NULL, NULL, NULL, NULL,
 NULL, NULL),

-- ======================================================================
-- 标准助贷 - bank_type='非小贷（独立担保）' (非FOCUS_LOAN，担保模式=独立)
-- fund_name = 资方名称
-- bank_amt = act_rep_tot_amt - act_rep_pri
-- ind_gua_owner = 担保公司
-- ind_gua_amt = paid_amt - refund_amt - act_rep_tot_amt
-- ======================================================================
('20260326', 'UID_S003', '王独担', 'BILL_SL_003', '1', 'TERM_SL_003_1', 'ASSET_XY_010', '兴业银行信托',
 3000.00, 240.00, 45.00, 10.00, 0.00, 0.00, 0.00, 3295.00,
 '2026-01-25', 0.00, 2800.00, 2650.00,
 1.00, '标准助贷', '兴业银行', 150.00, '中合担保有限公司', 495.00,
 NULL, NULL, NULL, NULL,
 NULL, NULL),

('20260326', 'UID_S003', '王独担', 'BILL_SL_003', '2', 'TERM_SL_003_2', 'ASSET_XY_010', '兴业银行信托',
 3000.00, 225.00, 42.00, 10.00, 0.00, 0.00, 0.00, 3277.00,
 '2026-02-25', 0.00, 2780.00, 2640.00,
 1.00, '标准助贷', '兴业银行', 140.00, '中合担保有限公司', 497.00,
 NULL, NULL, NULL, NULL,
 NULL, NULL),

-- 含退款 + 逾期场景的独立担保
('20260326', 'UID_S004', '赵逾期', 'BILL_SL_004', '1', 'TERM_SL_004_1', 'ASSET_MS_020', '民生银行直连',
 1500.00, 120.00, 22.00, 8.00, 30.00, 15.00, 0.00, 1695.00,
 '2026-03-10', 25.00, 1400.00, 1300.00,
 1.00, '标准助贷', '民生银行', 100.00, '华安担保有限公司', 270.00,
 NULL, NULL, NULL, NULL,
 NULL, NULL),

-- ======================================================================
-- 标准助贷 - bank_type='非小贷（联合担保）' (非FOCUS_LOAN，担保模式=联合)
-- fund_name = 资方名称
-- bank_amt = act_rep_tot_amt - act_rep_pri
-- uni_gua_main_owner/amt = 主担保公司及金额
-- uni_gua_follow_owner/amt = 跟随担保公司及金额
-- ======================================================================
('20260326', 'UID_S005', '孙联担', 'BILL_SL_005', '1', 'TERM_SL_005_1', 'ASSET_ZS_030', '招商银行ABS',
 5000.00, 400.00, 75.00, 20.00, 0.00, 0.00, 0.00, 5495.00,
 '2026-02-20', 0.00, 4600.00, 4350.00,
 0.70, '标准助贷', '招商银行', 250.00, NULL, NULL,
 '阳光担保有限公司', 52.50, '中禾信融资担保(福建)有限公司', 842.50,
 NULL, NULL),

('20260326', 'UID_S005', '孙联担', 'BILL_SL_005', '2', 'TERM_SL_005_2', 'ASSET_ZS_030', '招商银行ABS',
 5000.00, 380.00, 70.00, 20.00, 0.00, 0.00, 0.00, 5470.00,
 '2026-03-20', 0.00, 4580.00, 4340.00,
 0.70, '标准助贷', '招商银行', 240.00, NULL, NULL,
 '阳光担保有限公司', 49.00, '中禾信融资担保(福建)有限公司', 841.00,
 NULL, NULL),

-- ======================================================================
-- 标准助贷 - 无担保场景 (fund_cfg.guarantee='flase')
-- ======================================================================
('20260326', 'UID_S006', '周无担', 'BILL_SL_006', '1', 'TERM_SL_006_1', 'ASSET_PA_040', '平安银行信托',
 800.00, 60.00, 0.00, 5.00, 0.00, 0.00, 0.00, 865.00,
 '2026-03-15', 0.00, 750.00, 710.00,
 NULL, '标准助贷', '平安银行', 40.00, '无担保', NULL,
 NULL, NULL, NULL, NULL,
 NULL, NULL),

-- ======================================================================
-- 标准助贷 - 提前还款场景
-- ======================================================================
('20260326', 'UID_S007', '吴提前', 'BILL_SL_007', '1', 'TERM_SL_007_1', 'ASSET_GS_050', '工商银行信托',
 8000.00, 350.00, 100.00, 30.00, 0.00, 0.00, 150.00, 8630.00,
 '2026-02-05', 50.00, 7200.00, 6900.00,
 1.00, '标准助贷', '工商银行', 300.00, '中合担保有限公司', 1380.00,
 NULL, NULL, NULL, NULL,
 NULL, NULL),

-- ======================================================================
-- AMC 订单
-- ord_typ = 'AMC'
-- amc_amt = paid_amc_fee + paid_pre_fee + paid_pen
-- bank_amt = act_rep_tot_amt - act_rep_pri
-- ind_gua_amt = paid_amt - act_rep_tot_amt - paid_amc_fee - paid_pre_fee - paid_pen - refund_amt
-- 联合担保字段为空
-- ======================================================================
('20260326', 'UID_A001', '郑AMC一', 'BILL_AMC_001', '1', 'TERM_AMC_001_1', 'ASSET_AMC_XY_001', '兴业银行AMC',
 2000.00, 150.00, 30.00, 50.00, 0.00, 10.00, 0.00, 2240.00,
 '2026-02-28', 0.00, 1900.00, 1800.00,
 1.00, 'AMC', '兴业银行', 100.00, '中合担保有限公司', 280.00,
 NULL, NULL, NULL, NULL,
 '东方资产管理公司', 60.00),

('20260326', 'UID_A001', '郑AMC一', 'BILL_AMC_001', '2', 'TERM_AMC_001_2', 'ASSET_AMC_XY_001', '兴业银行AMC',
 2000.00, 140.00, 28.00, 48.00, 0.00, 8.00, 0.00, 2224.00,
 '2026-03-28', 0.00, 1880.00, 1790.00,
 1.00, 'AMC', '兴业银行', 90.00, '中合担保有限公司', 288.00,
 NULL, NULL, NULL, NULL,
 '东方资产管理公司', 56.00),

-- AMC + 逾期 + 退款场景
('20260326', 'UID_A002', '钱AMC二', 'BILL_AMC_002', '1', 'TERM_AMC_002_1', 'ASSET_AMC_MS_002', '民生银行AMC',
 3000.00, 200.00, 45.00, 80.00, 20.00, 15.00, 0.00, 3360.00,
 '2026-03-15', 30.00, 2700.00, 2550.00,
 1.00, 'AMC', '民生银行', 150.00, '华安担保有限公司', 515.00,
 NULL, NULL, NULL, NULL,
 '信达资产管理公司', 115.00),

-- AMC + 提前还款场景
('20260326', 'UID_A003', '冯AMC三', 'BILL_AMC_003', '1', 'TERM_AMC_003_1', 'ASSET_AMC_ZS_003', '招商银行AMC',
 4000.00, 280.00, 60.00, 100.00, 0.00, 0.00, 80.00, 4520.00,
 '2026-02-10', 20.00, 3800.00, 3600.00,
 1.00, 'AMC', '招商银行', 200.00, '阳光担保有限公司', 520.00,
 NULL, NULL, NULL, NULL,
 '华融资产管理公司', 180.00),

-- ======================================================================
-- 不同日期分区数据（验证 ds 过滤）
-- ======================================================================
('20260327', 'UID_S003', '王独担', 'BILL_SL_003', '1', 'TERM_SL_003_1', 'ASSET_XY_010', '兴业银行信托',
 3000.00, 240.00, 45.00, 10.00, 0.00, 0.00, 0.00, 3295.00,
 '2026-01-25', 0.00, 2800.00, 2650.00,
 1.00, '标准助贷', '兴业银行', 150.00, '中合担保有限公司', 495.00,
 NULL, NULL, NULL, NULL,
 NULL, NULL)
;


-- ============================================================
-- 3. 验证查询
-- ============================================================

-- 按日期查询全量
SELECT * FROM t_invoice_query_not_joint_loan_term_repayment_detail_v2 WHERE ds = '20260326';

-- 按订单类型分开查
SELECT * FROM t_invoice_query_not_joint_loan_term_repayment_detail_v2 WHERE ds = '20260326' AND ord_typ = '标准助贷';
SELECT * FROM t_invoice_query_not_joint_loan_term_repayment_detail_v2 WHERE ds = '20260326' AND ord_typ = 'AMC';

-- 按用户查询
SELECT * FROM t_invoice_query_not_joint_loan_term_repayment_detail_v2 WHERE ds = '20260326' AND uid = 'UID_S005';

-- 按订单号查询
SELECT * FROM t_invoice_query_not_joint_loan_term_repayment_detail_v2 WHERE ds = '20260326' AND order_no = 'BILL_AMC_001';

-- 验证标准助贷-小贷: bank_amt = paid_amt - paid_prin - refund_amt
SELECT order_no, term_no, ord_typ, loan_asset_id,
       paid_amt, paid_prin, refund_amt, bank_amt,
       ROUND(paid_amt - paid_prin - refund_amt, 2) AS calc_bank_amt,
       CASE WHEN bank_amt = ROUND(paid_amt - paid_prin - refund_amt, 2) THEN 'PASS' ELSE 'FAIL' END AS check_result
FROM t_invoice_query_not_joint_loan_term_repayment_detail_v2
WHERE ds = '20260326' AND ord_typ = '标准助贷' AND loan_asset_id LIKE '%FOCUS_LOAN%' AND loan_asset_id NOT LIKE '%ZHX%';

-- 验证标准助贷-独立担保: ind_gua_amt = paid_amt - refund_amt - act_rep_tot_amt
SELECT order_no, term_no, ord_typ,
       paid_amt, refund_amt, act_rep_tot_amt, ind_gua_amt,
       ROUND(paid_amt - refund_amt - act_rep_tot_amt, 2) AS calc_ind_gua_amt,
       CASE WHEN ind_gua_amt = ROUND(paid_amt - refund_amt - act_rep_tot_amt, 2) THEN 'PASS' ELSE 'FAIL' END AS check_result
FROM t_invoice_query_not_joint_loan_term_repayment_detail_v2
WHERE ds = '20260326' AND ord_typ = '标准助贷' AND ind_gua_owner IS NOT NULL AND ind_gua_owner <> '无担保';

-- 验证AMC: amc_amt = paid_amc_fee + paid_pre_fee + paid_pen
SELECT order_no, term_no, ord_typ,
       paid_amc_fee, paid_pre_fee, paid_pen, amc_amt,
       ROUND(paid_amc_fee + paid_pre_fee + paid_pen, 2) AS calc_amc_amt,
       CASE WHEN amc_amt = ROUND(paid_amc_fee + paid_pre_fee + paid_pen, 2) THEN 'PASS' ELSE 'FAIL' END AS check_result
FROM t_invoice_query_not_joint_loan_term_repayment_detail_v2
WHERE ds = '20260326' AND ord_typ = 'AMC';

-- 验证AMC: ind_gua_amt = paid_amt - act_rep_tot_amt - paid_amc_fee - paid_pre_fee - paid_pen - refund_amt
SELECT order_no, term_no, ord_typ,
       paid_amt, act_rep_tot_amt, paid_amc_fee, paid_pre_fee, paid_pen, refund_amt, ind_gua_amt,
       ROUND(paid_amt - act_rep_tot_amt - paid_amc_fee - paid_pre_fee - paid_pen - refund_amt, 2) AS calc_ind_gua_amt,
       CASE WHEN ind_gua_amt = ROUND(paid_amt - act_rep_tot_amt - paid_amc_fee - paid_pre_fee - paid_pen - refund_amt, 2) THEN 'PASS' ELSE 'FAIL' END AS check_result
FROM t_invoice_query_not_joint_loan_term_repayment_detail_v2
WHERE ds = '20260326' AND ord_typ = 'AMC';
