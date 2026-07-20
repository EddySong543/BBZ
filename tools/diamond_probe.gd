extends Node

## battle_screen 菱形头像框全英雄校准探针。
##   godot --path . res://tools/diamond_probe.tscn
## 输出：D:/Game/BoBoZan/diamond_probe.png（仓库外·勿入库）
## 当前覆盖 8 张手裁 battle portrait，并复现正式 HUD 的逐英雄 scale/x 校准与材质参数。

const FrameScene := preload("res://src/ui/components/hero_frame.tscn")
const OUT := "D:/Game/BoBoZan/diamond_probe.png"
const FRAME := 80.0
const PORTRAIT := 82.8
const RISE := 12.0
const HEROES: Array[String] = ["h03", "h04", "h05", "h07", "h12", "h19", "h20", "h21"]
const TUNING := {
	"h03": {"scale": 1.00, "x": 0.0, "y": -2.0},
	"h04": {"scale": 1.30, "x": -7.0, "y": -2.0},
	"h05": {"scale": 1.22, "x": 0.0, "y": -4.0},
	"h07": {"scale": 1.00, "x": -5.0, "y": -3.0},
	"h12": {"scale": 0.98, "x": 0.0, "y": 0.0},
	"h19": {"scale": 1.05, "x": -4.0, "y": 0.0},
	"h20": {"scale": 1.22, "x": -5.0, "y": 0.0},
	"h21": {"scale": 1.00, "x": 0.0, "y": -6.0},
}
const MAG := 3.0
const COL_STEP := 300.0
const ROW_STEP := 340.0
const LEFT := 90.0
const TOP := 85.0


func _ready() -> void:
	get_window().size = Vector2i(1280, 760)
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.11)   # 战斗夜空近似底
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	for i in HEROES.size():
		var hero_id := HEROES[i]
		var tune: Dictionary = TUNING[hero_id]
		var col := i % 4
		var row := i / 4
		var holder := Control.new()
		holder.position = Vector2(LEFT + float(col) * COL_STEP, TOP + float(row) * ROW_STEP)
		holder.scale = Vector2(MAG, MAG)
		add_child(holder)
		var f := FrameScene.instantiate() as HeroFrame
		holder.add_child(f)
		f.frame_size = Vector2(FRAME, FRAME)
		f.size = Vector2(FRAME, FRAME)
		f.position = Vector2.ZERO
		f.player_color = Color("#3f86c8") if i < 4 else Color("#d24a44")
		f.diamond_mode = true
		f.is_active = true
		f.diamond_portrait_px = PORTRAIT * float(tune["scale"])
		f.diamond_portrait_rise = RISE + float(tune["y"])
		f.diamond_portrait_shift_x = float(tune["x"])
		f.diamond_stroke_px = 6.0
		f.diamond_top_slack_px = -1.0
		var battle_path := "res://assets/sprites/heroes/%s/%s_battle_portrait.png" % [hero_id, hero_id]
		var normal_path := "res://assets/sprites/heroes/%s/%s_portrait.png" % [hero_id, hero_id]
		f.portrait_path = battle_path if FileAccess.file_exists(battle_path) else normal_path
		var lbl := Label.new()
		lbl.text = "%s  ×%.2f  x%+.0f y%+.0f" % [hero_id, float(tune["scale"]), float(tune["x"]), float(tune["y"])]
		lbl.position = Vector2(LEFT + float(col) * COL_STEP, TOP + float(row) * ROW_STEP + FRAME * MAG + 8.0)
		lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
		add_child(lbl)

	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT)
	print("saved: ", OUT)
	get_tree().quit()
