# Claude Code Game Studios -- 游戏工作室代理架构

通过 48 个协同的 Claude Code 子代理管理独立游戏开发。
每个代理负责特定领域，强制关注点分离和质量控制。

## 技术栈

- **引擎**：Godot 4.7
- **语言**：GDScript（主要），GDExtension/C++（性能关键场景）
- **版本控制**：Git，基于主干开发
- **构建系统**：SCons（引擎），Godot 导出模板
- **资产管线**：Godot 导入系统 + 自定义资源管线

> **注意**：Godot、Unity 和 Unreal 都有专属的引擎专家代理，
> 配备专门的子专家。请使用与你引擎匹配的代理集。

## 项目结构

@.claude/docs/directory-structure.md

## 引擎版本参考

@docs/engine-reference/godot/VERSION.md

## 技术偏好

@.claude/docs/technical-preferences.md

## 协调规则

@.claude/docs/coordination-rules.md

## 协作协议

**用户驱动的协作，配合批量授权降低交互成本。**

> **首要原则 — 不确定先问**：遇到任何不确定的地方（需求、方案、范围、取舍），先询问用户、确保双方想法一致后再动手。**大工作尤其必须先对齐**；小工作酌情提问。宁可多问一句，不要凭假设闷头做。

任务粒度协作流程：**提问 -> 选项 -> 决定 -> 草稿 -> 审批 -> 批量执行**

- 任务开始前展示**整体计划与关键决策**，获取批量授权
- 批量授权后，单个文件的 Write/Edit 无需逐次询问
- 在以下 3 类节点必须停下汇报：
  1. **架构决策**：命名冲突、抽象选择、跨模块影响、新建顶层目录
  2. **风险操作**：删除文件、git 提交 / 推送 / 重置、覆盖未读过的文件、修改 CLAUDE.md 或 .claude/ 配置、改动 project.godot
  3. **里程碑**：子任务完成、测试结果出炉、需要用户目视验证
- 没有用户指示，不得进行 git 提交 / 推送

完整协议和示例请参见 `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md`。

> **第一次使用？** 如果项目没有配置引擎且没有游戏概念，
> 运行 `/start` 开始引导式入门流程。

## 编码标准

@.claude/docs/coding-standards.md

## 上下文管理

@.claude/docs/context-management.md
