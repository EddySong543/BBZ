# Boot Remaster 静态金尘待机设计

## 目标

将独立 Boot Remaster 预览替换为无运镜的静态像素构图。画面从第一帧进入可持续待机状态，只保留金色能量点呼吸与背景粒子缓慢上飘。

## 固定画面

- 背景为深黑紫渐变和轻微暗角。
- “波波攒”标题位于人物后方，只占上半屏，使用克制的暗金色。
- `assets/import/boot_char_pixel.png` 是来源素材；它实际为带 alpha 的 WebP 数据，运行时必须无损转换为真正的 PNG。
- 运行时角色使用 `assets/ui/boot/boot_char_pixel.png`，保持 172×259 源像素并以整数倍最近邻放大。
- 人物完整居中，脚下只有轻微像素投影，不加入月亮、云海、山体、星空或雾层。
- 双手之间使用 `assets/ui/icons/energy_mote.png`，替换原金球。
- 远层和中层背景粒子复用 `energy_mote.png`，轻微向上漂浮；无拖尾、爆发、丝带或高速运动。
- 人物、标题和画布没有运镜、缩放、鼠标视差或整体漂移。

## 节点顺序

1. `Background`
2. `FarMotes`
3. `Title`
4. `MidMotes`
5. `GroundShadow`
6. `Character`
7. `HandMote`

所有旧 Backdrop、月亮、云海、山体、前后丝带、人物背光和前景雾节点从 Remaster 场景中删除，而不是隐藏。

## 待机和输入

- `FarMotes` 与 `MidMotes` 使用循环 `GPUParticles2D`，预处理后首帧即有粒子。
- `HandMote` 只做轻微透明度呼吸，不使用非整数缩放。
- 不保留演出时间线。Remaster 待机控制器的 `can_enter()` 从第一帧返回 `true`。
- 正式 Boot 入口继续保持不变，本阶段只替换独立 Remaster 预览。

## 验证

- 测试运行时 PNG 尺寸、alpha 与来源 WebP 解码后的逐像素数据一致。
- 测试场景不存在旧月亮、云海、丝带和运镜节点。
- 测试角色使用最近邻过滤、整数倍尺寸和新的运行时像素素材。
- 测试两层粒子使用 `energy_mote.png`、方向向上且速度克制。
- Godot 实际截图检查四角与透明区域，不得残留旧背景。
- 动画接触表应只有粒子与手中能量点变化，构图位置保持不变。
