extends Node

## 局域网好友开房·双进程双开实测探针（2026-07-15）：两个独立 Godot 进程各拉真大厅——
## host＝建房（UDP 信标广播）；join＝「附近的房间」列表发现 → 点击即入 → hello →
## 双端经真实转场进 battle_screen（各自断言座位视角）。
## 与 tools/lan_probe（单进程环回）互补：这里补验的是跨进程 UDP/ENet + 大厅点击链 + 进战斗交接。
## 跑法（必须带窗口·两个进程·join 晚 3 秒起）：
##   godot --path . res://tools/lan_duo_probe.tscn -- role=host shot=<png路径>
##   godot --path . res://tools/lan_duo_probe.tscn -- role=join shot=<png路径>
## ⚠ 占真实端口 47777（对局）/47778（发现）——跑前关掉其他游戏窗口。
## 成败标记打 stdout：LAN_DUO_HOST / LAN_DUO_JOIN: PASS 或 FAIL [原因]。

const JOIN_TEAM: Array = ["h02", "h09", "h12"]   # 与房主默认队 h01/h05/h06 全错开·断言视角用

var _role := "host"
var _shot := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var arg := String(a)
		if arg.begins_with("role="):
			_role = arg.get_slice("=", 1)
		elif arg.begins_with("shot="):
			_shot = arg.get_slice("=", 1)

	var fails: Array[String] = []
	var lobby: Node = load("res://src/ui/net_lobby_screen.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(0.9, true, false, true).timeout

	# 幸存者先挂树根——转场 change_scene 只换 current_scene（本探针根会被释放），
	# 树根子节点活到战斗屏，负责后半程断言+截图+打标记。
	var surv := Survivor.new()
	surv.role = _role
	surv.shot = _shot
	surv.fails = fails
	get_tree().root.add_child.call_deferred(surv)

	if _role == "host":
		lobby._on_host()   # 口令留空=公开房（口令门已有 lan_probe+GUT 盖）
		if lobby._session == null:
			_die("建房失败（端口 47777 被占？关掉其他游戏窗口再跑）")
			return
		if lobby._beacon == null:
			fails.append("建房后信标未启动")
	else:
		if lobby._browser == null:
			_die("发现端口 47778 被占（host 未让位或有其他窗口在找房）")
			return
		for id in ["h01", "h05", "h06"]:   # 换阵容与房主错开（顺带走真实选人格链路）
			(lobby._hero_btns[id] as Button).button_pressed = false
		for id in JOIN_TEAM:
			(lobby._hero_btns[id] as Button).button_pressed = true
		if (lobby._picked as Array) != JOIN_TEAM:
			fails.append("改选阵容失败: %s" % [lobby._picked])
		# 等「附近的房间」出现本机环回条目 → 同帧内直接点（列表每 0.5s 重建·跨帧持引用会踩释放）
		var room_text := ""
		var waited := 0.0
		while waited < 10.0 and room_text.is_empty():
			for c in lobby._rooms_box.get_children():
				if c is Button and (c as Button).text.contains("127.0.0.1"):
					room_text = (c as Button).text
					(c as Button).pressed.emit()   # 真实点击链 _on_room_clicked → _on_join
					break
			if room_text.is_empty():
				await get_tree().create_timer(0.25, true, false, true).timeout
				waited += 0.25
		if room_text.is_empty():
			_die("10s 内房间列表没出现 127.0.0.1 条目（信标没跨进程送达？）")
			return
		if room_text.contains("口令") or room_text.contains("不一致"):
			fails.append("公开房条目带了多余标记: %s" % room_text)
		if String(lobby._mode) != "join":
			fails.append("点房间后未进入加入流程（mode=%s status=%s）" % [lobby._mode, lobby._status.text])


func _die(msg: String) -> void:
	print("LAN_DUO_%s: FAIL [%s]" % [_role.to_upper(), msg])
	get_tree().quit()


## 转场幸存者：挂树根 → 等真战斗屏就位 → 断言双端「玩家0=自己」→ 截图 → 打标记退出。
class Survivor extends Node:
	const BATTLE_PATH := "res://src/ui/battle_screen1.tscn"

	var role := ""
	var shot := ""
	var fails: Array[String] = []

	func _ready() -> void:
		_run()

	func _run() -> void:
		var waited := 0.0
		var bs: Node = null
		while waited < 40.0:
			var cs := get_tree().current_scene
			if cs != null and cs.scene_file_path == BATTLE_PATH \
					and cs.get("battle") != null and int(cs.battle.turn_number) >= 1:
				bs = cs
				break
			await get_tree().create_timer(0.2, true, false, true).timeout
			waited += 0.2
		if bs == null:
			print("LAN_DUO_%s: FAIL [40s 内未进入战斗屏]" % role.to_upper())
			get_tree().quit()
			return
		var own := String(bs.battle.heroes[0][0].hero_id)
		var foe := String(bs.battle.heroes[1][0].hero_id)
		if role == "host" and (own != "h01" or foe != "h02"):
			fails.append("房主视角错误: 己方=%s 敌方=%s（期望 h01/h02）" % [own, foe])
		if role == "join" and (own != "h02" or foe != "h01"):
			fails.append("加入方视角未翻转: 己方=%s 敌方=%s（期望 h02/h01）" % [own, foe])
		await get_tree().create_timer(1.0, true, false, true).timeout   # 开场演出走一拍再截
		await RenderingServer.frame_post_draw
		if not shot.is_empty():
			get_viewport().get_texture().get_image().save_png(shot)
		print("LAN_DUO_%s: %s" % [role.to_upper(), "PASS" if fails.is_empty() else "FAIL " + str(fails)])
		if role == "host":
			await get_tree().create_timer(6.0, true, false, true).timeout   # 等加入方验完再退（先退=对面只见断线）
		get_tree().quit()
