extends Node

## 菱形头像框比例试排（2026-07-18·ref10 左侧头像语言）：同一英雄按不同 zoom 并排，
## 一屏看完好挑值；第二行换个发型更满的英雄（h17）验证「上方不收」在最坏情况下的样子。
##   godot --path . res://tools/diamond_probe.tscn
## 输出：D:/Game/BoBoZan/diamond_probe.png（仓库外·勿入库）

const FrameScene := preload("res://src/ui/components/hero_frame.tscn")
const OUT := "D:/Game/BoBoZan/diamond_probe.png"
const ZOOM := 1.15
const ZOOM_SWEEP: Array[float] = [1.0, 1.15, 1.3, 1.5, 1.7]
const SLACKS: Array[float] = [0.0, 14.0, 24.0, 40.0, 200.0]   # 200≈完全不收（ref10 原意）
const ROWS: Array[String] = ["h01", "h07", "h17"]
const STEP := 150.0
const TOP := 60.0


func _ready() -> void:
	get_window().size = Vector2i(900, 560)
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.11)   # 战斗夜空近似底
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	for r in ROWS.size():
		var hid: String = ROWS[r]
		for i in ZOOM_SWEEP.size():
			var f := FrameScene.instantiate() as HeroFrame
			add_child(f)                                  # 先入树 → _ready 跑完再设属性
			f.frame_size = Vector2(72, 72)
			f.size = Vector2(72, 72)
			f.position = Vector2(70.0 + float(i) * STEP, TOP + float(r) * STEP)
			f.player_color = Color("#3f86c8")
			f.portrait_path = "res://assets/sprites/heroes/%s/%s_portrait.png" % [hid, hid]
			f.diamond_mode = true
			f.diamond_portrait_zoom = ZOOM_SWEEP[i]
			f.diamond_top_slack_px = 14.0
			var lbl := Label.new()
			lbl.text = "%s z=%.2f" % [hid, ZOOM_SWEEP[i]]
			lbl.position = Vector2(60.0 + float(i) * STEP, TOP + float(r) * STEP + 86.0)
			lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
			add_child(lbl)

	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT)
	print("saved: ", OUT)
	get_tree().quit()
