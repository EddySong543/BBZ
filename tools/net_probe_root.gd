extends Node

## ENet 真网络探针（联机线批C·2026-07-12）：同进程 host+join 127.0.0.1 —— 房主拓扑实测：
## 房间在主机侧·玩家0走 LoopbackTransport（房主本地位）·玩家1走真 ENet 可靠包。
## 验证：连接建立 / JSON 包双向收发 / 混合传输下打满 3 个回合双端事件流一致 / 无服务器拒绝。
## 跑法（headless 即可）：godot --headless --path . res://tools/net_probe.tscn
## （单元测试禁网络依赖=tests/ 规则·真 socket 行为归本探针）

const NetTransport := preload("res://src/net/net_transport.gd")
const MatchRoom := preload("res://src/net/match_room.gd")
const MatchClient := preload("res://src/net/match_client.gd")
const PORT := 47777
const TURNS := 3


func _ready() -> void:
	var fails: Array[String] = []

	# —— 连接：主机开门 + 客户端拨号 → 等双向就绪 ——
	var host := NetTransport.ENetTransport.new()
	var join := NetTransport.ENetTransport.new()
	if not host.host(PORT):
		print("NET_PROBE: FAIL [端口 %d 无法监听]" % PORT)
		get_tree().quit()
		return
	if not join.join("127.0.0.1", PORT):
		fails.append("客户端拨号失败")
	var waited := 0.0
	while not (host.is_ready() and join.is_ready()) and waited < 5.0:
		host.poll()
		join.poll()
		await get_tree().create_timer(0.05).timeout
		waited += 0.05
	if not (host.is_ready() and join.is_ready()):
		print("NET_PROBE: FAIL [5s 内未建立连接]")
		get_tree().quit()
		return

	# —— 组桌：房间在主机侧·p0=环回（房主本地）·p1=ENet（远端）——
	var pair: Array = NetTransport.LoopbackTransport.make_pair()
	var room: MatchRoom = MatchRoom.new()
	room.start(_team("a"), _team("b"), 777,
		func(p: int, msg: Dictionary) -> void:
			if p == 0:
				pair[0].send(msg)
			else:
				host.send(msg))
	var c0: MatchClient = MatchClient.new(pair[1])
	var c1: MatchClient = MatchClient.new(join)

	# —— 打满 TURNS 个回合（双方全攒·纯协议流验证）——
	var last_submit: Array[int] = [-1, -1]
	var rounds := 0
	while rounds < 200 and c1.turn < TURNS:
		rounds += 1
		for msg in pair[0].poll():
			room.handle(0, msg)
		for msg in host.poll():
			room.handle(1, msg)
		c0.poll()
		c1.poll()
		var A := preload("res://src/battle/action_def.gd")
		for i in 2:
			var c: MatchClient = [c0, c1][i]
			if c.phase == "select" and last_submit[i] != c.turn:
				last_submit[i] = c.turn
				c.submit(A.Action.CHARGE)
		await get_tree().create_timer(0.02).timeout   # 给 ENet 泵留真实时间

	if c1.turn < TURNS:
		fails.append("200 拍内未打满 %d 回合（c1.turn=%d）" % [TURNS, c1.turn])
	if c0.events_log != c1.events_log:
		fails.append("双端事件流不一致（环回 vs ENet）")
	if not c0.errors.is_empty() or not c1.errors.is_empty():
		fails.append("出现服务器拒绝: %s / %s" % [c0.errors, c1.errors])
	if c0.you != 0 or c1.you != 1:
		fails.append("玩家位分配错误: %d/%d" % [c0.you, c1.you])

	host.close()
	join.close()
	print("NET_PROBE: %s" % ("PASS" if fails.is_empty() else "FAIL " + str(fails)))
	get_tree().quit()


func _team(prefix: String) -> Array:
	var out: Array = []
	for i in 3:
		var h := HeroData.new()
		h.hero_id = "%s%d" % [prefix, i]
		h.hero_name = h.hero_id
		h.max_hp = 5
		h.skill_type = HeroData.SkillType.PASSIVE
		out.append(h)
	return out
