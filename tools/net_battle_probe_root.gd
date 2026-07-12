extends Node

## M1 E2E 探针（2026-07-12）：真 battle_screen 以【加入方】身份经真 ENet 打联机局——
## 视角翻转全链路（快照/事件/动作/胜负）+ 提交→服务器结算→事件流动画→回合推进。
## 同进程拓扑：房间+房主 bot（环回·全程攒）在探针里·battle_screen 经 ENet 连 127.0.0.1。
## 带窗口跑：godot --path . res://tools/net_battle_probe.tscn
## 输出：D:/Game/BoBoZan/net_battle_select.png / net_battle_turn2.png

const OUT_DIR := "D:/Game/BoBoZan/"
const NetTransport := preload("res://src/net/net_transport.gd")
const NetProtocol := preload("res://src/net/net_protocol.gd")
const MatchRoom := preload("res://src/net/match_room.gd")
const NetSession := preload("res://src/net/net_session.gd")
const PORT := 47788

var _room: MatchRoom = null
var _host_enet: NetTransport.ENetTransport
var _host_loop: Variant   # 房主 bot 的环回端（房间视角）
var _bot_turn := -1


func _ready() -> void:
	var fails: Array[String] = []
	var A := preload("res://src/battle/action_def.gd")

	# —— 服务器侧：ENet 开门 + 房主 bot 环回 ——
	_host_enet = NetTransport.ENetTransport.new()
	if not _host_enet.host(PORT):
		print("NET_BATTLE_PROBE: FAIL [端口 %d 无法监听]" % PORT)
		get_tree().quit()
		return
	var pair: Array = NetTransport.LoopbackTransport.make_pair()
	_host_loop = pair[0]

	# —— 加入侧（被测）：真会话拨号 ——
	var ses: Variant = NetSession.create_join("127.0.0.1", PORT)
	var waited := 0.0
	while not (_host_enet.is_ready() and ses.is_link_ready()) and waited < 5.0:
		# 握手期双端都要显式泵（⚠ while 条件里的 is_link_ready 会被 and 短路跳过·不能依赖）
		_host_enet.poll()
		ses.pump()
		await _rt(0.05)
		waited += 0.05
	if not _host_enet.is_ready():
		print("NET_BATTLE_PROBE: FAIL [5s 内未建立连接]")
		get_tree().quit()
		return

	# —— 开局：房主队 h01/h05/h06 · 加入方队 h02/h09/h12 ——
	_room = MatchRoom.new()
	_room.start(_load_team(["h01", "h05", "h06"]), _load_team(["h02", "h09", "h12"]), 777,
		func(p: int, msg: Dictionary) -> void:
			if p == 0:
				_host_loop.send(msg)
			else:
				_host_enet.send(msg))
	# 等加入方收到 match_start（分到玩家位 1）
	waited = 0.0
	while int(ses.client.you) < 0 and waited < 5.0:
		_tick_host(A)
		ses.pump()
		await _rt(0.05)
		waited += 0.05
	if int(ses.client.you) != 1:
		fails.append("加入方未分到玩家位 1: %d" % int(ses.client.you))

	# —— 拉起真战斗屏（联机模式·加入方视角）——
	BattleSetup.net_session = ses
	var s: Node = load("res://src/ui/battle_screen.tscn").instantiate()
	add_child(s)
	await _rt(2.4)   # 回合开场 → 选择态（探针持续 _process 泵房主侧）
	# 翻转断言：自己队（屏幕玩家0位）= 加入方阵容 h02
	var own: HeroData = s.battle.heroes[0][0]
	var foe: HeroData = s.battle.heroes[1][0]
	if own.hero_id != "h02" or foe.hero_id != "h01":
		fails.append("视角翻转错误: 己方=%s 敌方=%s（期望 h02/h01）" % [own.hero_id, foe.hero_id])
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT_DIR + "net_battle_select.png")

	# —— 打两个回合：一到选择态就确认（默认攒）·房主 bot 每回合攒·等镜像推进到回合 2 ——
	var submitted_turn := -1
	waited = 0.0
	while s.battle.turn_number < 2 and waited < 30.0:
		if int(s.state) == 1 and submitted_turn != s.battle.turn_number:   # PLAYER_SELECT
			submitted_turn = s.battle.turn_number
			s._on_confirm_pressed()
		await _rt(0.1)
		waited += 0.1
	# 等回到选择态收尾截图
	waited = 0.0
	while int(s.state) != 1 and waited < 8.0:
		await _rt(0.1)
		waited += 0.1
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT_DIR + "net_battle_turn2.png")
	if s.battle.turn_number < 2:
		fails.append("两拍后回合号=%d（期望 ≥2）" % s.battle.turn_number)
	if not (BattleSetup.net_session == null or BattleSetup.net_session.client.errors.is_empty()):
		fails.append("出现服务器拒绝: %s" % [BattleSetup.net_session.client.errors])

	print("NET_BATTLE_PROBE: %s" % ("PASS" if fails.is_empty() else "FAIL " + str(fails)))
	get_tree().quit()


## 每帧泵房主侧：收双路包喂房间 + bot 每回合提交一次「攒」。
func _process(_delta: float) -> void:
	if _room == null:
		return
	_tick_host(preload("res://src/battle/action_def.gd"))


func _tick_host(A: GDScript) -> void:
	for msg in _host_loop.poll():
		_room.handle(0, msg)
	for msg in _host_enet.poll():
		_room.handle(1, msg)
	if _room.phase == MatchRoom.Phase.SELECT and _bot_turn != _room.battle.turn_number:
		_bot_turn = _room.battle.turn_number
		_room.handle(0, NetProtocol.msg_submit_turn(_bot_turn, A.Action.CHARGE, -1, []))


func _load_team(ids: Array) -> Array:
	var t: Array = []
	for id in ids:
		t.append(load("res://assets/data/heroes/%s.tres" % id))
	return t


func _rt(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout
