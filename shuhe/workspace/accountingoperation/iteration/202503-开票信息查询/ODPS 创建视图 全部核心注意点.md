## 一、视图最基础规则

1. **视图不能写 ORDER BY**
    
    - 视图 / 子查询里 **不能单独用 ORDER BY**
    - 必须用只能 **ORDER BY + LIMIT**
    - 最佳实践：**视图内部不排序，查询时再排序**
    
2. **视图不能带动态参数**
    
    - 不能写 `${bizdate}`、`${变量}`
    - 分区字段 `ds` 必须 **从外部查询传入**
    
3. **视图必须字段清晰**
    
    - 所有字段必须有别名
    - 不能有 `select *`（生产规范）
    - 不能有字段重复、歧义
    

---

## 二、GROUP BY 必守规则（你这次踩最多）

1. **SELECT 里的每一个非聚合字段，必须出现在 GROUP BY 里**
2. **CASE WHEN 字段也要写进 GROUP BY**
3. **关联表的字段（b.xxx）如果出现在 SELECT，必须进 GROUP BY**
4. **不要在 GROUP BY 里放复杂逻辑，尽量先算好再分组**
5. 聚合函数（SUM/COUNT/MAX）不受 GROUP BY 限制

错误示例：

sql

```
SELECT a.id, b.name, SUM(amt)   --> b.name 没在 GROUP BY 里 → 报错
FROM t1 a
GROUP BY a.id
```

---

## 三、分区字段 ds 正确用法（你这次核心需求）

1. **视图内部不要写死 ds = ${bizdate}**
2. **视图必须把 ds 作为普通字段查询出来**
3. **所有关联表必须用 ds 关联**
4. **查询视图时再传入 ds**

正确结构：

sql

```
-- 视图里
SELECT ds, id, name FROM table

-- 查询时
SELECT * FROM 视图
WHERE ds = '20260326'  --> 外部传入
```

---

## 四、JOIN 关联注意点

1. **分区表必须用 ds 关联**
2. 关联字段必须一一对应
3. 左连接 / 右连接不要产生字段歧义
4. 不要在视图里做过度复杂的多层 JOIN

---

## 五、字段不存在错误（Column Not Found）

1. 别名写错
2. 子查询里没带出这个字段
3. 表关联错误导致字段找不到
4. 大小写问题（ODPS 不区分，但尽量统一）

---

## 六、创建视图语法

1. 已存在视图用 **CREATE OR REPLACE VIEW**
2. 不要用 CREATE VIEW（容易报已存在错误）
3. 视图名不要和表名重复
4. 字段数量、顺序在 UNION ALL 里必须完全一致

---

## 七、UNION ALL 注意点

1. 前后 SELECT **字段数量必须一样**
2. **字段类型必须匹配**
3. 字段顺序必须一致
4. 不要在 UNION ALL 内部排序

---

## 八、生产视图最佳实践（必看）

1. **视图只做逻辑封装，不做排序、不分页**
2. **分区字段 ds 必须暴露给外部查询**
3. 不嵌套过深子查询
4. 不加不必要的计算
5. 所有字段必须有意义别名

---

## 九、LEFT JOIN 子查询不能引用外层字段（Column Not Found）

> 本次实际踩坑：把 `${bizdate}` 替换为 `a.ds` 写在 LEFT JOIN 子查询内部 → 报错 `Column Not Found: A.DS`

1. **ODPS 的 LEFT JOIN (子查询) 不支持关联引用外层表的字段**
    - 这不是 LATERAL JOIN，子查询是独立执行的
    - `WHERE ds = a.ds` 在子查询内部 → **必报错**
2. **正确做法**：子查询自己带出 `ds` 字段，通过 `ON x.ds = a.ds` 在外层关联

错误示例：

```sql
-- ✗ 子查询里引用外层 a.ds → Column Not Found
LEFT JOIN (
    SELECT bill_no, SUM(amt) as total
    FROM some_table
    WHERE ds = a.ds          -- ← 报错！子查询无法看到外层的 a
    GROUP BY bill_no
) b ON a.order_no = b.bill_no
```

正确示例：

```sql
-- ✓ 子查询自带 ds，外层 ON 关联
LEFT JOIN (
    SELECT ds, bill_no, SUM(amt) as total
    FROM some_table
    GROUP BY ds, bill_no     -- ← ds 作为普通字段带出
) b ON b.ds = a.ds AND a.order_no = b.bill_no
```

---

## 十、分区表全扫描禁止（Full Scan Error）

> 本次实际踩坑：独立 CTE 对分区表 `GROUP BY ds, bill_no` 但无 `WHERE ds = ...` → ODPS 拒绝创建视图

1. **ODPS 要求分区表必须有分区谓词**，否则报 `full scan with all partitions`
2. **独立 CTE 不能全分区扫描**
    - CTE 是独立执行的，ODPS 无法将外部 `WHERE ds` 下推到独立 CTE 内部
    - 即使 CTE 里 `GROUP BY ds`，后面 `ON x.ds = a.ds`，ODPS 静态分析阶段仍判定为全扫描
3. **正确做法：不用独立 CTE，改为内联子查询放在 JOIN 里**
    - 内联子查询 + `ON x.ds = a.ds`，ODPS 可通过 equi-join 做 Dynamic Partition Pruning（DPP）
    - 外部 `WHERE ds = '20260326'` 能沿着 JOIN 链一路下推到每个子查询的表扫描

错误示例（独立 CTE → 全扫描报错）：

```sql
-- ✗ 独立 CTE，无 WHERE ds → ODPS 拒绝
WITH cte_refund AS (
    SELECT ds, bill_no, SUM(amt)/100 as refund_amt
    FROM ods_loan_table
    GROUP BY ds, bill_no             -- ← 没有 WHERE ds，全分区扫描
)
SELECT a.*, b.refund_amt
FROM t1 a
LEFT JOIN cte_refund b ON b.ds = a.ds AND b.bill_no = a.order_no
```

正确示例（内联子查询 → 分区下推）：

```sql
-- ✓ 内联到 JOIN 里，ON 条件包含 ds，ODPS 可下推
SELECT a.*, refund.refund_amt
FROM t1 a
LEFT JOIN (
    SELECT ds, bill_no, SUM(amt)/100 as refund_amt
    FROM ods_loan_table
    GROUP BY ds, bill_no
) refund ON refund.ds = a.ds AND refund.bill_no = a.order_no
-- 查询 WHERE ds = '20260326' → 下推到 t1 → 通过 ON 下推到 refund 子查询
```

4. **分区下推链路**：外部 WHERE ds → 主表锚点 ds → ON x.ds = a.ds → 每个内联子查询的表扫描
5. **`set odps.sql.allow.fullscan=true` 不推荐**：虽然能绕过创建检查，但查询时仍可能全扫描，性能极差

---

## 十一、Catalog Not Found 错误

> 本次实际踩坑：视图名写了不存在的项目前缀 `ads_acctops.view_name` → Catalog Not Found

1. **视图名的项目前缀必须是当前有权限的 ODPS Project**
2. 如果只在当前项目建视图，**不需要加项目前缀**，直接写视图名
3. 跨项目建视图需要确认目标项目存在且有 CREATE VIEW 权限

---

## 十二、FULL JOIN 退款合并的替代方案

> 本次实际踩坑：两个退款来源用 FULL JOIN 合并，改视图后增加复杂度

1. 当多个数据源最终都要 LEFT JOIN 到同一个主表时
2. **可以拆成多个独立 LEFT JOIN**，用 `COALESCE` 合并金额
3. 效果等价，且每个 JOIN 独立，更利于分区下推

```sql
-- ✗ 原方案：先 FULL JOIN 退款，再整体关联
LEFT JOIN (refund_a FULL JOIN refund_b ON ...) ON ...

-- ✓ 优化方案：分别 LEFT JOIN，COALESCE 合并
LEFT JOIN (退款来源A聚合) refund_a ON refund_a.ds = a.ds AND ...
LEFT JOIN (退款来源B聚合) refund_b ON refund_b.ds = a.ds AND ...
-- SELECT 里：COALESCE(refund_a.amt, 0) + COALESCE(refund_b.amt, 0) as total_refund
```

---

# 最终 14 条黄金口诀（背会永不报错）

1. 视图 **不加 ORDER BY**
2. 视图 **不加 ${参数}**
3. **ds 从外部传，不写死**
4. **SELECT 有啥，GROUP BY 有啥**
5. **关联表必须带 ds**
6. **字段必须别名，不能重复**
7. **UNION 前后字段数量、类型一致**
8. **用 CREATE OR REPLACE VIEW**
9. **不写 SELECT \***
10. **复杂逻辑拆 CTE，不嵌套**
11. **子查询不能引用外层字段（非 LATERAL JOIN）**
12. **分区表禁止全扫描，聚合子查询内联到 JOIN 里**
13. **视图名不加不存在的项目前缀**
14. **FULL JOIN 能拆就拆成多个 LEFT JOIN**