# 会计核算运营系统 - 基线文档索引

本文档是会计核算运营系统（accountingoperation）的基线文档索引，包含项目架构、数据库结构、接口流程、调度任务和业务流的完整文档。

---

## 📚 文档导航

### 1. 项目概览

| 文档 | 说明 | 路径 |
|-----|------|------|
| 项目工程结构 | 模块结构、包组织、技术栈 | [01-项目工程结构.md](01-项目工程结构.md) |
| 数据库结构 | 三数据库架构、表结构、Mapper | [02-数据库结构.md](02-数据库结构.md) |

### 2. 核心流程文档

| 流程名称   | 文档                                   | 说明          |
| ------ | ------------------------------------ | ----------- |
| 工单调账流程 | [06-核心流程详情/工单调账核心流程.md](工单调账核心流程.md) | 完整的调账工单处理流程 |


---

## 📊 项目统计

| 类别 | 数量 | 说明 |
|-----|------|------|
| Controllers | 33 | REST 控制器 |
| Services | 229+ | 业务服务 |
| Scheduled Jobs | 72+ | 定时任务 |
| BizFlow Processes | 70+ | 业务流程节点 |
| Pipeline Processes | 6 | 流水线流程 |
| Mappers | 86+ | MyBatis Mapper |
| Domain Classes | 180+ | 领域实体 |
| Databases | 3 | 主库、数仓、DataHub |
| Business Domains | 15+ | 业务域 |

---

### Git 仓库

- **仓库路径**: `/Users/wangtaotao/Documents/workspace_v2/new3/accountingoperation`
- **主分支**: `master`

---

## 📝 文档维护

### 基线文档 (Baseline)

**路径**: `/Users/wangtaotao/Documents/Obsidian Vault/shuhe/workspace/accountingoperation/base/`

**用途**: 稳定的、跨版本的参考文档，包括：
- 架构设计
- 数据库结构
- 核心业务流程
- API 接口文档
- 调度任务说明
- 业务流定义

### 迭代文档 (Iteration)

**路径**: `/Users/wangtaotao/Documents/Obsidian Vault/shuhe/workspace/accountingoperation/iteration/`

**用途**: 特定功能的、有时效性的文档，包括：
- 新功能开发文档
- 迭代需求文档
- 实现说明
- 测试文档

---

## 🔄 文档更新记录

| 日期 | 版本 | 更新内容 |
|-----|------|---------|
| 2025-02-24 | v1.0 | 初始版本，创建基线文档结构 |
| 2025-02-24 | v1.1 | 添加核心流程索引和工单调账流程文档 |


---

**文档版本**: v1.0
**最后更新**: 2025-02-24
**维护人员**: Claude Code