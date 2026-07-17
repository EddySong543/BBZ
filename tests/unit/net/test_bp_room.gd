extends GutTest

## BP 选人权威房间 行为锁定测试（2026-07-17 打地基批·BP 联机化逻辑层）。
## 桌面=BpRoom + 双 BpClient 经 LoopbackTransport（test_match_room 同款组桌）。
## 锁：bp_start 双发/进度只转发对方/确认二道门（池外·队内重复·重复确认全拒）/
##     双确认同时揭晓/镜像合法/超时服务器代选/协议形状校验/hello 空 team=BP 报到放行。

const NetProtocol := preload("res://src/net/net_protocol.gd")
const BpRoom := preload("res://src/net/bp_room.gd")
const BpClient := preload("res://src/net/bp_client.gd")
const NetTransport := preload("res://src/net/net_transport.gd")
const SEED := 4242
const POOL: Array = ["h01", "h02", "h03", "h04", "h05", "h06"]


## 组一桌：BP 房间 + 双方环回传输 + 双 BP 客户端。返回 {room, clients, server_ends, client_ends}。
func _table() -> Dictionary:
	var pair0: Array = NetTransport.LoopbackTransport.make_pair()
	var pair1: Array = NetTransport.LoopbackTransport.make_pair()
	var server_ends: Array = [pair0[0], pair1[0]]
	var client_ends: Array = [pair0[1], pair1[1]]
	var room: BpRoom = BpRoom.new()
	room.start(POOL, SEED,
		func(p: int, msg: Dictionary) -> void: server_ends[p].send(msg))
	var clients: Array = [BpClient.new(pair0[1]), BpClient.new(pair1[1])]
	return {room = room, clients = clients, server_ends = server_ends, client_ends = client_ends}


## 泵一拍：服务器收包喂房间 → 客户端收包 feed（net_session.pump_bp 的路由对位）。
func _pump(t: Dictionary) -> void:
	for p in 2:
		for msg in t["server_ends"][p].poll():
			(t.room as BpRoom).handle(p, msg)
	for p in 2:
		for msg in t["client_ends"][p].poll():
			(t.clients[p] as BpClient).feed(msg)


func test_bp_room_start_sends_bp_start_with_pool_both_ends() -> void:
	# Arrange / Act
	var t := _table()
	_pump(t)

	# Assert：双端都进 draft·各自席位正确·池一致
	for p in 2:
		var c: BpClient = t.clients[p]
		assert_eq(c.phase, "draft")
		assert_eq(c.you, p)
		assert_eq(c.pool, POOL)


func test_bp_room_progress_relays_to_opponent_only() -> void:
	# Arrange
	var t := _table()
	_pump(t)

	# Act：P0 报进度 2
	(t.clients[0] as BpClient).send_progress(2)
	_pump(t)

	# Assert：只有 P1 看到对方进度·P0 自己的 opp_progress 不动
	assert_eq((t.clients[1] as BpClient).opp_progress, 2)
	assert_eq((t.clients[0] as BpClient).opp_progress, 0)


func test_bp_room_confirm_rejects_out_of_pool_and_duplicates() -> void:
	# Arrange
	var t := _table()
	_pump(t)
	var c0: BpClient = t.clients[0]

	# Act / Assert：池外 id 拒
	c0.confirm(["h01", "h02", "h99"])
	_pump(t)
	assert_true(c0.errors.has("illegal_picks"), "池外 id 应拒")
	assert_false(bool((t.room as BpRoom).confirmed[0]))

	# Act / Assert：队内重复拒
	c0.confirm(["h01", "h01", "h02"])
	_pump(t)
	assert_eq(c0.errors.count("illegal_picks"), 2, "队内重复应拒")
	assert_false(bool((t.room as BpRoom).confirmed[0]))


func test_bp_room_double_confirm_rejected() -> void:
	# Arrange
	var t := _table()
	_pump(t)
	var c0: BpClient = t.clients[0]
	c0.confirm(["h01", "h02", "h03"])
	_pump(t)

	# Act：重复确认
	c0.confirm(["h04", "h05", "h06"])
	_pump(t)

	# Assert：拒收+首次结果不被覆盖
	assert_true(c0.errors.has("already_submitted"))
	assert_eq((t.room as BpRoom).picks[0], ["h01", "h02", "h03"])


func test_bp_room_both_confirm_reveals_same_result_both_ends() -> void:
	# Arrange
	var t := _table()
	_pump(t)

	# Act：双方各自确认（P0 确认后 P1 应先看到进度=3 的真信号）
	(t.clients[0] as BpClient).confirm(["h01", "h02", "h03"])
	_pump(t)
	assert_eq((t.clients[1] as BpClient).opp_progress, 3, "确认=对方看到 3/3 盖牌信号")
	(t.clients[1] as BpClient).confirm(["h04", "h05", "h06"])
	_pump(t)

	# Assert：双端同时揭晓·视角各自正确·房间 teams() 与揭晓一致
	for p in 2:
		assert_eq((t.clients[p] as BpClient).phase, "done")
	assert_eq((t.clients[0] as BpClient).my_picks(), ["h01", "h02", "h03"])
	assert_eq((t.clients[0] as BpClient).opp_picks(), ["h04", "h05", "h06"])
	assert_eq((t.clients[1] as BpClient).my_picks(), ["h04", "h05", "h06"])
	assert_eq((t.clients[1] as BpClient).opp_picks(), ["h01", "h02", "h03"])
	assert_true((t.room as BpRoom).done())
	assert_eq((t.room as BpRoom).teams(), [["h01", "h02", "h03"], ["h04", "h05", "h06"]])


func test_bp_room_mirror_picks_across_teams_allowed() -> void:
	# Arrange：镜像=双方选同英雄（战斗核支持镜像局·跨队重复合法）
	var t := _table()
	_pump(t)

	# Act
	(t.clients[0] as BpClient).confirm(["h01", "h02", "h03"])
	(t.clients[1] as BpClient).confirm(["h01", "h02", "h03"])
	_pump(t)

	# Assert
	assert_true((t.room as BpRoom).done())
	assert_eq((t.room as BpRoom).teams()[0], (t.room as BpRoom).teams()[1])


func test_bp_room_deadline_autofills_unconfirmed_player() -> void:
	# Arrange：假时钟桌（超时=服务端代选·本地 _auto_fill 对位）
	var fake_ms: Array = [0]
	var t := _table()
	var room: BpRoom = t.room
	room.now_ms = func() -> int: return int(fake_ms[0])
	_pump(t)
	(t.clients[0] as BpClient).confirm(["h01", "h02", "h03"])
	_pump(t)

	# Act：拨过时限 → 服务器代 P1 补满
	fake_ms[0] = BpRoom.DRAFT_TIME_MS + BpRoom.DEADLINE_GRACE_MS + 60000
	room.check_deadline()
	_pump(t)

	# Assert：双端揭晓·P1 队=3 个池内不重复
	assert_true(room.done())
	assert_eq((t.clients[1] as BpClient).phase, "done")
	var auto: Array = room.teams()[1]
	assert_eq(auto.size(), 3)
	var seen := {}
	for id in auto:
		assert_true(POOL.has(id), "代选必须在池内")
		assert_false(seen.has(id), "代选不得重复")
		seen[id] = true


func test_net_protocol_bp_message_shapes_validated() -> void:
	# Assert：构造器出的包必过校验
	assert_eq(NetProtocol.validate_c2s(NetProtocol.msg_bp_progress(2)), "")
	assert_eq(NetProtocol.validate_c2s(NetProtocol.msg_bp_confirm(["h01", "h02", "h03"])), "")
	# Assert：形状破包全拒
	assert_eq(NetProtocol.validate_c2s({v = 1, kind = "bp_progress", n = 7}), "bad_n")
	assert_eq(NetProtocol.validate_c2s({v = 1, kind = "bp_confirm", picks = ["h01"]}), "bad_picks")
	assert_eq(NetProtocol.validate_c2s({v = 1, kind = "bp_confirm", picks = ["h01", "h02", "../evil"]}), "bad_picks")
	# Assert：hello 空 team=BP 流程报到（2026-07-17 放行）·凑数尺寸仍拒
	assert_eq(NetProtocol.validate_c2s(NetProtocol.msg_hello([])), "")
	assert_eq(NetProtocol.validate_c2s(NetProtocol.msg_hello(["h01"])), "bad_team")
