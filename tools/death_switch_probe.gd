extends Node

## 死亡换人过渡探针（2026-07-17·带窗口跑）：P2 播 defeat 躺地 → 直接跑
## _death_switch_transition(1)（不动 battle 状态·同英雄重入场——验证
## 「遗体消散 → 透明期换装 → 落点入场+尘」三拍视觉·秒切退役）。
##   godot --path . res://tools/death_switch_probe.tscn
## 输出：D:/Game/BoBoZan/dswitch_lying/dissolve/enter/done.png（仓库外·勿入库）

const OUT := "D:/Game/BoBoZan/"


func _ready() -> void:
	var s: Node = load("res://src/ui/battle_screen.tscn").instantiate()
	add_child(s)
	await get_tree().create_timer(2.2).timeout
	# 真死状态模拟（2026-07-18 站立 idle 回归修）：把 P2 出战位 HP 置 0 → 结算尾的
	# _update_all 刷新须被"遗体守卫"跳过，遗体不得被拉回 idle 站立。
	var b: Variant = s.get("battle")
	var orig_hp: int = b.hp[1][b.active_index[1]]
	b.hp[1][b.active_index[1]] = 0
	s.call("_play_defeat", 1)
	await get_tree().create_timer(1.0).timeout      # 倒地 0.7 + 落地宣告播毕（灰遗体）
	s.call("_update_all")                           # 回归探针：模拟结算尾刷新（修前=遗体站起）
	await get_tree().create_timer(0.2).timeout
	await _snap("dswitch_lying.png")
	# 死亡节拍 v3（2026-07-18 A 方案）：transition 起手按已躺时长补足 death_lie_duration
	# (2.7s·此处已躺 1.2 → 补 ~1.5s 静躺)再消散——采样点随之平移。
	s.call("_death_switch_transition", 1)           # async 启动·不 await——中途抓帧
	await get_tree().create_timer(0.75).timeout     # 静躺保底中段（应=灰遗体完整不透明）
	await _snap("dswitch_hold.png")
	b.hp[1][b.active_index[1]] = orig_hp            # 复活：透明期换装走正常刷新（探针不真换人）
	await get_tree().create_timer(0.95).timeout     # ≈1.7s=消散中段（1.5 起 0.38s 淡出）
	await _snap("dswitch_dissolve.png")
	await get_tree().create_timer(0.4).timeout      # ≈2.1s=入场落下中（1.88 起 0.26s）
	await _snap("dswitch_enter.png")
	await get_tree().create_timer(0.5).timeout
	await _snap("dswitch_done.png")
	get_tree().quit()


func _snap(fname: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + fname)
	print("saved: ", OUT + fname)
