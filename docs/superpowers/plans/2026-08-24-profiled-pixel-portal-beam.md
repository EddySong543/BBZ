# 轮廓化粗像素传送光柱实施计划

> **执行约束：** 保留 `240×135` 整数画布、`8×` 最近邻放大、`12 FPS`、五阶段时序、白色主调；不使用 Shader、外部纹理、Sprite Sheet、抗锯齿或截图。

**目标：** 将当前“完整白色矩形 + 平顶封口”的光柱改为一条连续、粗像素、可读为能量喷涌的程序化轮廓：主体具有离散断面变化，前沿由三股高低不同但在下方汇合的能量头组成，内部亮核和上行流持续运动，九格底座是宽阔爆发而非整块铺白。

**实现结构：** 继续由 `PortalPixelBeam` 管理 SubViewport 和状态，由 `PixelBeamCanvas` 生成共享的整数像素图层。运行时 `_draw()` 与无窗口验证 `build_cpu_pixel_frame()` 必须消费同一套几何生成结果，避免两条实现漂移。整体显示改为普通混合，亮度由预合成的暖白外缘、冷白主体、亮白核心和纯白高光四级控制，避免整柱加法混合后夹成一块白色。

---

## 任务 1：先把通过标准改成方案 1 的视觉契约

**文件：**
- 修改：`tests/unit/ui/test_main_menu_world.gd`
- 新增：`tests/unit/ui/test_portal_pixel_beam.gd`
- 修改：`tools/main_menu_world_probe.gd`

1. 将实现标识更新为 `profiled_low_resolution_pixel_portal_beam`。
2. 删除“主体每行等宽、覆盖率 99%、主体 alpha ≥ 0.72、整张纹理使用加法混合”的旧断言。
3. 新增以下契约断言：
   - `uses_connected_profile == true`
   - `uses_full_body_rect == false`
   - `uses_flat_top_cap == false`
   - `uses_full_frame_additive_blend == false`
   - `uses_controlled_value_layers == true`
   - `leading_prong_count == 3`
   - `silhouette_state_count == 6`
   - 九格底部的活动边界覆盖整个底座，但实际填充率处于 `0.25..0.85`，从而证明它是宽阔爆发而非白色地砖。
   - 光柱每一行都有连通像素，但主体填充率处于 `0.45..0.90`、至少有 4 种不同横截面宽度、连续满宽行不超过 6 行。
4. 运行聚焦测试，确认旧实现先失败：

```powershell
./tools/run_godot.ps1 -Mode Test -Target res://tests/unit/ui/test_main_menu_world.gd -TimeoutSeconds 180
```

预期：失败原因指向新的轮廓、前沿、混合与像素占用契约，而不是解析错误。

## 任务 2：用共享整数几何替换完整矩形主体

**文件：**
- 修改：`src/ui/components/portal_pixel_beam.gd`

1. 在 `PixelBeamCanvas` 内新增 6 帧循环的离散轮廓状态。按 4 个逻辑像素为一段选取左右内缩量，段与段之间必须重叠；不得逐行单调收窄，避免形成楼梯斜边。
2. 将 `_draw()` 和 `build_cpu_pixel_frame()` 都改为消费 `_build_frame_layers()` 返回的 `{rect, color}` 图层列表。每个矩形只是一个整数像素跨度，最终组合必须是一条连续轮廓，而不是把完整矩形主体、核心和封口反复叠加。
3. 光柱前沿使用 3 个不同起始高度的短粗能量头；前 6 个逻辑像素内彼此分离，下方立即并入同一主体。删除全宽 2 像素平顶和核心平顶。
4. 主体断面维持九格底座宽度的约 `70%..96%`，以非对称的小幅缺口和外凸形成生命感；中央亮核贯穿上下，保证整柱连通。内部上行流使用短粗高亮段，速度和相位不同，但方向统一向上。
5. 九格底座改为“中心亮核 + 三圈断续爆发臂 + 稀疏外缘触点”，活动边界横跨九格，但不再铺满完整底座矩形。
6. 将显示材质改为 `BLEND_MODE_MIX`。四级近白色值固定为：暖白低透明外缘、冷白半透明主体、亮白核心、纯白高光；不使用连续渐变。
7. 在 `get_runtime_pixel_metrics()` 中新增：
   - `column_fill_ratio`
   - `distinct_row_width_count`
   - `maximum_full_width_row_run`
   - `base_spans_full_rect`
   并保持帧签名、顶端贯通、亮像素数量等旧运行时证据。
8. 在 `get_visual_contract()` 中暴露任务 1 的全部新契约，同时保留无纹理、无 Shader、无 Sprite Sheet、最近邻放大和五阶段时序证明。

## 任务 3：验证运行链与回归范围

**文件：**
- 验证：`src/ui/components/portal_pixel_beam.gd`
- 验证：`tests/unit/ui/test_main_menu_world.gd`
- 验证：`tools/main_menu_world_probe.gd`

1. 再次运行任务 1 的聚焦 GUT，必须全通过。
2. 运行主界面无截图运行探针：

```powershell
./tools/run_godot.ps1 -Mode Tool -Target res://tools/main_menu_world_probe.gd -TimeoutSeconds 120
```

3. 运行 GDScript 解析/加载检查（使用项目包装脚本，不直接启动 Godot）：

```powershell
./tools/run_godot.ps1 -Mode Import -TimeoutSeconds 120
```

4. 用 `git diff --check` 和精确文件差异确认只改变光柱、对应测试/探针及本计划；不得改动主界面时序、角色移动、脚印路线、Scene7 或其他并行工作。
