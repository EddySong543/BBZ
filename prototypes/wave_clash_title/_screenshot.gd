extends SceneTree

## 离线截图 + 自检：渲染对波界面 3 个状态存 PNG，并统计中心 300×300 区域的独立色块数。
## 必须非 headless（headless 不跑 shader）：
##   godot --path <PROJ> -s res://prototypes/wave_clash_title/_screenshot.gd
## 1920×1080 + 横 24 格 → 每格 80px；300×300 区域理论上 ~3.75 格/边 → 约 16 块以内。

const SCENE := "res://prototypes/wave_clash_title/wave_clash_title.tscn"
const SHOTS := [
	{"name": "shot_1_clash", "pos": 0.50},  # 居中僵持（缝在中央，色块最多）
	{"name": "shot_2_push", "pos": 0.63},   # 蓝方推进
	{"name": "shot_3_flood", "pos": 0.94},  # 蓝方盖过泛滥
]


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var scene: Control = load(SCENE).instantiate()
	root.add_child(scene)
	scene.set("_phase", "done")  # 关掉脚本对 clash_pos 的逐帧覆盖
	var prompt = scene.get("_prompt")
	if prompt:
		prompt.text = "点击屏幕进入游戏"
	var wave := scene.get_node("Wave") as ColorRect
	var mat := wave.material as ShaderMaterial
	mat.set_shader_parameter("aspect", 1920.0 / 1080.0)

	for i in 60:
		await process_frame

	for shot in SHOTS:
		mat.set_shader_parameter("clash_pos", shot["pos"])
		mat.set_shader_parameter("intensity", 1.0)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		var path: String = "res://prototypes/wave_clash_title/%s.png" % shot["name"]
		img.save_png(path)
		print("saved ", path)
		if shot["name"] == "shot_1_clash":
			_verify_blocks(img)

	quit()


## 自检：中心 300×300 区域（避开顶/底文字）数独立纯色块。
func _verify_blocks(img: Image) -> void:
	var region := img.get_region(Rect2i(810, 390, 300, 300))
	var seen := {}
	for yy in 300:
		for xx in 300:
			var c := region.get_pixel(xx, yy)
			var key := (int(round(c.r * 255.0)) << 16) | (int(round(c.g * 255.0)) << 8) | int(round(c.b * 255.0))
			seen[key] = true
	print("[verify] 中心 300x300 区域独立色块数 ≈ ", seen.size(), "（远超 ~15 则说明仍太细）")
