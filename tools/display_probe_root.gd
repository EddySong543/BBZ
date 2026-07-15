extends Node

## 显示设置实测探针（2026-07-15·Epic 项⑦调查「显示模式/分辨率是否失效」）：
## 真窗口（非编辑器内嵌）逐档实测 GameSettings 显示链路——窗口化两档分辨率/无边框全屏/
## 独占全屏/回窗口化，每步断言 DisplayServer 实际状态；跑完恢复原设置值。
## 带窗口跑：godot --path . res://tools/display_probe.tscn
## ⚠ 编辑器 F5 内嵌运行窗口由编辑器接管=改模式/尺寸本来就不生效，这不是 bug（结论见探针输出）。

var fails := 0


func _ready() -> void:
	var orig_mode := String(GameSettings.get_value("window_mode"))
	var orig_res := String(GameSettings.get_value("resolution"))
	await _settle()

	# ① 窗口化 + 1280x720
	GameSettings.set_value("window_mode", "windowed")
	GameSettings.set_value("resolution", "1280x720")
	await _settle()
	_check("① 窗口化 1280x720", DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED
		and DisplayServer.window_get_size() == Vector2i(1280, 720))

	# ② 窗口化 + 1600x900
	GameSettings.set_value("resolution", "1600x900")
	await _settle()
	_check("② 窗口化 1600x900", DisplayServer.window_get_size() == Vector2i(1600, 900))

	# ③ content_scale 等比缩放接管（设计画布恒 1920×1080）
	var win := get_tree().root
	_check("③ content_scale 接管 1920×1080",
		win.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		and win.content_scale_size == Vector2i(1920, 1080))

	# ④ 无边框全屏（尺寸跟屏幕）
	GameSettings.set_value("window_mode", "borderless")
	await _settle()
	var scr := DisplayServer.screen_get_size()
	_check("④ 无边框全屏（%s）" % scr, DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		and DisplayServer.window_get_size().x >= scr.x - 2)

	# ⑤ 独占全屏
	GameSettings.set_value("window_mode", "fullscreen")
	await _settle()
	_check("⑤ 独占全屏", DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

	# ⑥ 回窗口化 1920x1080
	GameSettings.set_value("window_mode", "windowed")
	GameSettings.set_value("resolution", "1920x1080")
	await _settle()
	_check("⑥ 回窗口化 1920x1080", DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED
		and DisplayServer.window_get_size() == Vector2i(1920, 1080))

	# 恢复原设置
	GameSettings.set_value("window_mode", orig_mode)
	GameSettings.set_value("resolution", orig_res)
	await _settle()
	print("display_probe %s（原设置已恢复 %s/%s）" % ["PASS" if fails == 0 else "FAIL×%d" % fails, orig_mode, orig_res])
	get_tree().quit(0 if fails == 0 else 1)


func _settle() -> void:
	await get_tree().create_timer(0.6, true, false, true).timeout
	await RenderingServer.frame_post_draw


func _check(tag: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + tag + "  [mode=%d size=%s]" % [DisplayServer.window_get_mode(), DisplayServer.window_get_size()])
	if not ok:
		fails += 1
