extends Node

## 英雄图鉴点击回归探针（完整引擎模式·真场景）：
##   <godot> --path . res://tools/gallery_click_probe.tscn（带窗口·非 headless）
## 锁行为：①所有 HeroFrame 不吞点击（mouse_filter=IGNORE·2026-07-13 入树时序坑）
##         ②合成左键点第 3 格（idx=2）中心 → _sel_idx 必须跟随。
## 点击=Input.parse_input_event 状态注入（⛔warp_mouse 不可靠·老教训）。

func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	get_window().position = Vector2i(0, 0)
	await get_tree().process_frame
	var g := (load("res://src/ui/hero_gallery_screen.tscn") as PackedScene).instantiate()
	add_child(g)
	await get_tree().create_timer(1.2).timeout   # 等入场翻牌动画收尾

	var filter_ok := true
	for f in g.card_frames:
		if (f as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
			filter_ok = false
	var target := 2
	var pos := Vector2(221.0 + target * 121.0 + 52.0, 186.0 + 52.0)   # 第 3 格框中心
	_click(pos)
	await get_tree().create_timer(0.3).timeout
	var sel: int = g._sel_idx
	if filter_ok and sel == target:
		print("PASS: 框不吞点击·点第 %d 格选中跟随 (_sel_idx=%d)" % [target, sel])
	else:
		print("FAIL: filter_ok=%s _sel_idx=%d (期望 %d)" % [filter_ok, sel, target])
	get_tree().quit()


func _click(pos: Vector2) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		Input.parse_input_event(ev)
