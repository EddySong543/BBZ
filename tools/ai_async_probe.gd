extends Node

## 任务G 实机验证（2026-07-09）：走真实 _on_confirm_pressed 路径，测主线程阻塞时长。
##   godot --path . res://tools/ai_async_probe.tscn
## 预期：预想命中 → 确认阻塞 <100ms（旧同步路径中期 0.9-1.5s）。
## 同时验证多回合连打无线程错误（预想→确认→结算→下回合重想 循环）。


func _ready() -> void:
	var s: Node = load("res://src/ui/battle_screen1.tscn").instantiate()
	add_child(s)
	await get_tree().create_timer(2.5).timeout   # 进选择态 + 首次预想启动

	for i in range(4):
		var guard := 0
		while s.state != s.State.PLAYER_SELECT and guard < 600:
			guard += 1
			await get_tree().process_frame
		if guard >= 600:
			print("超时：未回到选招态")
			break
		await get_tree().create_timer(1.8).timeout   # 给预想线程留够时间（中期全量 ~1.5s）
		var t0: int = Time.get_ticks_usec()
		s._on_confirm_pressed()
		var dt: float = (Time.get_ticks_usec() - t0) / 1000.0
		print("确认拍 %d：主线程阻塞 = %.1fms（回合 %d）" % [i + 1, dt, s.battle.turn_number])

	get_tree().quit()
