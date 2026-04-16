-- ============================================================
-- 视图：联合贷开票查询
-- 用法：SELECT * FROM v_invoice_query_joint_loan_term_repayment_detail_v2 WHERE ds = '20260326'
-- 注意：视图不含 ORDER BY / ${参数}，ds 由外部 WHERE 传入
-- 核心：所有聚合子查询内联到 JOIN，通过 ON x.ds = a.ds 实现分区下推
-- ============================================================
CREATE OR REPLACE VIEW v_invoice_query_joint_loan_term_repayment_detail_v2
AS
with
-- ============ t1: 期次还款明细（锚点，ds 来自主表） ============
t1 as
(
select b.ds                                          as ds
     , b.uid                                         as uid
     , d.cus_nam                                     as cus_nam
     , b.bill_no                                     as order_no
     , b.term_no                                     as term_no
     , b.term_id                                     as term_id
     , c.loan_asset_id                               as loan_asset_id
     , b.paid_prin         / 100.00                  as paid_prin
     , b.paid_int          / 100.00                  as paid_int
     , b.paid_guarantee_fee/ 100.00                  as paid_guarantee_fee
     , b.paid_amc_fee      / 100.00                  as paid_amc_fee
     , b.paid_late_fee     / 100.00                  as paid_late_fee
     , b.paid_pen          / 100.00                  as paid_pen
     , b.paid_pre_fee      / 100.00                  as paid_pre_fee
     , b.paid_amt          / 100.00                  as paid_amt
     , b.paid_out_date                               as paid_out_date
from ods_pdw_loan.ods_pdw_loan_dsloankernelali_loancore_cls_term_df b
join dwt.dwt_heavy_order_df c
  on c.ds                = b.ds
 and c.loan_success_flag = '1'
 and b.bill_no           = c.order_no
join dbus.dbus_user_apply_info_df d
  on d.ds  = b.ds
 and d.uid = b.uid
where b.paid_amt > 0
),

-- ============ t2: 关联退款 + whether_amc ============
-- 退款拆为两个独立 LEFT JOIN（取代原 FULL JOIN），内联聚合子查询
t2 as
(
select a.ds                          as ds
     , a.uid                         as uid
     , a.cus_nam                     as cus_nam
     , a.order_no                    as order_no
     , a.term_no                     as term_no
     , a.term_id                     as term_id
     , a.loan_asset_id               as loan_asset_id
     , a.paid_prin                   as paid_prin
     , a.paid_int                    as paid_int
     , a.paid_guarantee_fee          as paid_guarantee_fee
     , a.paid_amc_fee                as paid_amc_fee
     , a.paid_late_fee               as paid_late_fee
     , a.paid_pen                    as paid_pen
     , a.paid_pre_fee                as paid_pre_fee
     , a.paid_amt                    as paid_amt
     , a.paid_out_date               as paid_out_date
     , coalesce(refund_loan.refund_amt, 0) + coalesce(refund_ext.rebate_amount, 0)  as refund_amt
     , loan_info.whether_amc         as whether_amc
from t1 a
-- 结清返现 + 补偿退款（bill 粒度聚合，内联）
left join
         (
          select ds                                                                        as ds
               , bill_no                                                                   as bill_no
               , sum(coalesce(sch_refund_amt, 0) + coalesce(tot_compensate_refund, 0)) / 100.00 as refund_amt
          from ods_pdw_loan.ods_pdw_loan_dsloankernelali_loancore_cls_loan_df
          group by ds, bill_no
         ) refund_loan
      on refund_loan.ds      = a.ds
     and refund_loan.bill_no = a.order_no
-- 返利退款（bill 粒度聚合，内联）
left join
         (
          select ds                                    as ds
               , bill_no                               as bill_no
               , sum(rebated_amt) / 100.00             as rebate_amount
          from ods_pdw_loan.ods_pdw_loan_dsloankernelali_loancore_cls_term_ext_df
          group by ds, bill_no
         ) refund_ext
      on refund_ext.ds      = a.ds
     and refund_ext.bill_no = a.order_no
-- whether_amc（直接关联，无需聚合）
left join ods_pdw_loan.ods_pdw_loan_dsloankernelali_loancore_cls_loan_df loan_info
       on loan_info.ds      = a.ds
      and loan_info.bill_no = a.order_no
),

-- ============ t3: 关联资方信息 ============
t3 as
(
select a.ds                                                              as ds
     , a.uid                                                             as uid
     , a.cus_nam                                                         as cus_nam
     , a.order_no                                                        as order_no
     , a.term_no                                                         as term_no
     , a.term_id                                                         as term_id
     , coalesce(transfer.asset_id, a.loan_asset_id)                     as loan_asset_id
     , a.paid_prin                                                       as paid_prin
     , a.paid_int                                                        as paid_int
     , a.paid_guarantee_fee                                              as paid_guarantee_fee
     , a.paid_amc_fee                                                    as paid_amc_fee
     , a.paid_late_fee                                                   as paid_late_fee
     , a.paid_pen                                                        as paid_pen
     , a.paid_pre_fee                                                    as paid_pre_fee
     , a.paid_amt                                                        as paid_amt
     , a.paid_out_date                                                   as paid_out_date
     , a.refund_amt                                                      as refund_amt
     , case when transfer.stage_order_no is null
            then coalesce(repay.act_rep_tot_amt / 100.00, fund_stage.actual_repaid_total_amount)
            else transfer.actual_repaid_total_amount
       end                                                               as act_rep_tot_amt
     , case when transfer.stage_order_no is null
            then coalesce(repay.act_rep_pri / 100.00, fund_stage.schedule_principal)
            else transfer.actual_repaid_principal
       end                                                               as act_rep_pri
     , a.whether_amc                                                     as whether_amc
from t2 a
-- 资方还款计划（取 rn=1，内联）
left join
         (
          select ds            as ds
               , stg_ord_no    as stg_ord_no
               , stg_no        as stg_no
               , act_rep_tot_amt as act_rep_tot_amt
               , act_rep_pri   as act_rep_pri
          from
             (
              select ds
                   , stg_ord_no
                   , stg_no
                   , act_rep_tot_amt
                   , act_rep_pri
                   , row_number() over(partition by ds, stg_ord_no, stg_no order by act_rep_tot_amt desc) as rn
              from ads_app_fundcore.ads_app_fundcore_repay_plan_process_nrt_hvy
             ) t
          where rn = 1
         ) repay
      on repay.ds          = a.ds
     and repay.stg_ord_no  = a.order_no
     and repay.stg_no      = a.term_no
-- 资方分期计划（直接关联）
left join cdmx.cdmx_fct_heavy_fund_stage_plan_df fund_stage
       on fund_stage.ds        = a.ds
      and fund_stage.order_no  = a.order_no
      and fund_stage.stage_no  = a.term_no
      and fund_stage.fund_code is not null
-- 债转资方分期计划（内联聚合）
left join
         (
          /*
          1. 双池信托订单在资方分期计划表里每笔分期会记两次（放款池和承接池），金额也会记两次
          2. actual_label 只会在实际结算的资方记录，债转前记录在放款池，债转后记录在承接池
          3. pdm_acctops.pdm_acctops_transfer_stage_plan_basic_df 为涉及债转资方的分期计划表
          */
          select p.ds                                                             as ds
               , p.stage_order_no                                                 as stage_order_no
               , p.stage_no                                                       as stage_no
               , case when q.is_transfer_plan = '1' then q.und_asset_id
                      when q.is_transfer_plan = '0' then q.ori_asset_id
                 end                                                              as asset_id
               , date(p.fund_repaid_time)                                         as fund_repaid_time
               , sum(p.actual_repaid_principal)    / 100.00                       as actual_repaid_principal
               , sum(p.actual_repaid_total_amount) / 100.00                       as actual_repaid_total_amount
          from ods_pdw_loan.ods_pdw_loan_dsfundwallali_capitalaccount_repay_plan_df p
          join pdm_acctops.pdm_acctops_transfer_stage_plan_basic_df q
            on q.ds              = p.ds
           and q.stage_order_no  = p.stage_order_no
           and q.stage_no        = p.stage_no
          where p.actual_label in ('compensatory', 'buyback', 'benefit')
          group by p.ds
               , p.stage_order_no
               , p.stage_no
               , case when q.is_transfer_plan = '1' then q.und_asset_id
                      when q.is_transfer_plan = '0' then q.ori_asset_id
                 end
               , date(p.fund_repaid_time)
         ) transfer
      on transfer.ds              = a.ds
     and transfer.stage_order_no  = a.order_no
     and transfer.stage_no        = a.term_no
),

-- ============ t7: 关联子贷标记 + 资方基础配置 ============
t7 as
(
select a.ds                                                as ds
     , a.uid                                               as uid
     , a.cus_nam                                           as cus_nam
     , a.order_no                                          as order_no
     , a.term_no                                           as term_no
     , a.term_id                                           as term_id
     , a.loan_asset_id                                     as loan_asset_id
     , config.asset_name                                   as asset_name
     , a.paid_prin                                         as paid_prin
     , a.paid_int                                          as paid_int
     , a.paid_guarantee_fee                                as paid_guarantee_fee
     , a.paid_amc_fee                                      as paid_amc_fee
     , a.paid_late_fee                                     as paid_late_fee
     , a.paid_pen                                          as paid_pen
     , a.paid_pre_fee                                      as paid_pre_fee
     , a.paid_amt                                          as paid_amt
     , a.paid_out_date                                     as paid_out_date
     , a.refund_amt                                        as refund_amt
     , a.act_rep_tot_amt                                   as act_rep_tot_amt
     , a.act_rep_pri                                       as act_rep_pri
     , config.fund_name                                    as fund_name
     , case when sub_loan.main_bill_no is not null then 1
            else 0
       end                                                 as is_lhd
     , a.whether_amc                                       as whether_amc
from t3 a
-- 联合贷子贷标记（内联聚合）
left join
         (
          select ds              as ds
               , main_bill_no    as main_bill_no
          from ods_pdw_loan.ods_pdw_loan_dsloankernel_loancore_cls_sub_loan_df
          group by ds, main_bill_no
         ) sub_loan
      on sub_loan.ds            = a.ds
     and sub_loan.main_bill_no  = a.order_no
-- 资方基础配置（直接关联）
left join pdm_fund.pdm_fund_zjpz_basicconfig_new_di config
       on config.ds       = a.ds
      and config.asset_id = a.loan_asset_id
)

-- ============ 最终输出 ============
select a.ds                                                                                          as ds
     , a.uid                                                                                         as uid
     , a.cus_nam                                                                                     as cus_nam
     , a.order_no                                                                                    as order_no
     , a.term_no                                                                                     as term_no
     , a.term_id                                                                                     as term_id
     , a.loan_asset_id                                                                               as loan_asset_id
     , a.asset_name                                                                                  as asset_name
     , round(a.paid_prin,          2)                                                               as paid_prin
     , round(a.paid_int,           2)                                                               as paid_int
     , round(a.paid_guarantee_fee, 2)                                                               as paid_guarantee_fee
     , round(a.paid_amc_fee,       2)                                                               as paid_amc_fee
     , round(a.paid_late_fee,      2)                                                               as paid_late_fee
     , round(a.paid_pen,           2)                                                               as paid_pen
     , round(a.paid_pre_fee,       2)                                                               as paid_pre_fee
     , round(a.paid_amt,           2)                                                               as paid_amt
     , a.paid_out_date                                                                               as paid_out_date
     , round(a.refund_amt,         2)                                                               as refund_amt
     , round(a.act_rep_tot_amt,    2)                                                               as act_rep_tot_amt
     , round(a.act_rep_pri,        2)                                                               as act_rep_pri
     , 1                                                                                             as guarantee_rate
     , '重庆市分众小额贷款有限公司'                                                                    as lead_name
     , round(sub_repay.lead_amt,   2)                                                               as lead_amt
     , a.fund_name                                                                                   as fund_name
     , round(sub_repay.fund_amt,   2)                                                               as fund_amt
     , guarantee.guarantee_company                                                                   as ind_gua_owner
     , round(coalesce(a.paid_amt, 0) - coalesce(a.act_rep_tot_amt, 0) - coalesce(a.refund_amt, 0), 2) as ind_gua_amt
from t7 a
-- 子还款计划拆分（��联聚合）
left join
         (
          select ds             as ds
               , stg_ord_no     as stg_ord_no
               , stg_no         as stg_no
               , sum(case when sub_fud     like '%FOCUS_LOAN%' then rep_int end) / 100.00 as lead_amt
               , sum(case when sub_fud not like '%FOCUS_LOAN%' then rep_int end) / 100.00 as fund_amt
          from ads_app_fundcore.ads_app_fundcore_sub_repay_plan_process_nrt_hvy
          group by ds, stg_ord_no, stg_no
         ) sub_repay
      on sub_repay.ds          = a.ds
     and sub_repay.stg_ord_no  = a.order_no
     and sub_repay.stg_no      = a.term_no
-- 担保信息（直接关联）
left join ods_pdw_loan.ods_pdw_loan_dsguaranteecore_guaranteecore_guarantee_stage_order_df guarantee
       on guarantee.ds                     = a.ds
      and guarantee.main_guarantee_company = 1
      and guarantee.stage_order_no         = a.order_no
where a.is_lhd = 1
;
