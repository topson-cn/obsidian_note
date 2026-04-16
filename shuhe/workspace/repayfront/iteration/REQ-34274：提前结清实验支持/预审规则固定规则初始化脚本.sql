-- ================================================================================
-- 预审规则固定规则初始化脚本
-- 表名: pre_audit_policy
-- 说明: 初始化4条固定规则（FIXED类型）
-- 创建时间: 2026-03-02
-- ================================================================================

-- 清理历史数据（可选，生产环境慎用）
-- DELETE FROM repayfront.pre_audit_policy WHERE rule_type = 'FIXED';

-- ================================================================================
-- 规则1: 白名单匹配
-- 说明: 白名单状态为ACTIVE或NULL的用户，无需审核
-- ================================================================================
INSERT INTO repayfront.pre_audit_policy (
    rule_id,
    rule_name,
    rule_type,
    priority,
    rule_condition,
    status,
    description,
    created_by,
    updated_by,
    created_at,
    updated_at
) VALUES (
    'WHITELIST',
    '白名单匹配',
    'FIXED',
    1,
    NULL,  -- 固定规则不需要rule_condition，逻辑硬编码在代码中
    'ONLINE',
    '白名单状态为ACTIVE或NULL的用户，无需审核',
    'SYSTEM',
    'SYSTEM',
    NOW(),
    NOW()
) ON DUPLICATE KEY UPDATE
    rule_name = VALUES(rule_name),
    priority = VALUES(priority),
    status = VALUES(status),
    description = VALUES(description),
    updated_at = NOW();

-- ================================================================================
-- 规则2: 轻资产订单
-- 说明: 符合轻资产订单特征的用户，无需审核
-- ================================================================================
INSERT INTO repayfront.pre_audit_policy (
    rule_id,
    rule_name,
    rule_type,
    priority,
    rule_condition,
    status,
    description,
    created_by,
    updated_by,
    created_at,
    updated_at
) VALUES (
    'SEAMLESS_V2',
    '轻资产订单',
    'FIXED',
    2,
    NULL,  -- 固定规则不需要rule_condition，逻辑硬编码在代码中
    'ONLINE',
    '符合轻资产订单特征的用户，无需审核',
    'SYSTEM',
    'SYSTEM',
    NOW(),
    NOW()
) ON DUPLICATE KEY UPDATE
    rule_name = VALUES(rule_name),
    priority = VALUES(priority),
    status = VALUES(status),
    description = VALUES(description),
    updated_at = NOW();

-- ================================================================================
-- 规则3: 随借随还订单
-- 说明: 随借随还订单类型的用户，无需审核
-- ================================================================================
INSERT INTO repayfront.pre_audit_policy (
    rule_id,
    rule_name,
    rule_type,
    priority,
    rule_condition,
    status,
    description,
    created_by,
    updated_by,
    created_at,
    updated_at
) VALUES (
    'ANY_REPAY',
    '随借随还订单',
    'FIXED',
    3,
    NULL,  -- 固定规则不需要rule_condition，逻辑硬编码在代码中
    'ONLINE',
    '随借随还订单类型的用户，无需审核',
    'SYSTEM',
    'SYSTEM',
    NOW(),
    NOW()
) ON DUPLICATE KEY UPDATE
    rule_name = VALUES(rule_name),
    priority = VALUES(priority),
    status = VALUES(status),
    description = VALUES(description),
    updated_at = NOW();

-- ================================================================================
-- 规则4: 当天订单审核通过后二次发起
-- 说明: 当天订单提前结清审核通过后，二次发起提前结清，无需审核
-- ================================================================================
INSERT INTO repayfront.pre_audit_policy (
    rule_id,
    rule_name,
    rule_type,
    priority,
    rule_condition,
    status,
    description,
    created_by,
    updated_by,
    created_at,
    updated_at
) VALUES (
    'SAME_DAY_APPROVED',
    '当天订单审核通过后二次发起',
    'FIXED',
    4,
    NULL,  -- 固定规则不需要rule_condition，逻辑硬编码在代码中
    'ONLINE',
    '当天订单提前结清审核通过后，二次发起提前结清，无需审核',
    'SYSTEM',
    'SYSTEM',
    NOW(),
    NOW()
) ON DUPLICATE KEY UPDATE
    rule_name = VALUES(rule_name),
    priority = VALUES(priority),
    status = VALUES(status),
    description = VALUES(description),
    updated_at = NOW();

-- ================================================================================
-- 验证数据
-- ================================================================================
-- 查看所有固定规则
SELECT
    rule_id AS '规则ID',
    rule_name AS '规则名称',
    rule_type AS '规则类型',
    priority AS '优先级',
    status AS '状态',
    description AS '描述',
    created_at AS '创建时间',
    updated_at AS '更新时间'
FROM repayfront.pre_audit_policy
WHERE rule_type = 'FIXED'
ORDER BY priority ASC;

-- 统计固定规则数量
SELECT
    COUNT(*) AS '固定规则总数',
    SUM(CASE WHEN status = 'ONLINE' THEN 1 ELSE 0 END) AS '在线规则数',
    SUM(CASE WHEN status = 'OFFLINE' THEN 1 ELSE 0 END) AS '离线规则数'
FROM repayfront.pre_audit_policy
WHERE rule_type = 'FIXED';

-- ================================================================================
-- 脚本执行说明
-- ================================================================================
-- 1. 执行环境: MySQL 5.7+
-- 2. 执行权限: 需要repayfront数据库的INSERT权限
-- 3. 幂等性: 使用ON DUPLICATE KEY UPDATE保证重复执行不会报错
-- 4. 注意事项:
--    - rule_id为唯一索引，重复执行会更新已有记录
--    - rule_condition设置为NULL，固定规则逻辑硬编码在代码中
--    - 固定规则的priority范围: 1-10
--    - 可配置规则的priority范围: 11-100
-- 5. 验证: 执行后查看验证SQL，确认4条规则插入成功
-- ================================================================================
