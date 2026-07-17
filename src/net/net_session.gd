extends RefCounted

## 联机会话（M1·2026-07-12）：一场联机局的"接线盒"——传输 + 房间（房主侧）+ 本端协议客户端。
## 寄存在 BattleSetup.net_session（沿用跨场景总线模式·零新 autoload/零 project.godot 改动），
## 由大厅屏创建、battle_screen 每帧 pump()、battle_screen 退场时 close() 并置空。
##
## 拓扑（与 tools/net_probe 实测一致）：
##   房主进程：MatchRoom + 本端走 Loopback（玩家0）+ 对外 ENet 服务器（玩家1）
##   加入进程：仅 ENet 客户端（玩家1）——权威核不在本机=作弊面最小

const NetTransport := preload("res://src/net/net_transport.gd")
const MatchRoom := preload("res://src/net/match_room.gd")
const MatchClient := preload("res://src/net/match_client.gd")
const NetProtocol := preload("res://src/net/net_protocol.gd")
const BpRoom := preload("res://src/net/bp_room.gd")
const BpClient := preload("res://src/net/bp_client.gd")

const DEFAULT_PORT := 47777
const KICK_GRACE_MS := 300            # 拒绝后延迟踢席位（先让 error 包送达·立踢会跟断连赛跑丢包·2026-07-14 探针实证）

var role := ""                        # "host" / "join"
var enet: NetTransport.ENetTransport
var room: MatchRoom = null            # 仅房主
var _loop_room_end: Variant = null    # 房主：房间侧环回端（收本地玩家包）
var client: MatchClient
var bp: BpRoom = null                 # 仅房主·BP 前置阶段（2026-07-17 BP 联机化）
var bp_client: BpClient = null        # 双方·BP 阶段本端（UI 读进度/揭晓）
var password := ""                    # 房主：房间口令（空=公开房·好友房准入·2026-07-14）
var last_reject := ""                 # 房主：最近一次准入拒绝（"bad_pass"/"bad_version:<对方版本>"·大厅读后清）
var _kick_at_ms := 0                  # >0=到点踢当前对端（拒绝方通常先自行断开·这是兜底）


## 建房：开 ENet 门 + 本地环回接自己的客户端。room_pass=房间口令（空=公开房）。失败返回 null。
static func create_host(port: int = DEFAULT_PORT, room_pass: String = "") -> RefCounted:
	var s := new()
	s.role = "host"
	s.password = room_pass
	s.enet = NetTransport.ENetTransport.new()
	if not s.enet.host(port):
		return null
	s.enet.max_packet_bytes = 8192   # M3a：服务器只收 C2S 小包·超限即丢（S2C 大快照不受影响）
	var pair: Array = NetTransport.LoopbackTransport.make_pair()
	s._loop_room_end = pair[0]
	s.client = MatchClient.new(pair[1])
	return s


## 加入：拨号房主。失败返回 null（真正连上与否看 is_link_ready()）。
static func create_join(ip: String, port: int = DEFAULT_PORT) -> RefCounted:
	var s := new()
	s.role = "join"
	s.enet = NetTransport.ENetTransport.new()
	if not s.enet.join(ip, port):
		return null
	s.client = MatchClient.new(s.enet)
	return s


## ENet 链路是否建立（对端已握手）。
## ⚠ 必须走 pump_only（只泵不取包）——曾用 enet.poll() 导致业务包被整批吃掉（2026-07-14 探针抓获）。
func is_link_ready() -> bool:
	enet.pump_only()
	return enet.is_ready()


## 房主开局（对端连上后调用一次）：t0=房主队 t1=加入方队。
func start_room(t0: Array, t1: Array, seed_v: int) -> void:
	room = MatchRoom.new()
	room.start(t0, t1, seed_v, func(p: int, msg: Dictionary) -> void:
		if p == 0:
			_loop_room_end.send(msg)
		else:
			enet.send(msg))


# ============================================================
# BP 前置阶段（2026-07-17 打地基批·逻辑层——UI 接线待任务12）
# ============================================================

## 房主开 BP（对端 hello 过门后·代替直接 start_room）：pool_ids=英雄 id 池。
## BP 双确认揭晓后：if bp.done() → 拿 bp.teams() 换 HeroData → start_room（战斗照旧）。
func start_bp(pool_ids: Array, seed_v: int) -> void:
	bp = BpRoom.new()
	bp.start(pool_ids, seed_v, func(p: int, msg: Dictionary) -> void:
		if p == 0:
			_loop_room_end.send(msg)
		else:
			enet.send(msg))
	ensure_bp_client()


## 双方：备好 BP 客户端端（加入方在进 BP 流程时调·房主 start_bp 自带）。
func ensure_bp_client() -> void:
	if bp_client == null:
		bp_client = BpClient.new(client.transport)


## BP 期泵（room 未建立期间·BP 屏/大厅每帧调）：房主收双路包喂 BP 房间+权威计时；
## 双方按 kind 路由本端包（bp_*→bp_client·其余→client=match_start 到达即无缝转战斗）。
## ⚠ 与 pump() 互斥使用（同一 transport 双泵会互抢包）：BP 期用这个·战斗期用 pump()。
func pump_bp() -> void:
	if role == "host" and bp != null and room == null:
		_tick_kick()
		for msg in _loop_room_end.poll():
			bp.handle(0, msg)
		for msg in enet.poll():
			if String(msg.get("kind", "")) == "hello" and not hello_pass_ok(msg):
				enet.send(NetProtocol.msg_error("bad_pass"))
				_schedule_kick()   # 重连报到同过口令门（pump 同款·防抢席位）
				continue
			bp.handle(1, msg)
		bp.check_deadline()
	if bp_client != null:
		for msg in client.transport.poll():
			if String(msg.get("kind", "")).begins_with("bp_"):
				bp_client.feed(msg)
			else:
				client.feed(msg)


## 每帧泵：房主=收双路包喂房间+服务端计时；双方=消化本端客户端消息。
## M2b：对端断线期间暂停权威计时——断线方不因掉线被计时判负（重连即续战）。
## 2026-07-14：重连 hello 同样过口令门——防陌生人趁好友掉线抢占唯一席位。
func pump() -> void:
	if role == "host" and room != null:
		_tick_kick()
		for msg in _loop_room_end.poll():
			room.handle(0, msg)
		for msg in enet.poll():
			if String(msg.get("kind", "")) == "hello" and not hello_pass_ok(msg):
				enet.send(NetProtocol.msg_error("bad_pass"))
				_schedule_kick()   # 腾出唯一席位给真正的重连方（延迟踢·让 error 先送达）
				continue
			room.handle(1, msg)
		if enet.is_ready():
			room.check_deadline()   # M3b：服务端权威计时（拖时→代提交攒/代选替补）
	client.poll()


## 开局前收包口（M2b 建·2026-07-14 内置准入门·仅房主大厅用·room 建立前）：
## 返回通过门的 hello（报到+阵容）；坏包丢弃·版本不合/口令不对 → 回 error+踢席位，
## 拒绝原因写 last_reject（大厅读了展示后自行清空）。
func poll_prestart() -> Array:
	if role != "host" or room != null:
		return []
	_tick_kick()
	var ok: Array = []
	for msg in enet.poll():
		if NetProtocol.validate_c2s(msg) != "" or String(msg.get("kind", "")) != "hello":
			continue
		var gv := String(msg.get("gv", ""))
		if gv != NetProtocol.game_version():
			enet.send(NetProtocol.msg_error("bad_version", NetProtocol.game_version()))
			_schedule_kick()
			last_reject = "bad_version:" + gv
			continue
		if not hello_pass_ok(msg):
			enet.send(NetProtocol.msg_error("bad_pass"))
			_schedule_kick()
			last_reject = "bad_pass"
			continue
		ok.append(msg)
	return ok


## 口令门（纯逻辑·GUT 可测）：没设口令=全放行；设了=hello 的 pass 字段必须全等。
func hello_pass_ok(msg: Dictionary) -> bool:
	return password.is_empty() or String(msg.get("pass", "")) == password


## 延迟踢：先送 error 再到点踢（立踢=断连跟排队包赛跑·error 会丢）。对端多数自行断开，这是兜底。
func _schedule_kick() -> void:
	if _kick_at_ms == 0:
		_kick_at_ms = Time.get_ticks_msec() + KICK_GRACE_MS


func _tick_kick() -> void:
	if _kick_at_ms > 0 and Time.get_ticks_msec() >= _kick_at_ms:
		_kick_at_ms = 0
		enet.kick()


func close() -> void:
	if enet != null:
		enet.close()
