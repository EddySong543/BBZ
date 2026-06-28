# HD-2D 创意原型

## 验证假设（Hypothesis）

现有 2D 像素立绘（h38 圣斗士）放进 3D 立体舞台后，能否在**不画任何法线贴图 / 不做 3D 角色模型**的前提下，
获得 HD-2D（八方旅人式）的光照与纵深感。

## 如何运行

- 编辑器：打开 `prototypes/hd2d/hd2d_stage.tscn`，F6 运行当前场景。
- CLI 截图模式（自动存图到 `screenshots/` 并退出）：
  `godot --path . --resolution 1280x720 res://prototypes/hd2d/hd2d_stage.tscn -- --screenshot`

场景全部由 `hd2d_stage.gd` 在 `_ready()` 程序化搭建（原型宽松标准，硬编码数值）。

## 第三阶段：HD-2D 三要素接入正式战斗场景（实验·已回退）

**结论（2026-06-10）**：Eddy 看过效果后决定回退，src/assets 三个文件已 `git restore` 还原，
正式场景回到 `ec91058` 状态。原型场景与本 README 的研究发现保留，未来若重启此方向，
按下述改动清单可在半天内重现（核心算法都在本目录 shader 里）。

当时的改动清单（已还原，仅作记录）：
- `assets/shaders/character_light.gdshader`：新增 `hd2d_volume` uniform 组（伪圆柱法线体积光 +
  色阶量化 + 亮度代理高光）。**默认全 0 = 与原行为完全一致**。
  ⚠️ 踩坑：AtlasTexture 的 fragment `UV` 是图集坐标（逐帧漂移），伪法线必须用 vertex 阶段
  `VERTEX/frame_px+0.5` 重建帧内 UV；half-lambert² + 高位光会把全身压进最亮色阶（视觉无变化），
  改为 `smoothstep(shade_low, shade_high, ndl)` 直接映射。
- `src/ui/components/character_display.gd`：新增 "HD-2D 体积光（实验）" 导出组
  （hd2d_volume / hd2d_cel_steps / hd2d_spec / hd2d_base_lift，Inspector 实时可调）。
- `src/ui/battle_screen.tscn`：P1/P2CharDisplay 开 `hd2d_volume=0.8, hd2d_spec=0.9`；
  启用既有 ForeDust/LowerDust 尘埃粒子（原 visible=false）。
- 对比图：`screenshots/battle_compare.png`（上=改前 / 下=改后），特写 `_cmp_p1/p2_after.png`。

## 当前状态

**已结束**（2026-06-10）。3D 原型 ×2 已出图归档；正式场景接入实验已按 Eddy 决定回退。
原型目录保留作参考，不再扩展（原型规范：不得渐进演变成生产代码）。

两个 3D 原型场景：
- **场景 1 火把石台**（`hd2d_stage.tscn`）：`screenshots/shot.png` 全景 + `shot_hero.png` 主角特写
- **场景 2 卫城宫殿月夜对垒**（`hd2d_acropolis.tscn`）：`screenshots/acropolis.png` 全景 +
  `acropolis_ground.png` 地面裁切。要素：帕特农式神殿（台基/8柱/檐部/山花）+ 宫殿后明月 +
  h38 vs h30 左右对垒（右侧镜像）+ 柔和月光 + 场景内无可见光源 + 每角色单一影子

## 技术要点 / 研究发现

**2D 立绘无法线贴图的伪光照**（`shaders/hd2d_sprite.gdshader`，三招组合，吃场景真实灯光）：

1. **伪体积法线**：把平面立绘当竖直圆柱体，按 UV 距中心的偏移弯曲法线
   （Broken Age 的"包围盒中心→顶点"法的逐像素简化）。
2. **alpha 边缘梯度 rim**：采样邻域 alpha 求轮廓朝向，轮廓朝光一侧自动勾亮边——
   火把在侧面时铠甲外缘出现暖色描边，零额外资产。
3. **色阶量化 + 亮度代理高光**：漫反射压成 3 档色阶保像素风；用像素亮度近似金属度，
   金甲亮部吃高光、布料暗部不吃。
   另：half-lambert 包裹 + 暗部抬升（base_lift）保证立绘在逆光下仍可读。

**纵深感四件套**：两列参差立柱透视线 + 指数雾（远处溶入夜色）+ 相机远景景深（CameraAttributesPractical）
+ 漂浮尘埃粒子。地面/立柱用程序化像素石材 shader（世界坐标量化到虚拟像素格 + 砖块 hash 色差）。

**光照三层**：冷色月光（DirectionalLight，逆光投长影）+ 双火把暖色点光（双正弦拍频闪烁）+
主角正面冷白补光（保可读性）。辉光走 4.6 新管线（显式设 intensity，默认值已改 0.3）。

**场景 2 新发现（光照布局）**：
- **单一影子铁律**：全场只允许一盏 `shadow_enabled` 灯（主光）；所有补光（正面 Omni、立面方向光）
  一律关阴影。场景 1 出双影子的根因 = 火把 Omni 也开了阴影。
- **"月在殿后"的物理陷阱**：投影光真从月亮位置打过来时，整个前庭都泡在建筑自身的影子里，
  角色反而没有影子对比。解法 = 月亮圆盘（构图）与投影光方向（打光）解耦：光从高位侧方打，
  保留指向镜头的分量（影子朝前 = 视觉上仍像背后光源），方位够侧让建筑影子扫出舞台。
- **影子被地砖伪装**：程序化砖块的随机明暗（color_jitter）会掩盖柔和阴影；
  舞台地面砖色差要调低（0.35→0.15）。
- 镜像立绘：`frame_scale.x` 取负 + 偏移补一帧宽即可，但 rim 的 alpha 边缘向量 x 分量
  必须同步翻转（`flip_sign` uniform），否则勾边亮错侧。

**踩坑记录**：
- `unshaded` 渲染模式只输出 ALBEDO，写 EMISSION 全黑——火苗颜色须直接写 ALBEDO（HDR 值仍被辉光拾取）。
- Godot 4 spatial shader 的 varying 可以 fragment 写 → light() 读，rim 计算靠这个传边缘向量。
- 立绘 quad 用 ALPHA_SCISSOR（非透明混合）才能正确写深度 / 接收逐像素光照 / 投镂空影子。

**调研来源**：
- [Dynamic 2D Character Lighting (Game Developer / Broken Age)](https://www.gamedeveloper.com/programming/dynamic-2d-character-lighting)
- [2D Lighting Techniques (slembcke)](https://www.slembcke.net/blog/2DLightingTechniques/)
- [A dynamic lighting shader for your 2D sprites (Clockwork Chilli)](https://clockworkchilli.com/blog/33_a_dynamic_lighting_shader_for_your_2d_sprites)
- [2D Rim Light (godotshaders.com)](https://godotshaders.com/shader/2d-rim-light-2/)
- 注：八方旅人本体实际**使用了**法线贴图（UE4 自定义 shader 层），本原型是无法线的近似替代。

## 调优旋钮（编辑器内可改）

`hd2d_sprite.gdshader` uniforms：`curve_x/curve_y`（伪体积弯曲）、`cel_steps`（色阶数）、
`base_lift`（暗部抬升）、`rim_strength`、`spec_strength/spec_shininess`。
场景灯光/相机/雾/辉光数值都在 `hd2d_stage.gd` 各 `_build_*()` 内。
