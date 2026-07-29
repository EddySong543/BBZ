extends SceneTree

## 转场波幕静帧预览（v3 波列体自检）：progress=0.55 盖屏中段 + 揭幕段 1.45 各截一帧。
##   godot --path . -s tools/transition_wave_preview.gd   （⚠须带窗口·headless 卡 frame_post_draw）
## 输出：D:/Game/BoBoZan/_probe_output/transition_wave_*.png（仓库外·勿入库）

const OUT_COVER := "D:/Game/BoBoZan/_probe_output/transition_wave_cover.png"
const OUT_REVEAL := "D:/Game/BoBoZan/_probe_output/transition_wave_reveal.png"
const SHADER := preload("res://assets/shaders/canvas_transition_wave.gdshader")


func _initialize() -> void:
	var bg := ColorRect.new()   # 模拟被盖住的旧场景（暖纸色·看穿帮）
	bg.color = Color("#d8c9a3")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var wave := ColorRect.new()
	wave.set_anchors_preset(Control.PRESET_FULL_RECT)
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("progress", 0.55)
	m.set_shader_parameter("dir", 1.0)
	m.set_shader_parameter("wave_time", 3.2)
	# 配色模拟 TransitionManager._apply_winner_style 的实际映射（deep=crest 压暗 62%·v3 暗场）
	var crest := Color(0.36, 0.64, 1.0)
	m.set_shader_parameter("crest_color", crest)
	m.set_shader_parameter("deep_color", crest.darkened(0.62))
	wave.material = m
	root.add_child(wave)
	await process_frame   # 等窗口尺寸就绪再铺满（_initialize 时 visible_rect 不可靠）
	var size: Vector2 = root.get_visible_rect().size
	bg.size = size
	wave.size = size
	m.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT_COVER)
	print("saved: ", OUT_COVER)
	m.set_shader_parameter("progress", 1.45)
	m.set_shader_parameter("wave_time", 4.1)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT_REVEAL)
	print("saved: ", OUT_REVEAL)
	quit()
