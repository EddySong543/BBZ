extends SceneTree

## 离线截图：渲染对波界面【9 个时刻】快照。
## 必须非 headless：
##   godot --path <PROJ> -s res://prototypes/wave_clash_title/_screenshot.gd
## 1920×1080 + cells_x=64（tscn 默认）→ 每格 30px。
## 新增 shot_8/9 验证连击撞击闪 + 崩溃扩散环。

const SCENE := "res://prototypes/wave_clash_title/wave_clash_title.tscn"

# 每张图固定一组 shader 参数，避开脚本的 _process 覆盖。
# 波相位用 phase_l/phase_r 控制（非对称浪头从屏外推进到中央侧）。
const SHOTS := [
	{
		"name": "shot_1_start",       # 起手：大波在屏幕最外缘
		"params": {
			"pulse_l_x": 0.0, "pulse_r_x": 1.0, "pulse_amp": 1.0,
			"center_amp": 0.0, "wave_amp": 0.10, "wave_time": 2.0,
			"phase_l": 0.30, "phase_r": 0.55, "clash_pos": 0.5,
			"intensity": 1.0, "hit_flash": 0.0, "burst": 0.0, "dither_amt": 1.0,
		},
	},
	{
		"name": "shot_2_advance_25",  # 推进 25%
		"params": {
			"pulse_l_x": 0.125, "pulse_r_x": 0.875, "pulse_amp": 1.0,
			"center_amp": 0.0, "wave_amp": 0.10, "wave_time": 2.0,
			"phase_l": 0.45, "phase_r": 0.70, "clash_pos": 0.5,
			"intensity": 1.0, "hit_flash": 0.0, "burst": 0.0, "dither_amt": 1.0,
		},
	},
	{
		"name": "shot_3_advance_70",  # 推进 70%
		"params": {
			"pulse_l_x": 0.35, "pulse_r_x": 0.65, "pulse_amp": 1.0,
			"center_amp": 0.0, "wave_amp": 0.10, "wave_time": 2.0,
			"phase_l": 0.60, "phase_r": 0.20, "clash_pos": 0.5,
			"intensity": 1.0, "hit_flash": 0.0, "burst": 0.0, "dither_amt": 1.0,
		},
	},
	{
		"name": "shot_4_impact",      # 撞击：大波消散中 + center 起 + 小波起 + intensity 闪
		"params": {
			"pulse_l_x": 0.5, "pulse_r_x": 0.5, "pulse_amp": 0.5,
			"center_amp": 0.5, "wave_amp": 0.12, "wave_time": 1.2,
			"phase_l": 0.50, "phase_r": 0.75, "clash_pos": 0.5,
			"intensity": 1.18, "hit_flash": 0.0, "burst": 0.0, "dither_amt": 1.0,
		},
	},
	{
		"name": "shot_5_settle_a",    # 僵持帧 A：clash 偏右 + center 偏亮 + 波相位 a
		"params": {
			"pulse_l_x": 0.5, "pulse_r_x": 0.5, "pulse_amp": 0.0,
			"center_amp": 1.08, "wave_amp": 0.18, "wave_time": 3.0,
			"phase_l": 0.40, "phase_r": 0.65, "clash_pos": 0.515,
			"intensity": 1.0, "hit_flash": 0.0, "burst": 0.0, "dither_amt": 1.0,
		},
	},
	{
		"name": "shot_6_settle_b",    # 僵持帧 B：clash 偏左 + center 偏暗 + 波相位 b（波移动了）
		"params": {
			"pulse_l_x": 0.5, "pulse_r_x": 0.5, "pulse_amp": 0.0,
			"center_amp": 0.92, "wave_amp": 0.18, "wave_time": 4.7,
			"phase_l": 0.72, "phase_r": 0.22, "clash_pos": 0.485,
			"intensity": 1.0, "hit_flash": 0.0, "burst": 0.0, "dither_amt": 1.0,
		},
	},
	{
		"name": "shot_7_combo_hit",   # 连击蓄力：中线居中顶住不动 + 撞击局部闪 hit_flash
		"params": {
			"pulse_l_x": 0.5, "pulse_r_x": 0.5, "pulse_amp": 0.0,
			"center_amp": 1.0, "wave_amp": 0.18, "wave_time": 5.0,
			"phase_l": 0.30, "phase_r": 0.50, "clash_pos": 0.5,
			"intensity": 1.0, "hit_flash": 1.0, "burst": 0.0, "dither_amt": 1.0,
		},
	},
	{
		"name": "shot_8_burst",       # 崩溃：白闪回落后、扩散环向外扩张中（验证环可见性）
		"params": {
			"pulse_l_x": 0.5, "pulse_r_x": 0.5, "pulse_amp": 0.0,
			"center_amp": 1.0, "wave_amp": 0.18, "wave_time": 6.0,
			"phase_l": 0.40, "phase_r": 0.60, "clash_pos": 0.80,
			"intensity": 1.0, "hit_flash": 0.0, "burst": 0.45, "dither_amt": 1.0,
		},
	},
	{
		"name": "shot_9_swept",       # 盖过末态：蓝盖过 97% → base_L flood 提亮
		"params": {
			"pulse_l_x": 0.5, "pulse_r_x": 0.5, "pulse_amp": 0.0,
			"center_amp": 1.0, "wave_amp": 0.18, "wave_time": 7.0,
			"phase_l": 0.50, "phase_r": 0.70, "clash_pos": 0.97,
			"intensity": 1.0, "hit_flash": 0.0, "burst": 0.0, "dither_amt": 1.0,
		},
	},
]


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	root.set_meta("wave_screenshot_mode", true)   # 让场景脚本跳过 _run_intro
	var scene: Control = load(SCENE).instantiate()
	root.add_child(scene)
	var prompt = scene.get("_prompt")
	if prompt:
		prompt.text = "点击屏幕进入游戏"
	var wave := scene.get_node("Wave") as ColorRect
	var mat := wave.material as ShaderMaterial
	mat.set_shader_parameter("aspect", 1920.0 / 1080.0)

	for i in 60:
		await process_frame

	for shot in SHOTS:
		for k in shot["params"]:
			mat.set_shader_parameter(k, shot["params"][k])
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		var path: String = "res://prototypes/wave_clash_title/%s.png" % shot["name"]
		img.save_png(path)
		print("saved ", path)
		if shot["name"] == "shot_5_settle_a":
			_verify_blocks(img)
			_verify_color_richness(img)

	quit()


## 自检 A：僵持期中心 300×300 区域独立色块数。
func _verify_blocks(img: Image) -> void:
	var region := img.get_region(Rect2i(810, 390, 300, 300))
	var seen := {}
	for yy in 300:
		for xx in 300:
			var c := region.get_pixel(xx, yy)
			var key := (int(round(c.r * 255.0)) << 16) | (int(round(c.g * 255.0)) << 8) | int(round(c.b * 255.0))
			seen[key] = true
	print("[verify] 僵持期中心 300x300 独立色块数 ≈ ", seen.size())


## 自检 B：整屏独立颜色数（验收"颜色丰富不再 5 色简笔画"）。
func _verify_color_richness(img: Image) -> void:
	var seen := {}
	# 跑一遍中部 1920×600 区域（避开顶/底文字）
	for yy in 600:
		for xx in 1920:
			var c := img.get_pixel(xx, 240 + yy)
			var key := (int(round(c.r * 255.0)) << 16) | (int(round(c.g * 255.0)) << 8) | int(round(c.b * 255.0))
			seen[key] = true
	print("[verify] 整屏独立颜色数 ≈ ", seen.size(), "（目标：> 30，证明颜色丰富）")
