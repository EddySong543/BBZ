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


func _ready_item_slot(item_id: String) -> Dictionary:
	return {
		state = BattleCore.SlotState.CHARGING,
		item = ItemCatalog.make(item_id),
		since = -1,
		used = false,
		draft = [],
		upg_draft = [],
	}


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


func test_match_client_and_room_forward_item_slot_target_to_furnace() -> void:
	var t := _table(5)
	var room: MatchRoom = t.room
	var c0: MatchClient = t.clients[0]
	var c1: MatchClient = t.clients[1]
	room.battle.energy = [0, 0]
	room.battle.slots[0] = [
		_ready_item_slot("t1_ronglu"),
		_ready_item_slot("t1_feibiao"),
		_ready_item_slot("t1_jiudun"),
	]
	_pump(t)

	c0.submit(A.DEFEND, -1, [0], false, false, false, false, [], -1, false, [1])
	c1.submit(A.DEFEND)
	_pump(t)

	assert_null(room.battle.slots[0][0]["item"], "熔炉自身应在使用后消耗")
	assert_null(room.battle.slots[0][1]["item"], "协议指定的槽1应被熔炉烧掉")
	assert_eq((room.battle.slots[0][2]["item"] as ItemData).item_id, "t1_jiudun",
		"未被指定的槽2不得受影响")


func test_match_room_routes_secondary_target_to_friendly_hero_items() -> void:
	var t := _table(5)
	var room: MatchRoom = t.room
	var c0: MatchClient = t.clients[0]
	var c1: MatchClient = t.clients[1]
	room.battle.slots[0][0] = _ready_item_slot("t2_huzhen_ding")
	_pump(t)

	c0.submit(A.CHARGE, -1, [0], false, false, false, false, [], -1, false, [2])
	c1.submit(A.CHARGE)
	_pump(t)

	assert_eq(room.battle.shield[0][2], 4, "协议副目标应解释为己方英雄槽")
	assert_eq(room.battle.shield[0][0], 0)


func test_match_room_routes_houzhen_target_to_end_turn_entry() -> void:
	var t := _table(5)
	var room: MatchRoom = t.room
	var c0: MatchClient = t.clients[0]
	var c1: MatchClient = t.clients[1]
	room.battle.slots[0][0] = _ready_item_slot("t1_houzhen_qian")
	_pump(t)

	c0.submit(A.CHARGE, -1, [0], false, false, false, false, [], -1, false, [2])
	c1.submit(A.CHARGE)
	_pump(t)

	assert_eq(room.battle.active_index[0], 2, "协议副目标应成为候阵签的回合末登场位")


func test_match_room_requires_and_executes_lianhuan_second_action() -> void:
	var t := _table(5)
	var room: MatchRoom = t.room
	var c0: MatchClient = t.clients[0]
	var c1: MatchClient = t.clients[1]
	room.battle.energy = [4, 0]
	room.battle.slots[0][0] = _ready_item_slot("t3_lianhuan_gu")
	_pump(t)

	# 缺第二行动的提交在克隆预检中拒绝，权威战局不得被消耗或污染。
	c0.submit(A.CHARGE, -1, [0])
	_pump(t)
	assert_true(c0.errors.has("illegal_submission"))
	assert_eq((room.battle.slots[0][0]["item"] as ItemData).item_id, "t3_lianhuan_gu")

	# 合法的「攒→波」经完整客户端/房间链执行；P1 的攒用于完成同时提交。
	c0.submit(A.CHARGE, -1, [0], false, false, false, false, [], -1, false,
		[-1], [-1], A.ATTACK, -1)
	c1.submit(A.CHARGE)
	_pump(t)
	assert_null(room.battle.slots[0][0]["item"])
	assert_eq(room.battle.hp[1][0], 8, "第二行动的波应造成1点伤害")


func test_match_room_rejects_missing_or_illegal_friendly_hero_target() -> void:
	for item_id in ["t2_yijia_huan", "t2_huzhen_ding", "t2_jieyin_pei",
			"t2_daishang_san", "t2_xingjun_yaonang", "t1_houzhen_qian",
			"t3_yiyuan_deng"]:
		var sent: Array = [[], []]
		var room := MatchRoom.new()
		room.start(_team("a", 5), _team("b", 5), SEED,
			func(p: int, msg: Dictionary) -> void: (sent[p] as Array).append(msg))
		room.battle.slots[0][0] = _ready_item_slot(item_id)
		var before: Dictionary = room.battle.to_snapshot()
		room.handle(0, NetProtocol.msg_submit_turn(0, A.CHARGE, -1, [0]))
		assert_eq(_last_error(sent[0]), "illegal_submission")
		assert_eq_deep(room.battle.to_snapshot(), before)

	var bad_sent: Array = [[], []]
	var bad_room := MatchRoom.new()
	bad_room.start(_team("a", 5), _team("b", 5), SEED,
		func(p: int, msg: Dictionary) -> void: (bad_sent[p] as Array).append(msg))
	bad_room.battle.slots[0][0] = _ready_item_slot("t2_huzhen_ding")
	bad_room.handle(0, NetProtocol.msg_submit_turn(
		0, A.CHARGE, -1, [0], false, false, false, false, [], -1, false, [0]))
	assert_eq(_last_error(bad_sent[0]), "illegal_submission", "护阵钉不能指定出战位")


func test_match_room_routes_shizhi_target_to_an_enemy_item_slot() -> void:
	var t := _table(5)
	var room: MatchRoom = t.room
	var c0: MatchClient = t.clients[0]
	var c1: MatchClient = t.clients[1]
	room.battle.slots[0][0] = _ready_item_slot("t2_shizhi_jiasuo")
	room.battle.slots[1][2] = _ready_item_slot("t2_feibiao")
	room.battle.slots[1][2]["since"] = room.battle.turn_number
	_pump(t)

	c0.submit(A.CHARGE, -1, [0], false, false, false, false, [], -1, false, [2])
	c1.submit(A.CHARGE)
	_pump(t)
	assert_eq(int(room.battle.slots[1][2]["since"]), 1)
	assert_false(room.battle.slot_ready(1, 2))


func test_match_room_routes_ready_item_pressure_and_last_wish_targets() -> void:
	for pressure_id in ["t2_yawu_piao", "t2_cuiyong_pai"]:
		var t := _table(5)
		var room: MatchRoom = t.room
		var c0: MatchClient = t.clients[0]
		var c1: MatchClient = t.clients[1]
		room.battle.configure_battle_backpacks([], [])
		room.battle.slots[0][0] = _ready_item_slot(pressure_id)
		room.battle.slots[1][2] = _ready_item_slot("t2_feibiao")
		_pump(t)
		c0.submit(A.CHARGE, -1, [0], false, false, false, false, [], -1, false, [2])
		c1.submit(A.CHARGE)
		_pump(t)
		assert_null(room.battle.slots[0][0]["item"], "%s 应接受敌方就绪槽目标" % pressure_id)

	var wish_table := _table(5)
	var wish_room: MatchRoom = wish_table.room
	var wish_c0: MatchClient = wish_table.clients[0]
	var wish_c1: MatchClient = wish_table.clients[1]
	wish_room.battle.hp[0] = [2, 4, 8]
	wish_room.battle.max_hp[0] = [10, 10, 10]
	wish_room.battle.slots[0][0] = _ready_item_slot("t3_yiyuan_deng")
	_pump(wish_table)
	wish_c0.submit(A.CHARGE, -1, [0], false, false, false, false, [], -1, false, [1])
	wish_c1.submit(A.CHARGE)
	_pump(wish_table)
	assert_eq(wish_room.battle.hp[0][0], 0, "遗愿灯应完成原出战英雄死亡结算")
	assert_eq(wish_room.battle.hp[0][1], 10, "协议副目标应被回满并登场")
	assert_eq(wish_room.battle.active_index[0], 1)


func test_miwu_snapshots_hide_only_the_opponent_item_ids() -> void:
	var room := MatchRoom.new()
	room.start(_team("a", 5), _team("b", 5), SEED, func(_p: int, _msg: Dictionary) -> void: pass)
	room.battle.slots[0][0] = _ready_item_slot("t2_feibiao")
	room.battle.info_distortion[0]["hide_item_bar"] = true

	var owner_snap: Dictionary = room._snap_for(0)
	var enemy_snap: Dictionary = room._snap_for(1)
	assert_eq(String(((owner_snap["slots"] as Array)[0][0] as Dictionary)["item"]), "t2_feibiao")
	assert_eq(String(((enemy_snap["slots"] as Array)[0][0] as Dictionary)["item"]), "")
	assert_eq(String(((room._view(1)["slots"] as Array)[0][0] as Dictionary)["item"]), "",
		"公开view也不能成为改包读取道具id的后门")


func test_match_room_authoritatively_accepts_xunxing_wave_target_and_rejects_forgery() -> void:
	var sent: Array = [[], []]
	var room: MatchRoom = MatchRoom.new()
	room.start(_team("a", 5), _team("b", 5), SEED,
		func(p: int, msg: Dictionary) -> void: (sent[p] as Array).append(msg))
	room.battle.energy = [20, 20]
	room.battle.slots[0][0] = _ready_item_slot("t1_xunxing_zhui")
	room.handle(0, NetProtocol.msg_submit_turn(0, A.ATTACK, 2, [0]))
	room.handle(1, NetProtocol.msg_submit_turn(0, A.CHARGE, -1, []))

	assert_eq(room.battle.hp[1][2], 9, "权威端应将 0.5 点寻星波结算到后排目标")
	assert_eq(room.battle.hp[1][0], 10, "敌方出战位不得被误伤")
	assert_eq((sent[0] as Array).filter(
		func(msg: Dictionary) -> bool: return String(msg.get("kind", "")) == "error").size(), 0)

	var forged_sent: Array = [[], []]
	var forged: MatchRoom = MatchRoom.new()
	forged.start(_team("a", 5), _team("b", 5), SEED,
		func(p: int, msg: Dictionary) -> void: (forged_sent[p] as Array).append(msg))
	forged.battle.energy = [20, 20]
	forged.handle(0, NetProtocol.msg_submit_turn(0, A.ATTACK, 2, []))
	assert_eq(_last_error(forged_sent[0]), "illegal_submission",
		"未提交寻星坠时伪造后排波目标必须被拒绝")
	assert_eq(forged.battle.turn_number, 0, "非法目标提交不得污染真局")


func test_match_room_privately_offers_pointstone_t3_and_commits_selected_choice() -> void:
	var t := _table(5)
	var room: MatchRoom = t.room
	var c0: MatchClient = t.clients[0]
	var c1: MatchClient = t.clients[1]
	room.battle.slots[0] = [
		_ready_item_slot("t2_dianjinshi"),
		_ready_item_slot("t1_feibiao"),
		_ready_item_slot("t1_jiudun"),
	]
	_pump(t)

	c0.request_pointstone_draft(0, 1)
	_pump(t)
	var offer: Dictionary = c0.draft_offer
	assert_eq(String(offer.get("kind", "")), "pointstone_offer")
	assert_eq((offer.get("options", []) as Array).size(), 3)
	assert_true(c1.draft_offer.is_empty(), "点金石传说候选只能私发使用者")
	var chosen_id: String = String((offer["options"] as Array)[1])

	c0.submit(A.DEFEND, -1, [0], false, false, false, false, [], -1, false,
		[1], [1])
	c1.submit(A.CHARGE)
	_pump(t)

	assert_null(room.battle.slots[0][0]["item"], "点金石自身应被消耗")
	assert_eq((room.battle.slots[0][1]["item"] as ItemData).item_id, chosen_id,
		"权威端必须采用私发候选中提交的下标")
	assert_eq((room.battle.slots[0][1]["item"] as ItemData).tier, 3)
	assert_false(bool(room.battle.slots[0][1]["used"]), "传说道具不能在升级回合顺带使用")
	assert_eq((room.battle.slots[0][2]["item"] as ItemData).item_id, "t1_jiudun",
		"未指定的普通道具不得被升级")


func test_match_room_rejects_illegal_furnace_target_without_probe_pollution() -> void:
	var sent: Array = [[], []]
	var room := MatchRoom.new()
	room.start(_team("a", 5), _team("b", 5), SEED,
		func(p: int, msg: Dictionary) -> void: (sent[p] as Array).append(msg))
	room.battle.energy = [0, 0]
	room.battle.slots[0] = [
		_ready_item_slot("t1_ronglu"),
		_ready_item_slot("t1_feibiao"),
		_ready_item_slot("t1_jiudun"),
	]
	var before: Dictionary = room.battle.to_snapshot()

	room.handle(0, NetProtocol.msg_submit_turn(
		0, A.DEFEND, -1, [0], false, false, false, false, [], -1, false, [0]))

	assert_eq(_last_error(sent[0]), "illegal_submission", "熔炉不得把自身作为燃料")
	assert_eq_deep(room.battle.to_snapshot(), before)


func test_match_room_rejects_pointstone_target_that_is_not_ready_tier1() -> void:
	var sent: Array = [[], []]
	var room := MatchRoom.new()
	room.start(_team("a", 5), _team("b", 5), SEED,
		func(p: int, msg: Dictionary) -> void: (sent[p] as Array).append(msg))
	room.battle.slots[0] = [
		_ready_item_slot("t2_dianjinshi"),
		_ready_item_slot("t2_feibiao"),
		_ready_item_slot("t1_jiudun"),
	]
	var before: Dictionary = room.battle.to_snapshot()

	room.handle(0, NetProtocol.msg_item_draft(0, 0, 1))

	assert_eq(_last_error(sent[0]), "draft_unavailable", "点金石只能选择另一件可使用的普通道具")
	assert_eq_deep(room.battle.to_snapshot(), before)


func test_match_room_rejects_pointstone_submit_without_authoritative_offer() -> void:
	var sent: Array = [[], []]
	var room := MatchRoom.new()
	room.start(_team("a", 5), _team("b", 5), SEED,
		func(p: int, msg: Dictionary) -> void: (sent[p] as Array).append(msg))
	room.battle.slots[0] = [
		_ready_item_slot("t2_dianjinshi"),
		_ready_item_slot("t1_feibiao"),
		_ready_item_slot("t1_jiudun"),
	]
	var before: Dictionary = room.battle.to_snapshot()

	room.handle(0, NetProtocol.msg_submit_turn(
		0, A.DEFEND, -1, [0], false, false, false, false, [], -1, false, [1], [0]))

	assert_eq(_last_error(sent[0]), "illegal_submission",
		"未请求权威候选时不得伪造点金石选择")
	assert_eq_deep(room.battle.to_snapshot(), before)


func test_match_room_accepts_h05_empowered_wave_and_rejects_forged_one() -> void:
	var sent: Array = [[], []]
	var room: MatchRoom = MatchRoom.new()
	room.start([_hero("a0", 5), _hero("h05", 5), _hero("a2", 5)], _team("b", 5), SEED,
		func(p: int, msg: Dictionary) -> void: (sent[p] as Array).append(msg))
	room.battle.energy = [8, 8]
	room.handle(0, NetProtocol.msg_submit_turn(0, A.ATTACK, -1, [], false, true))
	room.handle(1, NetProtocol.msg_submit_turn(0, A.CHARGE, -1, []))
	assert_eq(room.battle.hp[1][0], 6, "权威房间应按强化波造成 2 点伤害")

	var forged: MatchRoom = MatchRoom.new()
	var forged_sent: Array = [[], []]
	forged.start(_team("a", 5), _team("b", 5), SEED,
		func(p: int, msg: Dictionary) -> void: (forged_sent[p] as Array).append(msg))
	forged.battle.energy = [8, 8]
	forged.handle(0, NetProtocol.msg_submit_turn(0, A.ATTACK, -1, [], false, true))
	assert_eq(_last_error(forged_sent[0]), "illegal_submission", "队内无亢金时伪造强化标记必须被业务层拒绝")
	assert_eq(forged.battle.turn_number, 0, "非法强化提交不得污染真局")


func test_match_room_accepts_h13_split_big_wave_and_rejects_forged_one() -> void:
	var sent: Array = [[], []]
	var room: MatchRoom = MatchRoom.new()
	room.start([_hero("h13", 4), _hero("a1", 5), _hero("a2", 5)], _team("b", 5), SEED,
		func(p: int, msg: Dictionary) -> void: (sent[p] as Array).append(msg))
	room.battle.energy = [8, 8]
	room.handle(0, NetProtocol.msg_submit_turn(0, A.BIG_ATTACK, -1, [], false, false, true))
	room.handle(1, NetProtocol.msg_submit_turn(0, A.CHARGE, -1, []))
	assert_eq(room.battle.hp[1][0], 6, "权威房间应按玄冥双波造成两次共 2 点伤害")

	var forged: MatchRoom = MatchRoom.new()
	var forged_sent: Array = [[], []]
	forged.start(_team("a", 5), _team("b", 5), SEED,
		func(p: int, msg: Dictionary) -> void: (forged_sent[p] as Array).append(msg))
	forged.battle.energy = [8, 8]
	forged.handle(0, NetProtocol.msg_submit_turn(0, A.BIG_ATTACK, -1, [], false, false, true))
	assert_eq(_last_error(forged_sent[0]), "illegal_submission", "无玄冥时伪造双波标记必须被业务层拒绝")
	assert_eq(forged.battle.turn_number, 0, "非法双波提交不得污染真局")


func test_match_room_accepts_h14_blood_payment_and_rejects_forged_one() -> void:
	var sent: Array = [[], []]
	var room: MatchRoom = MatchRoom.new()
	room.start([_hero("h14", 6), _hero("a1", 5), _hero("a2", 5)], _team("b", 5), SEED,
		func(p: int, msg: Dictionary) -> void: (sent[p] as Array).append(msg))
	room.battle.energy = [0, 0]
	room.handle(0, NetProtocol.msg_submit_turn(0, A.BIG_ATTACK, -1, [], false, false, false, true))
	room.handle(1, NetProtocol.msg_submit_turn(0, A.CHARGE, -1, []))
	assert_eq(room.battle.hp[0][0], 6, "权威房间应由蚩尤支付大波的 3 点生命")
	assert_eq(room.battle.hp[1][0], 6, "权威房间仍应结算大波伤害")

	var forged: MatchRoom = MatchRoom.new()
	var forged_sent: Array = [[], []]
	forged.start(_team("a", 5), _team("b", 5), SEED,
		func(p: int, msg: Dictionary) -> void: (forged_sent[p] as Array).append(msg))
	forged.battle.energy = [0, 0]
	forged.handle(0, NetProtocol.msg_submit_turn(0, A.ATTACK, -1, [], false, false, false, true))
	assert_eq(_last_error(forged_sent[0]), "illegal_submission", "无蚩尤时伪造生命支付标记必须被业务层拒绝")
	assert_eq(forged.battle.turn_number, 0, "非法生命支付提交不得污染真局")


func test_match_room_accepts_h24_discount_and_rejects_forged_one() -> void:
	var sent: Array = [[], []]
	var room: MatchRoom = MatchRoom.new()
	room.start([_hero("a0", 5), _hero("h24", 6), _hero("a2", 5)], _team("b", 5), SEED,
		func(p: int, msg: Dictionary) -> void: (sent[p] as Array).append(msg))
	room.battle.energy = [4, 4]
	room.handle(0, NetProtocol.msg_submit_turn(
		0, A.BIG_ATTACK, -1, [], false, false, false, false, [], -1, true))
	room.handle(1, NetProtocol.msg_submit_turn(0, A.CHARGE, -1, []))
	assert_eq(room.battle.energy_max[0], 18, "权威房间应结算并封的 1 点上限代价")
	assert_eq(room.battle.hp[1][0], 6, "减费后仍应正常打出大波")

	var forged: MatchRoom = MatchRoom.new()
	var forged_sent: Array = [[], []]
	forged.start(_team("a", 5), _team("b", 5), SEED,
		func(p: int, msg: Dictionary) -> void: (forged_sent[p] as Array).append(msg))
	forged.battle.energy = [4, 4]
	forged.handle(0, NetProtocol.msg_submit_turn(
		0, A.BIG_ATTACK, -1, [], false, false, false, false, [], -1, true))
	assert_eq(_last_error(forged_sent[0]), "illegal_submission", "无并封时伪造减费标记必须被拒绝")
	assert_eq(forged.battle.energy_max[0], 20, "非法减费提交不得污染真局上限")


func test_match_room_replays_single_h07_free_switch_before_paid_h07_action() -> void:
	var sent: Array = [[], []]
	var room: MatchRoom = MatchRoom.new()
	room.start(
		[_hero("h14", 6), _hero("h07", 6), _hero("h17", 7)],
		_team("b", 5),
		SEED,
		func(p: int, msg: Dictionary) -> void: (sent[p] as Array).append(msg))
	room.battle.energy = [0, 0]
	room.handle(0, NetProtocol.msg_submit_turn(
		0, A.BIG_ATTACK, -1, [], false, false, false, true, [1], 0))
	room.handle(1, NetProtocol.msg_submit_turn(0, A.CHARGE, -1, []))

	assert_eq(room.battle.active_index[0], 1, "权威端应重放本回合唯一一次蚩尤→星日免费切换")
	assert_eq(room.battle.hp[0][0], 6, "星日大波的 3 点费用应由原槽蚩尤支付")
	assert_eq(room.battle.energy[0], 2, "血量支付不得误扣团队能量，只获得正常回合被动能量")
	assert_eq(room.battle.hp[1][0], 5, "星日登场0.5点并继续打出大波2点")


func test_match_room_tianluo_cancels_h07_preview_for_both_players_and_arrival_orders() -> void:
	# MatchRoom 只在双方都提交后落真局；以下同时交换玩家编号与消息到达顺序，
	# 锁定天罗裁定不能依赖“谁是 P0”或“谁先发包”。
	for h07_player: int in [0, 1]:
		for h07_first: bool in [false, true]:
			var sent: Array = [[], []]
			var room: MatchRoom = MatchRoom.new()
			var h07_team: Array = [
				_hero("h07_origin", 10), _hero("h07", 10), _hero("h07_third", 10),
			]
			var plain_team: Array = _team("plain", 10)
			room.start(h07_team if h07_player == 0 else plain_team,
				plain_team if h07_player == 0 else h07_team, SEED,
				func(p: int, msg: Dictionary) -> void: (sent[p] as Array).append(msg))
			room.battle.energy = [0, 0]
			var tianluo_player: int = 1 - h07_player
			room.battle.slots[tianluo_player][0] = _ready_item_slot("t3_tianluodiwang")
			room.battle.relics[h07_player].append({
				data = ItemCatalog.make("t3_yemingzhu"), state = {charges = 3},
			})
			room.battle.set_status(h07_player, 0, "vuln", 3)
			var enemy_hp_before: int = room.battle.hp[tianluo_player][0]

			var h07_msg: Dictionary = NetProtocol.msg_submit_turn(
				0, A.DEFEND, -1, [], false, false, false, false, [1])
			var tianluo_msg: Dictionary = NetProtocol.msg_submit_turn(
				0, A.DEFEND, -1, [0])
			var first_player: int = h07_player if h07_first else tianluo_player
			var second_player: int = tianluo_player if h07_first else h07_player
			room.handle(first_player, h07_msg if h07_first else tianluo_msg)
			room.handle(second_player, tianluo_msg if h07_first else h07_msg)

			assert_eq(room.battle.active_index[h07_player], 0,
				"天罗必须取消选择期免费切换预览")
			assert_eq(room.battle.hp[tianluo_player][0], enemy_hp_before,
				"被取消的星日登场不能先造成冲撞")
			assert_eq(room.battle.shield[h07_player][1], 0,
				"被取消的夜明珠不能给预览目标护甲")
			assert_eq(int(room.battle.relics[h07_player][0]["state"].get("charges", 0)), 3,
				"被取消的夜明珠不能消耗次数")
			assert_eq(int(room.battle.get_status(h07_player, 0, "vuln", 0)), 3,
				"原出战英雄不能发生离场清状态副作用")
			assert_eq(room.battle.free_switch_uses[h07_player], 0,
				"天罗取消后免费切换次数应恢复")
			var saw_cancel := false
			for msg_variant in sent[h07_player]:
				var msg: Dictionary = msg_variant
				if String(msg.get("kind", "")) != "resolve":
					continue
				for event_variant in msg.get("events", []):
					var event: Dictionary = event_variant
					if String(event.get("id", "")) == "free_switch_cancelled" \
							and int(event.get("player", -1)) == h07_player:
						saw_cancel = true
			assert_true(saw_cancel, "联机结算事件必须显式告知 UI 免费切换被天罗取消")


func test_match_room_sage_book_preserves_h07_switch_against_tianluo() -> void:
	var sent: Array = [[], []]
	var room: MatchRoom = MatchRoom.new()
	room.start(
		[_hero("origin", 10), _hero("h07", 10), _hero("third", 10)],
		_team("enemy", 10), SEED,
		func(p: int, msg: Dictionary) -> void: (sent[p] as Array).append(msg))
	room.battle.energy = [0, 0]
	room.battle.slots[0][0] = _ready_item_slot("t1_hushenfu")
	room.battle.slots[1][0] = _ready_item_slot("t3_tianluodiwang")
	room.battle.relics[0].append({
		data = ItemCatalog.make("t3_yemingzhu"), state = {charges = 3},
	})
	room.battle.set_status(0, 0, "vuln", 3)
	var enemy_hp_before: int = room.battle.hp[1][0]

	room.handle(1, NetProtocol.msg_submit_turn(0, A.DEFEND, -1, [0]))
	room.handle(0, NetProtocol.msg_submit_turn(
		0, A.DEFEND, -1, [0], false, false, false, false, [1]))

	assert_eq(room.battle.active_index[0], 1,
		"圣贤书抵消天罗后，免费切换应在权威端恰好兑现一次")
	assert_eq(enemy_hp_before - room.battle.hp[1][0], 3,
		"星日冲撞与夜明珠伤害应各兑现一次")
	assert_eq(room.battle.shield[0][1], 2)
	assert_eq(int(room.battle.relics[0][0]["state"].get("charges", 0)), 2)
	assert_eq(int(room.battle.get_status(0, 0, "vuln", 0)), 0)
	assert_eq(room.battle.free_switch_uses[0], 1)


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
	# Act（重连令牌=match_start 第一条下发·2026-07-17 身份门后必带）
	var rtk0 := String(((sent[0] as Array)[0] as Dictionary).get("rtk", ""))
	room.handle(0, NetProtocol.msg_resync(rtk0))
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
	room.battle.energy_max = [18, 12]
	room.battle.relics[0].append({
		data = ItemCatalog.make("t3_yemingzhu"), state = {charges = 2},
	})
	room.battle.item_buffs[0]["free_big_attack_until_turn"] = room.battle.turn_number
	var snap: Dictionary = room.battle.to_snapshot()
	# Act
	var flipped: Dictionary = MatchClient.flip_snapshot(snap)
	# Assert：双翻恒等·翻转后可恢复且视角互换（加入方镜像契约）
	assert_eq_deep(MatchClient.flip_snapshot(flipped), snap)
	var b := BattleCore.new()
	assert_true(b.from_snapshot(flipped))
	assert_eq(b.energy[0], 3, "翻转后玩家0=原玩家1")
	assert_eq(b.energy[1], 9)
	assert_eq(b.energy_max, [12, 18], "动态能量上限应随玩家视角一起翻转")
	assert_eq((b.relics[1][0]["data"] as ItemData).item_id, "t3_yemingzhu")
	assert_eq(int(b.relics[1][0]["state"].get("charges", 0)), 2,
		"遗物权威次数应随所属玩家一起翻转")
	assert_eq(int(b.item_buffs[1].get("free_big_attack_until_turn", -1)), room.battle.turn_number,
		"免费大波窗口应随所属玩家一起翻转")
	assert_eq((b.heroes[0][0] as HeroData).hero_id, "b1", "翻转后己方阵容=原对方阵容")
	# winner 常量互换
	var w := snap.duplicate(true)
	w["winner"] = BattleCore.WINNER_P1
	assert_eq(int(MatchClient.flip_snapshot(w)["winner"]), BattleCore.WINNER_P2)
	# 事件翻转：player 0↔1·victory winner 互换
	var evs: Array = [
		{id = "damage_taken", player = 0, amount = 2},
		{id = "victory", winner = BattleCore.WINNER_P1},
		{id = "relic_trigger", player = 0, item_id = "t3_yemingzhu"},
	]
	var fev: Array = MatchClient.flip_events(evs)
	assert_eq(int(fev[0]["player"]), 1)
	assert_eq(int(fev[1]["winner"]), BattleCore.WINNER_P2)
	assert_eq(int(fev[2]["player"]), 1)
	assert_eq(String(fev[2]["item_id"]), "t3_yemingzhu", "遗物ID不是阵营字段，不得被视角翻转改写")


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
	# Act（重连 hello 带身份令牌·2026-07-17 门后必带）
	var rtk1 := String(((sent[1] as Array)[0] as Dictionary).get("rtk", ""))
	room.handle(1, NetProtocol.msg_hello(["h01", "h05", "h06"], "", "", rtk1))
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
	# Act：同一毫秒灌 100 个 resync（带正牌令牌·测的是防洪不是身份门）
	var rtk0 := String(((sent[0] as Array)[0] as Dictionary).get("rtk", ""))
	for _i in 100:
		room.handle(0, NetProtocol.msg_resync(rtk0))
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
	room.handle(0, NetProtocol.msg_resync(rtk0))
	assert_gt((sent[0] as Array).size(), b2, "令牌回填后应恢复响应")


func _last_error(msgs: Array) -> String:
	for i in range(msgs.size() - 1, -1, -1):
		if String((msgs[i] as Dictionary).get("kind", "")) == "error":
			return String((msgs[i] as Dictionary).get("code", ""))
	return ""


func test_match_room_submitted_player_economy_frozen() -> void:
	# Arrange（2026-07-17 审计修复②）：提交动作后经济状态必须冻结——否则提交后
	# 抽卡/补充改真局 → 缓存动作落真局时预检结论失效（能量已花=部分应用污染）。
	var t := _table(5)
	var c0: MatchClient = t.clients[0]
	_pump(t)
	var energy_before: int = int((t.room as MatchRoom).battle.energy[0])
	c0.submit(ActionDef.Action.CHARGE, -1, [])
	_pump(t)

	# Act：提交后尝试经济操作（门必须先于一切槽状态判断）
	c0.request_refill(0)
	c0.request_draft(0)
	_pump(t)

	# Assert：全拒 already_submitted·真局能量分文未动
	assert_true(c0.errors.has("already_submitted"), "提交后经济操作应拒 already_submitted")
	assert_eq(int((t.room as MatchRoom).battle.energy[0]), energy_before, "提交后的经济操作不得改变真局能量")


func test_match_room_snapshot_hides_opponent_draft_options() -> void:
	# Arrange（2026-07-17 审计修复③）：往 P0 槽 0 塞 3 选 1 候选（模拟 draft 进行中）
	var t := _table(5)
	_pump(t)
	var room: MatchRoom = t.room
	var some_id: String = String(ItemCatalog.ids()[0])
	(room.battle.slots[0][0] as Dictionary)["draft"] = [ItemCatalog.make(some_id)]
	(room.battle.slots[0][0] as Dictionary)["upg_draft"] = [ItemCatalog.make("t3_jianyi")]
	room.battle.relics[0].append({
		data = ItemCatalog.make("t3_budongmingwang"), state = {charges = 2},
	})
	room.battle.item_buffs[0]["free_big_attack_until_turn"] = room.battle.turn_number

	# Act：双方各自 resync 拿全量快照
	(t.clients[0] as MatchClient).request_resync()
	(t.clients[1] as MatchClient).request_resync()
	_pump(t)

	# Assert：本人快照含候选·对手快照被剥空（防改包偷看=「只发本人」不再有快照后门）
	var snap0: Dictionary = (t.clients[0] as MatchClient).snapshot["snap"]
	var snap1: Dictionary = (t.clients[1] as MatchClient).snapshot["snap"]
	var mine: Array = snap0["slots"][0][0]["draft"]
	var theirs: Array = snap1["slots"][0][0]["draft"]
	assert_eq(mine.size(), 1, "本人应看到自己的候选")
	assert_eq(theirs.size(), 0, "对手侧快照的候选必须剥空")
	assert_eq((snap0["slots"][0][0]["upg_draft"] as Array).size(), 1,
		"本人应看到自己的点金石传说候选")
	assert_eq((snap1["slots"][0][0]["upg_draft"] as Array).size(), 0,
		"对手侧快照不得通过点金石缓存泄漏传说候选")
	for public_snap in [snap0, snap1]:
		assert_eq(String(public_snap["relics"][0][0].get("id", "")), "t3_budongmingwang",
			"已激活遗物属于公开战局信息")
		assert_eq(int(public_snap["relics"][0][0]["state"].get("charges", 0)), 2)
		assert_eq(int(public_snap["item_buffs"][0].get("free_big_attack_until_turn", -1)),
			room.battle.turn_number, "免费大波窗口必须通过权威重连快照恢复")


func test_match_room_reconnect_during_death_switch_restores_phase() -> void:
	# Arrange（2026-07-17 审计修复）：DEATH_SWITCH 期没有 turn_begin 可跟——重连快照
	# 必须恢复相位，否则客户端只能干等服务器超时代选。夹具直设房间/引擎态。
	var t := _table(5)
	_pump(t)
	var room: MatchRoom = t.room
	room.phase = MatchRoom.Phase.DEATH_SWITCH
	room.battle.pending_death_switch = [true, false]

	# Act：双方各自重连 resync
	(t.clients[0] as MatchClient).request_resync()
	(t.clients[1] as MatchClient).request_resync()
	_pump(t)

	# Assert：待换人方恢复 death_switch·对方=waiting（等对面选）
	assert_eq((t.clients[0] as MatchClient).phase, "death_switch", "pending 方重连应直接回到选替补")
	assert_eq((t.clients[1] as MatchClient).phase, "waiting", "非 pending 方重连=等待对面")


func test_enet_transport_released_without_close() -> void:
	# 审计修复（2026-07-17 三轮①）：信号 lambda 弱捕获——不 close 也随引用归零释放
	# （原=lambda 捕获 self 经 peer 信号成环·RefCounted 永生·每次建房/拨号泄一对）。
	var t: RefCounted = NetTransport.ENetTransport.new()
	var wr: WeakRef = weakref(t)

	# Act：唯一引用归零
	t = null

	# Assert
	assert_null(wr.get_ref(), "ENetTransport 应随引用归零释放（无 lambda 引用环）")


func test_match_room_defer_deadline_freezes_countdown() -> void:
	# 审计修复（三轮②）：断线期 deadline 顺延——旧行为只是"不检查"·时间照流·
	# 重连同帧旧 deadline 立即触发被代提交「攒」。
	var t := _table(5)
	var room: MatchRoom = t.room
	var fake_ms: Array = [0]
	room.now_ms = func() -> int: return int(fake_ms[0])
	room._deadline_ms = 5000   # 换假时钟坐标系重新武装
	_pump(t)
	var turn_before: int = room.battle.turn_number

	# Act：模拟断线 8s=顺延 8000 → 原 deadline(5000) 时刻已过但顺延后(13000)未到
	room.defer_deadline(8000)
	fake_ms[0] = 8000
	room.check_deadline()
	assert_eq(room.battle.turn_number, turn_before, "顺延期内不得代提交推进回合")

	# Act：过顺延后的 deadline → 双方被代提交「攒」→ 回合推进
	fake_ms[0] = 14000
	room.check_deadline()
	assert_gt(room.battle.turn_number, turn_before, "过顺延后 deadline 才代提交")


func test_match_room_reconnect_requires_token() -> void:
	# 审计修复（三轮③）：中局重连身份门——原行为=任何过口令门（公开房无门）的新连接
	# 都能顶席位拿快照+控制权。令牌 match_start 只发本人·hello/resync 报到必须对上。
	var t := _table(5)
	_pump(t)
	var c0: MatchClient = t.clients[0]
	var c1: MatchClient = t.clients[1]
	assert_false(c0.rtk.is_empty(), "match_start 应下发重连令牌")

	# Act / Assert：正牌（resync 自动带 rtk）→ 收快照
	c0.request_resync()
	_pump(t)
	assert_false(c0.snapshot.is_empty(), "正牌令牌应收到快照")

	# Act / Assert：伪牌 → bad_token 拒·快照不发
	(t.room as MatchRoom).handle(1, NetProtocol.msg_resync("wrong_token"))
	_pump(t)
	assert_true(c1.errors.has("bad_token"), "伪令牌应拒 bad_token")
	assert_true(c1.snapshot.is_empty(), "伪令牌不得拿到快照")


func test_net_protocol_hello_rejects_duplicate_team_ids() -> void:
	# 审计修复（三轮⑦）：旧 LAN 直开局路径可被恶意客户端塞同队重复英雄。
	assert_eq(NetProtocol.validate_c2s(NetProtocol.msg_hello(["h01", "h01", "h02"])), "bad_team")
	assert_eq(NetProtocol.validate_c2s(NetProtocol.msg_hello(["h01", "h02", "h03"])), "")


func test_net_protocol_version_field_type_gate() -> void:
	# 终审修复（2026-07-17）：v 字段先验类型——旧 int() 强转让 "1"/true/1.9 全过门·
	# Array/Dictionary 直接运行时脚本错误（10 万畸形包=3.5 万报错/12.7MB 日志放大）。
	for bad_v: Variant in ["1", true, 1.9, [], {}, null]:
		assert_eq(NetProtocol.validate_c2s({"v": bad_v, "kind": "resync", "rtk": ""}),
			"version_mismatch", "v=%s 应拒" % str(bad_v))
	# JSON 线上形态（int→float 整数值）必须放行
	assert_eq(NetProtocol.validate_c2s({"v": 1.0, "kind": "resync", "rtk": ""}), "")
