## 原型截图跑器（带窗口跑·非 headless）：
## godot --path <项目根> --script res://prototypes/expedition/proto_shot.gd -- <scene res://路径> <输出 png 绝对路径>
extends SceneTree

func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("用法：-- <scene.tscn> <out.png>")
		quit(1)
		return
	var scene: PackedScene = load(args[0])
	var node: Node = scene.instantiate()
	root.add_child(node)
	_shoot(String(args[1]))

func _shoot(out_path: String) -> void:
	for i: int in 20:
		await process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() >= 3 and args[2] == "walk":
		# 自动走几步（右右右下…）·穿插回车确认弹窗首个选项——看局中画面
		var keys: Array = [KEY_D, KEY_D, KEY_ENTER, KEY_D, KEY_S, KEY_ENTER, KEY_D, KEY_S, KEY_D, KEY_ENTER, KEY_D, KEY_S, KEY_D, KEY_D, KEY_ENTER, KEY_S, KEY_D, KEY_D]
		for k: int in keys:
			var ev := InputEventKey.new()
			ev.keycode = k
			ev.physical_keycode = k
			ev.pressed = true
			Input.parse_input_event(ev)
			for i: int in 3:
				await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(out_path)
	print("截图已存：", out_path)
	quit(0)
