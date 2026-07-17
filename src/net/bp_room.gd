extends RefCounted

## BP 选人权威房间（2026-07-17 打地基批·BP 联机化逻辑层——UI 接线待任务12 风格定案后挂 bp_screen）。
## 定位=开局前置阶段：大厅 hello 过门（空 team=BP 流程报到）→ 本房间跑同时盲选 →
## 双方 bp_confirm → bp_reveal 同时揭晓 → 宿主拿 teams() 换 HeroData 转 MatchRoom.start（战斗照旧）。
## 纯逻辑零 socket（match_room 同款）：出站消息经 send_cb(player, msg) 回调交传输层 → GUT 可测。
##
## 规则（与本地 bp_screen 同制）：
##   - pick-only 同时盲选（去 ban·24 池容不下 ban）；镜像可=双方可选同英雄；队内禁重复。
##   - bp_progress 只转发张数（0..3）不带内容——对手席盖牌演出的真信号源（实时压力不泄内容）。
##   - 超时=服务端权威计时（假时钟可注入·GUT 可测）：到点未确认方由服务器随机补满
##     （本地 _auto_fill 的服务端对位）→ 照常揭晓。
##   - BP 期收到 hello/resync=断线重连报到 → 补发 bp_start+对方进度（轻量重连·战斗期重连另有全量快照）。
##
## 用法（net_session.start_bp 同款）：
##   var bp := BpRoom.new()   # preload 引用
##   bp.start(pool_ids, seed, func(p, msg): transport[p].send(msg))
##   bp.handle(0, msg_from_client0)   # 传输层收到包 → 喂这里
##   bp.check_deadline()              # 宿主每帧（net_session.pump_bp）
##   if bp.done(): MatchRoom.start(拿 bp.teams() 换 HeroData, ...)

const NetProtocol := preload("res://src/net/net_protocol.gd")

enum Phase { DRAFT, DONE }

const DRAFT_TIME_MS := 30000        # 与 bp_screen STEP_TIME=30s 对齐（客户端超时自确认先到·这是兜底）
const DEADLINE_GRACE_MS := 4000     # match_room 同款宽限（覆盖入场演出漂移）
const RATE_BURST := 30.0            # 防洪令牌桶（match_room 同参）
const RATE_REFILL_PER_SEC := 10.0

var phase: int = Phase.DRAFT
var pool: Array = []                     # hero_id 池快照（合法性校验的白名单）
var picks: Array = [[], []]              # 双方最终选择（confirm 落定·绝对视角）
var confirmed: Array = [false, false]
var progress: Array = [0, 0]             # 双方已亮张数（重连补发用）
var now_ms: Callable = Callable(Time, "get_ticks_msec")   # 测试注入假时钟
var _send: Callable                      # (player:int, msg:Dictionary) -> void
var _deadline_ms: int = 0
var _rng := RandomNumberGenerator.new()  # 超时代选用（种子注入=可复现）
var _rate_tokens: Array[float] = [RATE_BURST, RATE_BURST]
var _rate_last_ms: Array[int] = [0, 0]
var _rate_warned: Array[bool] = [false, false]


func start(pool_ids: Array, seed_v: int, send_cb: Callable) -> void:
	_send = send_cb
	pool = pool_ids.duplicate()
	_rng.seed = seed_v
	phase = Phase.DRAFT
	picks = [[], []]
	confirmed = [false, false]
	progress = [0, 0]
	_rate_last_ms = [int(now_ms.call()), int(now_ms.call())]
	_deadline_ms = int(now_ms.call()) + DRAFT_TIME_MS + DEADLINE_GRACE_MS
	for p in 2:
		_send.call(p, {v = NetProtocol.PROTO_VERSION, kind = "bp_start", you = p, pool = pool.duplicate()})


## 传输层入口。防洪（零道门）→ 协议校验（一道门）→ 业务校验（二道门）。
func handle(player: int, msg: Variant) -> void:
	if not _rate_ok(player):
		return
	var err := NetProtocol.validate_c2s(msg)
	if err != "":
		_send.call(player, NetProtocol.msg_error(err))
		return
	var d: Dictionary = msg
	match String(d["kind"]):
		"bp_progress":
			_on_progress(player, int(d["n"]))
		"bp_confirm":
			_on_confirm(player, d["picks"])
		"hello", "resync":
			# BP 期断线重连报到：补发 bp_start + 对方当前进度（客户端凭这两条重建界面）
			_send.call(player, {v = NetProtocol.PROTO_VERSION, kind = "bp_start", you = player, pool = pool.duplicate()})
			_send.call(player, {v = NetProtocol.PROTO_VERSION, kind = "bp_progress", n = int(progress[1 - player])})
		_:
			_send.call(player, NetProtocol.msg_error("bad_phase"))   # BP 期不收战斗包


func _on_progress(player: int, n: int) -> void:
	if phase != Phase.DRAFT or confirmed[player]:
		return   # 迟到/确认后的进度包静默丢（演出信号非状态·不值一个 error）
	progress[player] = n
	_send.call(1 - player, {v = NetProtocol.PROTO_VERSION, kind = "bp_progress", n = n})


func _on_confirm(player: int, arr: Array) -> void:
	if phase != Phase.DRAFT:
		_send.call(player, NetProtocol.msg_error("bad_phase"))
		return
	if confirmed[player]:
		_send.call(player, NetProtocol.msg_error("already_submitted"))
		return
	# 二道门（协议只验形状）：全在池内 + 队内无重复（镜像=跨队重复·合法）
	var seen := {}
	for id in arr:
		if not pool.has(id) or seen.has(id):
			_send.call(player, NetProtocol.msg_error("illegal_picks"))
			return
		seen[id] = true
	picks[player] = arr.duplicate()
	confirmed[player] = true
	progress[player] = NetProtocol.TEAM_SIZE
	_send.call(1 - player, {v = NetProtocol.PROTO_VERSION, kind = "bp_progress", n = NetProtocol.TEAM_SIZE})
	if confirmed[0] and confirmed[1]:
		_reveal()


## 服务端权威计时（宿主每帧调·net_session.pump_bp）：超时未确认方由服务器随机补满。
func check_deadline() -> void:
	if phase != Phase.DRAFT or int(now_ms.call()) < _deadline_ms:
		return
	for p in 2:
		if not confirmed[p]:
			picks[p] = _auto_picks()
			confirmed[p] = true
	_reveal()


func _reveal() -> void:
	phase = Phase.DONE
	for p in 2:
		_send.call(p, {v = NetProtocol.PROTO_VERSION, kind = "bp_reveal",
			picks = [picks[0].duplicate(), picks[1].duplicate()]})


## 超时代选：池内随机 3 个不重复（本地 _auto_fill 对位·种子可复现）。
func _auto_picks() -> Array:
	var cand := pool.duplicate()
	var out: Array = []
	while out.size() < NetProtocol.TEAM_SIZE and not cand.is_empty():
		out.append(cand.pop_at(_rng.randi_range(0, cand.size() - 1)))
	return out


func done() -> bool:
	return phase == Phase.DONE


## 揭晓结果（绝对视角·[房主队, 加入方队]·hero_id 串）——宿主换 HeroData 后喂 MatchRoom.start。
func teams() -> Array:
	return [picks[0].duplicate(), picks[1].duplicate()]


## M3b 同款防洪令牌桶：超额静默丢、首超回一次 rate_limited。
func _rate_ok(player: int) -> bool:
	var now := int(now_ms.call())
	var dt := maxf(0.0, float(now - _rate_last_ms[player]) / 1000.0)
	_rate_last_ms[player] = now
	_rate_tokens[player] = minf(RATE_BURST, _rate_tokens[player] + dt * RATE_REFILL_PER_SEC)
	if _rate_tokens[player] < 1.0:
		if not _rate_warned[player]:
			_rate_warned[player] = true
			_send.call(player, NetProtocol.msg_error("rate_limited"))
		return false
	_rate_warned[player] = false
	_rate_tokens[player] -= 1.0
	return true
