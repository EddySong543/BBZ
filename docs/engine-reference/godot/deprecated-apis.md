# Godot 4.4 → 4.6 废弃 API 对照表

最后验证：2026-05-10

如果 agent 建议使用"已弃用"列中的任何 API，**必须**替换为"替代方案"列中的 API。

---

## 已移除的 API

| 已移除 | 版本 | 替代方案 |
|--------|------|----------|
| `RenderingServer.instance_reset_physics_interpolation` | 4.5 | 无替代 |
| `RenderingServer.instance_set_interpolated` | 4.5 | 无替代 |
| `EditorFileDialog.add_side_menu` | 4.6 | 使用 `FileDialog` 基类方法 |
| `FileAccess.get_as_text(skip_cr)` | 4.6 | 移除 `skip_cr` 参数，直接调用 `get_as_text()` |

---

## 已废弃的 API

| 已废弃 | 版本 | 替代方案 |
|--------|------|----------|
| `ParallaxBackground` / `ParallaxLayer` | 4.5 | 自定义着色器视差或 `CanvasLayer` 替代 |
| `SkeletonIK3D` | 4.0 | `SkeletonModifier3D` 体系（TwoBoneIK3D、FABRIK3D 等） |

---

## 重命名对照

| 旧名称 | 新名称 | 版本 |
|--------|--------|------|
| `Node.get_rpc_config` | `Node.get_node_rpc_config` | 4.5 |
| `JSONRPC.set_scope` | `JSONRPC.set_method` | 4.5 |

---

## 类/枚举迁移

| 旧位置 | 新位置 | 版本 |
|--------|--------|------|
| `SpringBoneSimulator3D.BoneDirection` | `SkeletonModifier3D.BoneDirection` | 4.6 |
| `SpringBoneSimulator3D.RotationAxis` | `SkeletonModifier3D.RotationAxis` | 4.6 |

---

## 节点与类（4.0+ 累积）

| 已弃用 | 替代方案 | 起始版本 |
|--------|----------|----------|
| `TileMap` | `TileMapLayer` | 4.3 |
| `VisibilityNotifier2D` | `VisibleOnScreenNotifier2D` | 4.0 |
| `VisibilityNotifier3D` | `VisibleOnScreenNotifier3D` | 4.0 |
| `YSort` | `Node2D.y_sort_enabled` | 4.0 |
| `Navigation2D` / `Navigation3D` | `NavigationServer2D` / `NavigationServer3D` | 4.0 |
| `EditorSceneFormatImporterFBX` | `EditorSceneFormatImporterFBX2GLTF` | 4.3 |

## 方法与属性（4.0+ 累积）

| 已弃用 | 替代方案 | 起始版本 |
|--------|----------|----------|
| `yield()` | `await signal` | 4.0 |
| `connect("signal", obj, "method")` | `signal.connect(callable)` | 4.0 |
| `instance()` | `instantiate()` | 4.0 |
| `PackedScene.instance()` | `PackedScene.instantiate()` | 4.0 |
| `get_world()` | `get_world_3d()` | 4.0 |
| `OS.get_ticks_msec()` | `Time.get_ticks_msec()` | 4.0 |
| 嵌套资源 `duplicate()` | `duplicate_deep()` | 4.5 |
| `Skeleton3D` `bone_pose_updated` | `skeleton_updated` | 4.3 |
| `AnimationPlayer.method_call_mode` | `AnimationMixer.callback_mode_method` | 4.3 |
| `AnimationPlayer.playback_active` | `AnimationMixer.active` | 4.3 |

---

## SkeletonModifier3D 体系（IK 替代）

Godot 4.6 已完全替代旧的 `SkeletonIK3D`：

| 类 | 用途 |
|----|------|
| `TwoBoneIK3D` | 双骨骼 IK（手臂/腿） |
| `ChainIK3D` | 链式 IK |
| `SplineIK3D` | 样条曲线 IK |
| `IterateIK3D` | 迭代 IK |
| `FABRIK3D` | FABRIK 算法 |
| `CCDIK3D` | CCD 算法 |
| `JacobianIK3D` | Jacobian 矩阵 IK |
| `IKModifier3D` | IK 基类 |

---

## 已弃用模式

| 已弃用 | 替代方案 | 原因 |
|--------|----------|------|
| 基于字符串的 `connect()` | 类型化信号连接 | 类型安全，便于重构 |
| `_process()` 中使用 `$NodePath` | `@onready var` 缓存 | 每帧路径查找影响性能 |
| 无类型 `Array` / `Dictionary` | `Array[Type]`，类型化变量 | GDScript 编译器优化 |
| 着色器参数 `Texture2D` | `Texture` 基类型 | 4.4 变更 |
| 新项目使用 GodotPhysics3D | Jolt Physics 3D | 4.6 起默认 |
