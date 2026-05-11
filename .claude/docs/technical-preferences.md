# 技术偏好

<!-- 引擎锁定后填充，随开发决策更新。 -->
<!-- 所有代理参考此文件获取项目标准和约定。 -->

## 引擎与语言

- **Engine（引擎）**: Godot 4.6.2
- **Language（语言）**: GDScript（主要），GDExtension/C++（性能关键场景）
- **Rendering（渲染）**: D3D12（Windows 默认），Vulkan（可选）
- **Physics（物理）**: Jolt Physics（3D 默认）

## 命名约定（Naming Conventions）

- **Classes（类）**: PascalCase（如 `PlayerController`）
- **Variables（变量）**: snake_case（如 `move_speed`）
- **Functions（函数）**: snake_case（如 `take_damage()`）
- **Signals/Events（信号/事件）**: snake_case 过去时（如 `health_changed`）
- **Files（文件）**: snake_case 与类名匹配（如 `player_controller.gd`）
- **Scenes/Prefabs（场景/预制体）**: PascalCase 与根节点匹配（如 `PlayerController.tscn`）
- **Constants（常量）**: UPPER_SNAKE_CASE（如 `MAX_HEALTH`）

## 性能预算（Performance Budgets）

- **Target Framerate（目标帧率）**: 60 fps
- **Frame Budget（帧预算）**: 16.6 ms
- **Draw Calls（绘制调用）**: [待配置 — 像素风格游戏预估较低]
- **Memory Ceiling（内存上限）**: [待配置]

## 测试

- **Framework（框架）**: GUT（Godot Unit Testing）
- **Minimum Coverage（最低覆盖率）**: [待配置]
- **Required Tests（必需测试）**: 平衡公式、游戏系统、网络（如适用）

## 禁用模式（Forbidden Patterns）

- 禁止在 `_process`/`_physics_process` 中调用 `get_node()` 或 `get_tree().get_nodes_in_group()`
- 禁止在热路径中分配新对象或数组
- 禁止子节点直接调用父节点方法（Signal Up, Call Down）
- 禁止硬编码游戏数值（伤害、血量等必须外部配置）
- 禁止无类型的变量和数组声明

## 允许的库 / 插件（Allowed Libraries / Addons）

- [尚未配置 — 在批准依赖后添加]

## 架构决策日志（Architecture Decisions Log）

- [尚无 ADR — 使用 /architecture-decision 创建]
