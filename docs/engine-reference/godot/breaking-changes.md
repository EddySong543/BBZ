# Godot 4.4 → 4.5 → 4.6 破坏性变更

最后验证：2026-05-10

---

## 4.4 → 4.5 破坏性变更

### Core

| 变更 | GDScript | 说明 |
|---|---|---|
| `Node.get_rpc_config` → `get_node_rpc_config` | ❌ | 方法重命名 |
| `Node.set_name` 参数类型 `String` → `StringName` | ✔️ | 源码兼容 |
| `JSONRPC.set_scope` → `set_method` | ❌ | 方法替换 |

### 渲染

| 变更 | 说明 |
|---|---|
| `RenderingServer.instance_reset_physics_interpolation` | 已移除 |
| `RenderingServer.instance_set_interpolated` | 已移除 |
| 多个 `draw_*` 方法（`CanvasItem`、`Font`、`TextLine`、`TextParagraph`、`TextServer`） | 新增可选 `oversampling` 参数（源码兼容） |

### GLTF 导入

| 变更 | 说明 |
|---|---|
| GLTF Naming Version | 新增导入选项。旧 `.import` 文件默认 Version 0（Godot 4.0–4.1 命名），新文件默认 Version 1。升级后需手动切换并重新导入，否则节点可能被重命名。**最常见升级痛点** |

### 资源

| 变更 | 说明 |
|---|---|
| `Resource.duplicate(true)` | 现在仅复制内部资源，不复制外部引用。使用 `Resource.duplicate_deep(DEEP_DUPLICATE_ALL)` 恢复旧行为 |

### TileMap

| 变更 | 说明 |
|---|---|
| `physics_quadrant_size` | 物理分块默认启用。`get_coords_for_body_rid()` 返回精度降低。设 `physics_quadrant_size = 1` 禁用分块 |

### Jolt Physics

| 变更 | 说明 |
|---|---|
| `areas_detect_static_bodies` 项目设置 | 已移除。Area3D 与静态体之间的重叠现在始终被报告 |

### 文本 / RichTextLabel

| 变更 | 说明 |
|---|---|
| `add_image` / `update_image` | `size_in_percent` 被 `width_in_percent` + `height_in_percent` 替换 |
| `push_strikethrough` / `push_underline` | 新增可选 `color` 参数 |
| `push_table` | 新增可选 `name` 参数 |
| `TreeItem.add_button` | 新增可选 `alt_text` 参数 |

---

## 4.5 → 4.6 破坏性变更

### Core

| 变更 | 说明 |
|---|---|
| `FileAccess.create_temp` — `mode_flags` 参数类型 `int` → `FileAccess.ModeFlags` 枚举 | 源码兼容 |
| `FileAccess.get_as_text` — `skip_cr` 参数已移除 | ❌ 需移除该参数 |
| `Performance.add_custom_monitor` — 新增可选 `type` 参数 | 源码兼容 |

### 动画

| 变更 | 说明 |
|---|---|
| `AnimationPlayer.assigned_animation` / `autoplay` / `current_animation` | 类型 `String` → `StringName` |
| `AnimationPlayer.get_queue()` | 返回类型 `PackedStringArray` → `StringName[]` |
| `AnimationPlayer.current_animation_changed` 信号 | `name` 参数类型 `String` → `StringName` |

### 3D — SpringBoneSimulator3D 枚举迁移

| 枚举 | 原路径 | 新路径 |
|------|--------|--------|
| `BoneDirection` | `SpringBoneSimulator3D.BoneDirection` | `SkeletonModifier3D.BoneDirection` |
| `RotationAxis` | `SpringBoneSimulator3D.RotationAxis` | `SkeletonModifier3D.RotationAxis` |

### 网络 — 方法迁移至基类

| 方法 | 从 | 迁移至 |
|------|-----|--------|
| `disconnect_from_host` / `poll` | `StreamPeerTCP` | `StreamPeerSocket` |
| `get_status` | `StreamPeerTCP` | `StreamPeerSocket` |
| `is_connection_available` / `is_listening` / `stop` | `TCPServer` | `SocketServer` |

### GUI

| 变更 | 说明 |
|---|---|
| `Control.grab_focus` | 新增可选 `hide_focus` 参数 |
| `Control.has_focus` | 新增可选 `ignore_hidden_focus` 参数 |
| `FileDialog.add_filter` | 新增可选 `mime_type` 参数 |
| `SplitContainer.clamp_split_offset` | 新增可选 `priority_index` 参数 |
| `LineEdit.edit` | 新增可选 `hide_focus` 参数 |

### 编辑器

| 变更 | 说明 |
|---|---|
| `EditorFileDialog.add_side_menu` | ❌ 完全移除 |
| `EditorFileDialog` 属性/方法/信号 | 大部分迁移至基类 `FileDialog` |
| `EditorExportPreset.get_script_export_mode` | 返回类型 `int` → `ScriptExportMode` 枚举 |

---

## 默认值变更（4.5 → 4.6）

| 设置 | 旧默认 | 新默认 |
|------|--------|--------|
| Windows 渲染驱动 | Vulkan | **D3D12** |
| 3D 物理引擎 | GodotPhysics | **Jolt Physics** |
| `Environment.glow_blend_mode` | 2 | **1** |
| `Environment.glow_intensity` | 0.8 | **0.3** |
| `Environment.glow_levels/2` | 0.0 | **0.8** |
| `Environment.glow_levels/3` | 1.0 | **0.4** |
| `Environment.glow_levels/4` | 0.0 | **0.1** |
| `Environment.glow_levels/5` | 1.0 | **0.0** |
| `Environment.ssr_depth_tolerance` | 0.2 | **0.5** |
| `rendering/reflections/sky_reflections/roughness_layers` | 8 | **7** |
| `MeshInstance3D.skeleton` | `NodePath("..")` | `NodePath("")` |

> 老项目升级后 3D 物件显示异常：开启 Project Settings → Animation → Compatibility → Detect Parent Skeleton in MeshInstance3D。
> Soft Light 混合模式现在始终按照启用了 `use_hdr_2d` 的方式运行。
