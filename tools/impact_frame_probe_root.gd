extends Node

## 冲击帧概念稿探针：boot 战斗屏 → 直接驱动 PostFX impact_* 参数定格 → 正片/负片各一张截图。
## （真实演出是 0.15s 硬切三段·截图探针把两段定格下来供 F6 静看形态/阈值/毛边。）
##   godot --path . res://tools/impact_frame_probe.tscn
## 输出：D:/Game/BoBoZan/_probe_output/impact_pos.png / impact_neg.png（仓库外）

const OUT_POS := "D:/Game/BoBoZan/_probe_output/impact_pos.png"
const OUT_NEG := "D:/Game/BoBoZan/_probe_output/impact_neg.png"


func _ready() -> void:
	var s: Node = load("res://src/ui/battle_screen1.tscn").instantiate()
	add_child(s)
	await _rt(2.2)
	var mat: ShaderMaterial = s.post_fx.material
	# 炸开中心=P2 受击者（与真实终结拍同一取点公式）
	var vcd: Control = s.p2_char_display
	var center: Vector2 = (vcd.global_position + vcd.size * 0.5) / (s as Control).get_viewport_rect().size
	mat.set_shader_parameter("impact_center", center)
	mat.set_shader_parameter("impact_invert", 0.0)
	mat.set_shader_parameter("impact_strength", 1.0)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT_POS)
	mat.set_shader_parameter("impact_invert", 1.0)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT_NEG)
	mat.set_shader_parameter("impact_strength", 0.0)
	print("IMPACT_FRAME_PROBE done: ", OUT_POS, " / ", OUT_NEG)
	get_tree().quit()


func _rt(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout
