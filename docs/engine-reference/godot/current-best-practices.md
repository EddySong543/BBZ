# Godot 4.6 GDScript 最佳实践

最后验证：2026-05-10 | 引擎：Godot 4.6.2

自 LLM 训练数据（~4.3）以来新增或变更的实践。本文档补充（而非替代）agent 的内置知识。

---

## 脚本结构模板

```gdscript
extends Node
class_name MyComponent

# 1. Signals / Enums / Constants
signal item_collected(item: ItemResource)

enum State { IDLE, RUNNING, DEAD }
const MAX_HEALTH := 100

# 2. @export / @onready / 属性
@export var speed: float = 200.0
@onready var sprite: Sprite2D = %Sprite2D

# 3. 生命周期方法
func _init() -> void:
    pass

func _ready() -> void:
    pass

# 4. Public 方法
func activate() -> void:
    pass

# 5. Private 方法（_ 前缀）
func _calculate_path() -> Array[Vector2]:
    return []
```

---

## 五条核心原则

| 规则 | 说明 |
|------|------|
| **强类型静态标注** | `var hp: int = 100` 比无类型快 20-40%；`Array[Enemy]` 优于无类型 `Array` |
| **Signal Up, Call Down** | 子节点发射信号，父节点调用子节点方法。绝不用 `get_parent().do_something()` |
| **缓存场景树查找** | 用 `@onready var sprite = $Sprite2D` 或 `%UniqueName`，禁止在 `_process` 中 `get_node()` |
| **字典安全访问** | 用 `dict.get("key", default)` 而非 `dict["key"]` |
| **使用 class_name** | 可复用脚本必须声明 `class_name`，否则无法作为类型使用 |

---

## GDScript 4.5+ 新特性

### @abstract 抽象类

```gdscript
@abstract
class_name BaseEnemy extends CharacterBody2D

@abstract
func get_attack_pattern() -> Array[Attack]:
    pass  # 子类必须重写
```

声明为 `@abstract` 的脚本不能直接挂载到节点上。

### 可变参数 `...args`

```gdscript
func log_all(category: String, ...messages) -> void:
    for msg in messages:
        print("[%s] %s" % [category, msg])

log_all("UI", "clicked", "hovered", "focused")
```

`...args` 必须在参数列表最后，传入的剩余参数打包为 `Array`。

### Variant 类型标注

```gdscript
var meta: Dictionary[String, Variant] = {}
```

字典/数组的值类型可声明为 `Variant`，增强类型安全性。

### 脚本回溯

即使在 Release 构建中也可获取详细调用栈。

---

## 四大性能杀手

### 1. 无类型变量和数组

```gdscript
# ❌ 慢
var enemies = []
var hp = 100

# ✅ 快
var enemies: Array[Enemy] = []
var hp: int = 100
```

### 2. 热循环中的场景树遍历

```gdscript
# ❌ 每帧遍历
func _process(delta: float) -> void:
    for enemy in get_tree().get_nodes_in_group("enemies"):
        pass

# ✅ _ready 中缓存
@onready var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
```

### 3. _process 中的字符串操作

```gdscript
# ❌ 每帧分配字符串
var debug_text = str(x) + " " + str(y)

# ✅ 格式化，且仅在调试时运行
var debug_text = "%d %d" % [x, y]
if not OS.is_debug_build(): return
```

### 4. 信号重复连接

```gdscript
# ❌ _ready 和 _enter_tree 都 connect 导致回调触发两次
# ✅ 连接前检查
if not button.pressed.is_connected(_on_pressed):
    button.pressed.connect(_on_pressed)
```

---

## 热路径零分配

```gdscript
# ✅ Pre-allocated array reused each frame
var _nearby_cache: Array[Node3D] = []

func _physics_process(delta: float) -> void:
    _nearby_cache.clear()
    _spatial_grid.query_radius(position, radius, _nearby_cache)
```

---

## 物理（4.6）

- **Jolt Physics 是 3D 默认物理引擎** — 比 GodotPhysics3D 更稳定、更确定
- 部分 HingeJoint3D 属性（`damp`）仅在 GodotPhysics 中生效
- 2D 物理未变（仍为 Godot Physics 2D）

## 渲染（4.6）

- **D3D12 是 Windows 默认后端**（之前为 Vulkan）
- **辉光在色调映射之前处理**，默认值已调整
- SSR 全面重做，性能和质量大幅提升
- AgX 色调映射器新增白点和对比度控制

## 渲染（4.5）

- 着色器烘焙器：预编译着色器消除启动卡顿
- SMAA 1x：比 FXAA 锐利，比 TAA 轻量
- 模板缓冲、弯曲法线贴图、镜面反射遮蔽

## 动画（4.6）

- IK 系统完全恢复：CCDIK、FABRIK、Jacobian IK、Spline IK、TwoBoneIK
- 通过 `SkeletonModifier3D` 节点应用

## 性能分析流程

1. 在导出构建中 profile，不要在编辑器内测
2. Debugger → Profiler，按 Self Time 排序找瓶颈
3. 使用自定义 Monitor：`Performance.add_custom_monitor("game/active_enemies", _count_enemies)`
4. 每次只改一处，改完重新 profile 验证
