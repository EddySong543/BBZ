extends GutTest

## 权威对局房间 行为锁定测试（联机线批B/C/D·2026-07-12）。
## 大用例=两个 MatchClient 经 LoopbackTransport（含 JSON 降级模拟）与房间真打完整局：
## 提交/结算/事件双端一致/死亡换人/胜负判定。另锁：非法提交全拒、抽卡选项只发本人、重连快照可续。

const A := ActionDef.Action
const NetProtocol := preload("res://src/net/net_protocol.gd")
const MatchRoom := preload("res://src/net/match_room.gd")
const MatchClient := preload("res://src/net/match_client.gd")
const NetTransport := preload("res://src/net/net_transport.gd")
const SEED := 777


func _hero(id: String, hp: int) -> HeroData:
	var h := HeroData.new()
	h.hero_id = id
	h.hero_name = id
	h.max_hp = hp
	h.skill_type = HeroData.SkillType.PASSIVE
	return h


func _team(prefix: String, hp: int) -> Array:
	return [_hero(prefix + "1", hp), _hero(prefix + "2", hp), _hero(prefix + "3", hp)]


## 组一桌：房间 + 双方环回传输 + 双客户端。返回 {room, clients, server_ends}。
func _table(hp: int = 2) -> Dictionary:
	var pair0: Array = NetTransport.LoopbackTransport.make_pair()
	var pair1: Array = NetTransport.LoopbackTransport.make_pair()
	var server_ends: Array = [pair0[0], pair1[0]]
	var room: MatchRoom = MatchRoom.new()
	room.start(_team("a", hp), _team("b", hp), SEED,
		func(p: int, msg: Dictionary) -> void: server_ends[p].send(msg))
	room.battle.energy = [999, 999]   # 测试夹具：垫满能量·专注协议流
	var clients: Array = [MatchClient.new(pair0[1]), MatchClient.new(pair1[1])]
	return {room = room, clients = clients, server_ends = server_ends}


## 泵一拍：服务器收包喂房间 → 客户端消化回包。（server_ends 元素动态派发·鸭子 poll）
func _pump(t: Dictionary) -> void:
	for p in 2:
		var inbox: Array = t["server_ends"][p].poll()
		for msg in inbox:
			(t.room as MatchRoom).handle(p, msg)
	for c in t.clients:
		(c as MatchClient).poll()


func test_match_room_full_game_over_protocol() -> void:
	# Arrange：低血量速战桌·P0 全程波·P1 全程攒
	var t := _table(2)
	var clients: Array = t.clients
	var last_submit: Array[int] = [-1, -1]
	# Act：驱动到终局（护栏 200 拍防死循环）
	var guard := 0
	while (clients[0] as MatchClient).phase != "over" and guard < 200:
		guard += 1
		_pump(t)
		for i in 2:
			var c: MatchClient = clients[i]
			if c.phase == "select" and last_submit[i] != c.turn:
				last_submit[i] = c.turn
				c.submit(A.ATTACK if i == 0 else A.CHARGE)
			elif c.phase == "death_switch":
				var res: Array[int] = c.living_reserves()
				assert_gt(res.size(), 0, "死亡换人时应有存活替补")
				c.death_switch(res[0])
				c.phase = "waiting"   # 测试夹具：防同拍重发
		_pump(t)
	# Assert：终局正确·双端事件流逐位一致·服务器状态吻合
	assert_lt(guard, 200, "对局未在护栏内结束")
	assert_eq((clients[0] as MatchClient).phase, "over")
	assert_eq((clients[1] as MatchClient).phase, "over")
	assert_eq((clients[0] as MatchClient).winner, BattleCore.WINNER_P1, "P0 全程输出应获胜")
	assert_eq_deep((clients[0] as MatchClient).events_log, (clients[1] as MatchClient).events_log)
	assert_true((t.room as MatchRoom).battle.game_over)
	assert_eq((clients[0] as MatchClient).errors.size(), 0, "全程不应有拒绝: %s" % [(clients[0] as MatchClient).errors])
	assert_eq((clients[1] as MatchClient).errors.size(), 0, "全程不应有拒绝: %s" % [(clients[1] as MatchClient).errors])


func test_match_room_rejects_illegal_submissions() -> void:
	# Arrange
	var sent: Array = [[], []]
	var room: MatchRoom = MatchRoom.new()
	room.start(_team("a", 5), _team("b", 5), SEED,
		func(p: int, msg: Dictionary) -> void: (sent[p] as Array).append(msg))
	# Act + Assert：五路非法各得其码
	room.handle(0, {v = 999, kind = "resync"})
	assert_eq(_last_error(sent[0]), "version_mismatch")
	room.handle(0, {v = NetProtocol.PROTO_VERSION, kind = "hack", turn = 0})
	assert_eq(_last_error(sent[0]), "unknown_kind")
	room.handle(0, NetProtocol.msg_submit_turn(999, A.CHARGE, -1, []))
	assert_eq(_last_error(sent[0]), "turn_mismatch")
	room.handle(0, NetProtocol.msg_submit_turn(room.battle.turn_number, 15, -1, []))
	assert_eq(_last_error(sent[0]), "illegal_submission", "范围内但不合法的动作应被业务层拒绝")
	room.handle(0, NetProtocol.msg_submit_turn(room.battle.turn_number, A.CHARGE, -1, []))
	room.handle(0, NetProtocol.msg_submit_turn(room.battle.turn_number, A.CHARGE, -1, []))
	assert_eq(_last_error(sent[0]), "already_submitted", "重复提交应被拒（先到先锁）")
	# 非法提交不得污染真局（克隆预检契约）
	assert_eq(room.battle.turn_number, 0, "非法/等待期间真局不得推进")


func test_match_room_draft_offer_is_private() -> void:
	# Arrange：推进到 slot1 解锁后请求 3 选 1
	var t := _table(5)
	var clients: Array = t.clients
	var c0: MatchClient = clients[0]
	var c1: MatchClient = clients[1]
	var last_submit: Array[int] = [-1, -1]
	var picked := false
	var offer: Dictionary = {}   # pick 时的 offer 快照（turn_begin 会清 client.draft_offer）
	var guard := 0
	# Act：每回合 c0 先请求 slot1 抽卡并当拍取回选项（turn_begin 会清 offer·须同回合内完成请求→选择），
	# 拿到选项即选 0 号；未解锁时服务器回 draft_unavailable（预期噪音·本用例不断言 errors 为空）。
	while not picked and guard < 40:
		guard += 1
		_pump(t)
		if c0.phase == "select":
			if c0.draft_offer.is_empty():
				c0.request_draft(1, false)
				_pump(t)
			if not c0.draft_offer.is_empty():
				offer = c0.draft_offer
				c0.pick(int(offer["slot"]), 0, false)
				picked = true
				_pump(t)
			if last_submit[0] != c0.turn:
				last_submit[0] = c0.turn
				c0.submit(A.CHARGE)
		if c1.phase == "select" and last_submit[1] != c1.turn:
			last_submit[1] = c1.turn
			c1.submit(A.CHARGE)
		_pump(t)
	# Assert：本人拿到 3 项·对手全程没收到任何 draft_offer·落格可见于公开视图
	assert_true(picked, "40 拍内应完成一次抽卡")
	assert_eq((offer["options"] as Array).size(), 3)
	assert_true(c1.draft_offer.is_empty(), "抽卡选项泄漏给了对手")
	_pump(t)
	var slot1: Dictionary = (c1.view["slots"] as Array)[0][1]
	assert_ne(String(slot1["item"]), "", "抽卡结果（明牌）应体现在双方公开视图")


func test_match_room_resync_snapshot_resumable() -> void:
	# Arrange：打两拍后请求重连快照
	var sent: Array = [[], []]
	var room: MatchRoom = MatchRoom.new()
	room.start(_team("a", 5), _team("b", 5), SEED,
		func(p: int, msg: Dictionary) -> void: (sent[p] as Array).append(msg))
	room.battle.energy = [99, 99]
	for _i in 2:
		room.handle(0, NetProtocol.msg_submit_turn(room.battle.turn_number, A.ATTACK, -1, []))
		room.handle(1, NetProtocol.msg_submit_turn(room.battle.turn_number, A.DEFEND, -1, []))
	# Act
	room.handle(0, NetProtocol.msg_resync())
	# resync 回两条：snapshot + 补发 turn_begin（M2b）→ 取最后一条 snapshot
	var snap_msg: Dictionary = {}
	for m in sent[0]:
		if String((m as Dictionary).get("kind", "")) == "snapshot":
			snap_msg = m
	# Assert：快照可恢复成逐位一致的战局（断线重连契约）
	assert_eq(String(snap_msg.get("kind", "")), "snapshot")
	var b2 := BattleCore.new()
	assert_true(b2.from_snapshot(snap_msg["snap"]))
	assert_eq_deep(b2.to_snapshot(), room.battle.to_snapshot())


func test_match_client_snapshot_flip_roundtrip() -> void:
	# Arrange：非对称中盘快照（能量/阵容/血上限两侧不同）
	var sent: Array = [[], []]
	var room: MatchRoom = MatchRoom.new()
	room.start(_team("a", 5), _team("b", 3), SEED,
		func(p: int, msg: Dictionary) -> void: (sent[p] as Array).append(msg))
	room.battle.energy = [9, 3]
	var snap: Dictionary = room.battle.to_snapshot()
	# Act
	var flipped: Dictionary = MatchClient.flip_snapshot(snap)
	# Assert：双翻恒等·翻转后可恢复且视角互换（加入方镜像契约）
	assert_eq_deep(MatchClient.flip_snapshot(flipped), snap)
	var b := BattleCore.new()
	assert_true(b.from_snapshot(flipped))
	assert_eq(b.energy[0], 3, "翻转后玩家0=原玩家1")
	assert_eq(b.energy[1], 9)
	assert_eq((b.heroes[0][0] as HeroData).hero_id, "b1", "翻转后己方阵容=原对方阵容")
	# winner 常量互换
	var w := snap.duplicate(true)
	w["winner"] = BattleCore.WINNER_P1
	assert_eq(int(MatchClient.flip_snapshot(w)["winner"]), BattleCore.WINNER_P2)
	# 事件翻转：player 0↔1·victory winner 互换
	var evs: Array = [{id = "damage_taken", player = 0, amount = 2}, {id = "victory", winner = BattleCore.WINNER_P1}]
	var fev: Array = MatchClient.flip_events(evs)
	assert_eq(int(fev[0]["player"]), 1)
	assert_eq(int(fev[1]["winner"]), BattleCore.WINNER_P2)


func test_match_room_deadline_force_submits_charge() -> void:
	# Arrange：假时钟·只有 p0 提交（p1 拖时）
	var fake := {t = 0}
	var sent: Array = [[], []]
	var room: MatchRoom = MatchRoom.new()
	room.now_ms = func() -> int: return int(fake.t)
	room.start(_team("a", 5), _team("b", 5), SEED,
		func(p: int, msg: Dictionary) -> void: (sent[p] as Array).append(msg))
	room.battle.energy = [99, 99]
	room.handle(0, NetProtocol.msg_submit_turn(0, A.DEFEND, -1, []))
	assert_eq(room.battle.turn_number, 0, "只到一方提交不应结算")
	# Act：拨过回合 0 时限（10s + 4s 宽限）
	fake.t = 15000
	room.check_deadline()
	# Assert：p1 被服务器代提交「攒」→ 结算完成·回合推进（拖时锁不死对局）
	assert_eq(room.battle.turn_number, 1, "超时后服务器应代提交并结算")
	assert_eq(room.phase, MatchRoom.Phase.SELECT)


func test_match_room_deadline_auto_switches_dead_player() -> void:
	# Arrange：假时钟·敌方出战 0.5 血·大波击杀 → 进死亡换人相位后拖时
	var fake := {t = 0}
	var sent: Array = [[], []]
	var room: MatchRoom = MatchRoom.new()
	room.now_ms = func() -> int: return int(fake.t)
	room.start(_team("a", 5), _team("b", 5), SEED,
		func(p: int, msg: Dictionary) -> void: (sent[p] as Array).append(msg))
	room.battle.energy = [99, 99]
	room.battle.hp[1][0] = 1
	room.handle(0, NetProtocol.msg_submit_turn(0, A.BIG_ATTACK, -1, []))
	room.handle(1, NetProtocol.msg_submit_turn(0, A.CHARGE, -1, []))
	assert_eq(room.phase, MatchRoom.Phase.DEATH_SWITCH, "击杀后应进换人相位")
	# Act：拨过换人时限
	fake.t = 999999
	room.check_deadline()
	# Assert：服务器代选首个存活替补·开新回合
	assert_eq(room.phase, MatchRoom.Phase.SELECT, "超时后应代选替补并开新回合")
	assert_eq(room.battle.active_index[1], 1, "应换上首个存活替补")


func test_match_room_hello_midgame_resumes_with_snapshot_and_turn_begin() -> void:
	# Arrange：打一拍后掉线方 hello 报到（M2b 重连路径）
	var sent: Array = [[], []]
	var room: MatchRoom = MatchRoom.new()
	room.start(_team("a", 5), _team("b", 5), SEED,
		func(p: int, msg: Dictionary) -> void: (sent[p] as Array).append(msg))
	room.battle.energy = [99, 99]
	room.handle(0, NetProtocol.msg_submit_turn(0, A.CHARGE, -1, []))
	room.handle(1, NetProtocol.msg_submit_turn(0, A.CHARGE, -1, []))
	var before: int = (sent[1] as Array).size()
	# Act
	room.handle(1, NetProtocol.msg_hello(["h01", "h05", "h06"]))
	# Assert：snapshot（you=1·逐位可恢复）+ 补发 turn_begin（重连即回选招·阵容字段被忽略）
	var msgs: Array = (sent[1] as Array).slice(before)
	assert_eq(String((msgs[0] as Dictionary)["kind"]), "snapshot")
	assert_eq(int((msgs[0] as Dictionary)["you"]), 1)
	var b2 := BattleCore.new()
	assert_true(b2.from_snapshot((msgs[0] as Dictionary)["snap"]))
	assert_eq_deep(b2.to_snapshot(), room.battle.to_snapshot())
	assert_eq(String((msgs[1] as Dictionary)["kind"]), "turn_begin", "SELECT 相位应补发 turn_begin")


func test_match_room_rate_limit_drops_flood_then_recovers() -> void:
	# Arrange
	var fake := {t = 0}
	var sent: Array = [[], []]
	var room: MatchRoom = MatchRoom.new()
	room.now_ms = func() -> int: return int(fake.t)
	room.start(_team("a", 5), _team("b", 5), SEED,
		func(p: int, msg: Dictionary) -> void: (sent[p] as Array).append(msg))
	var before: int = (sent[0] as Array).size()
	# Act：同一毫秒灌 100 个 resync
	for _i in 100:
		room.handle(0, NetProtocol.msg_resync())
	# Assert：突发桶 30 → 只放行约 30 个（每个回 snapshot+turn_begin 两条）·其余静默丢
	var snaps := 0
	for i in range(before, (sent[0] as Array).size()):
		if String(((sent[0] as Array)[i] as Dictionary).get("kind", "")) == "snapshot":
			snaps += 1
	assert_lt(snaps, 40, "洪水应被限流·实际放行 %d" % snaps)
	assert_gt(snaps, 25, "正常突发不应被误杀·实际放行 %d" % snaps)
	# 时间推进回填令牌 → 恢复服务（不误伤后续正常包）
	fake.t = 5000
	var b2: int = (sent[0] as Array).size()
	room.handle(0, NetProtocol.msg_resync())
	assert_gt((sent[0] as Array).size(), b2, "令牌回填后应恢复响应")


func _last_error(msgs: Array) -> String:
	for i in range(msgs.size() - 1, -1, -1):
		if String((msgs[i] as Dictionary).get("kind", "")) == "error":
			return String((msgs[i] as Dictionary).get("code", ""))
	return ""
