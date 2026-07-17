extends RefCounted

## 权威对局房间（联机线批B·2026-07-12·ADR-004 M2 核心）：服务端持唯一 BattleCore，
## 客户端只提交意图，一切合法性在此校验——绝不信任客户端（network-code.md §1）。
## 纯逻辑零 socket：出站消息经 send_cb(player, msg) 回调交给传输层 → GUT 可整局测试。
##
## 关键机制：
##   - 提交预检走 clone（use_slot/apply_choice 整套在克隆上跑通才收下·非法提交零污染真局·
##     与 AI 异步预想同款模式）；双方到齐一次性落真局+resolve。
##   - 抽卡/升级选项由真局 core.rng 生成（服务器权威随机）·draft_offer 只发本人（私有信息）。
##   - 死亡换人=resolve 后 DEATH_SWITCH 相位，逐方提交，清空后开新回合。
##   - 断线重连：resync → 按接收者过滤的快照（_snap_for·2026-07-17 审计修复：对方 draft/
##     upg_draft 候选+info_distortion 剥除——改包客户端偷看不到 3 选 1）。
##   - 提交即锁经济（_econ_gate·同批修复）：已提交方的 draft/refill/pick 全拒——防提交后
##     改真局让缓存动作的预检结论失效。
##   - 平局=直接结案（线上加时赛=后续立项·同故事模式先例）。回合计时=M3（服务端计时）。
##
## 用法（测试/未来 match_host 同款）：
##   var room := MatchRoom.new()   # preload 引用
##   room.start(team0, team1, seed, func(p, msg): transport[p].send(msg))
##   room.handle(0, msg_from_client0)   # 传输层收到包 → 喂这里

const NetProtocol := preload("res://src/net/net_protocol.gd")

enum Phase { SELECT, DEATH_SWITCH, OVER }

# —— M3b 服务端计时/防洪（时钟可注入=GUT 可测·真实源 Time.get_ticks_msec）——
const TURN_TIME_STEPS: Array = [[5, 20], [2, 15], [0, 10]]   # 与 battle_screen:47 同表（服务器=权威·客户端=显示）
const DEADLINE_GRACE_MS := 4000      # 比客户端显示宽 4s（覆盖回合开场演出漂移）：正常时客户端超时自提交先到·这是拖时/挂机的兜底
const SWITCH_TIME_MS := 20000        # 死亡换人时限
const RATE_BURST := 30.0             # 防洪令牌桶：突发上限（正常一回合十几个包远够）
const RATE_REFILL_PER_SEC := 10.0    # 每秒回填

var battle: BattleCore
var phase: int = Phase.SELECT
var now_ms: Callable = Callable(Time, "get_ticks_msec")   # 测试注入假时钟
var _rtk: Array[String] = ["", ""]     # 重连令牌（2026-07-17 审计修复·match_start 只发本人·重连报到必对上）
var _send: Callable                    # (player:int, msg:Dictionary) -> void
var _pending: Array = [null, null]     # 本回合已收提交（先到先锁·拒绝重复提交）
var _deadline_ms: int = 0
var _rate_tokens: Array[float] = [RATE_BURST, RATE_BURST]
var _rate_last_ms: Array[int] = [0, 0]
var _rate_warned: Array[bool] = [false, false]


func start(team0: Array, team1: Array, seed_v: int, send_cb: Callable) -> void:
	_send = send_cb
	battle = BattleCore.new()
	battle.setup(team0, team1, seed_v)
	battle.econ_init()
	phase = Phase.SELECT
	_pending = [null, null]
	_rate_last_ms = [int(now_ms.call()), int(now_ms.call())]
	_arm_turn_deadline()
	# 重连令牌（2026-07-17 审计修复）：开局发给各自玩家·中局重连报到必须对上——
	# 否则原玩家掉线后任何过口令门（公开房=无门）的新连接都能顶席位拿快照+控制权。
	var crypto := Crypto.new()
	for p in 2:
		_rtk[p] = crypto.generate_random_bytes(16).hex_encode()
	for p in 2:
		_send.call(p, {v = NetProtocol.PROTO_VERSION, kind = "match_start", you = p,
			heroes = [_pack_team(0), _pack_team(1)], turn = battle.turn_number, view = _view(),
			rtk = _rtk[p], snap = _snap_for(p)})


## 传输层入口：一切客户端包从这进。防洪（零道门）→ 协议校验（一道门）→ 回合号校验 → 业务校验（二道门）。
func handle(player: int, msg: Variant) -> void:
	if not _rate_ok(player):
		return   # M3b 防洪：超额包静默丢（回错误包本身也会被刷成放大器·只在首超回一次提示）
	var err := NetProtocol.validate_c2s(msg)
	if err != "":
		_send.call(player, NetProtocol.msg_error(err))
		return
	var d: Dictionary = msg
	var kind := String(d["kind"])
	if kind == "resync" or kind == "hello":
		# 开局后的 hello = 断线重连报到（阵容字段忽略——阵容在开局时已定死·防中途换队）。
		# 身份门（2026-07-17 审计修复）：重连令牌必须对上（match_start 只发过本人）——
		# resync 同过此门·防新连接顶席位后跳过 hello 直接 resync 拿快照。
		if String(d.get("rtk", "")) != _rtk[player] or _rtk[player].is_empty():
			_send.call(player, NetProtocol.msg_error("bad_token"))
			return
		_send.call(player, {v = NetProtocol.PROTO_VERSION, kind = "snapshot", you = player,
			phase = phase, snap = _snap_for(player)})
		if phase == Phase.SELECT:
			# 补发 turn_begin：重连者立刻回到选招（否则要干等到下一拍）
			_send.call(player, {v = NetProtocol.PROTO_VERSION, kind = "turn_begin",
				turn = battle.turn_number, view = _view(), snap = _snap_for(player)})
		return
	if phase == Phase.OVER:
		_send.call(player, NetProtocol.msg_error("match_over"))
		return
	if int(d["turn"]) != battle.turn_number:
		_send.call(player, NetProtocol.msg_error("turn_mismatch"))
		return
	match kind:
		"submit_turn":
			_on_submit(player, d)
		"econ_draft":
			_on_econ_draft(player, int(d["slot"]), false)
		"econ_upgrade":
			_on_econ_draft(player, int(d["slot"]), true)
		"econ_refill":
			_on_econ_refill(player, int(d["slot"]))
		"econ_pick":
			_on_econ_pick(player, d)
		"death_switch":
			_on_death_switch(player, int(d["slot"]))


func _on_submit(player: int, d: Dictionary) -> void:
	if phase != Phase.SELECT:
		_send.call(player, NetProtocol.msg_error("bad_phase"))
		return
	if _pending[player] != null:
		_send.call(player, NetProtocol.msg_error("already_submitted"))
		return
	# 合法性预检：克隆上整套跑通（道具槽逐个 use_slot + 动作 apply_choice）才收下
	var probe := battle.clone()
	if not _apply_payload(probe, player, d):
		_send.call(player, NetProtocol.msg_error("illegal_submission"))
		return
	_pending[player] = d
	if _pending[0] != null and _pending[1] != null:
		_commit_and_resolve()


func _apply_payload(core: BattleCore, player: int, d: Dictionary) -> bool:
	for s in d["item_slots"]:
		if not core.use_slot(player, int(s)):
			return false
	# 动作合法性=legal_actions 白名单精确匹配（apply_choice 对未知动作号可能宽容·权威校验不赌下游）
	var want_action := int(d["action"])
	var want_target := int(d["target"])
	var legal := false
	for la in core.legal_actions(player):
		if int(la["action"]) == want_action and int(la["target"]) == want_target:
			legal = true
			break
	if not legal:
		return false
	if not core.apply_choice(player, {action = want_action, target = want_target}):
		return false
	# 疾风附加动作（h16）：付第二份能·can_double 把门
	if bool(d.get("double", false)):
		if not core.can_double(player):
			return false
		core.select_double(player, true)
	return true


func _commit_and_resolve() -> void:
	for p in 2:
		# 预检已过且提交即锁经济（_econ_gate）→ 此处应必成；万一失败=真局与预检漂移·
		# 状态可能已部分应用——绝不静默（2026-07-17 审计修复）。
		if not _apply_payload(battle, p, _pending[p]):
			push_error("MatchRoom: 已提交动作落真局失败（p%d·预检与真局漂移·请查经济门）" % p)
	var r: Dictionary = battle.resolve()
	var pending := battle.pending_death_switch.duplicate()
	if battle.game_over:
		phase = Phase.OVER
	elif bool(pending[0]) or bool(pending[1]):
		phase = Phase.DEATH_SWITCH
		_deadline_ms = int(now_ms.call()) + SWITCH_TIME_MS
	for p in 2:
		_send.call(p, {v = NetProtocol.PROTO_VERSION, kind = "resolve",
			actions = [r.get("p1_action", -1), r.get("p2_action", -1)],
			events = r.get("events", []), pending = pending, view = _view(),
			snap = _snap_for(p)})
	if phase == Phase.OVER:
		for p in 2:
			_send.call(p, NetProtocol.msg_game_over(battle.winner))
	elif phase == Phase.SELECT:
		_begin_turn()


func _begin_turn() -> void:
	phase = Phase.SELECT
	_pending = [null, null]
	_arm_turn_deadline()
	for p in 2:
		_send.call(p, {v = NetProtocol.PROTO_VERSION, kind = "turn_begin",
			turn = battle.turn_number, view = _view(), snap = _snap_for(p)})


## 断线冻结（2026-07-17 审计修复）：deadline 是绝对时间戳——旧行为"断线期不检查"只是不判，
## 时间照流·重连同帧立即超时被代提交「攒」。真冻结=随断线时长顺延（net_session.pump 断链期喂）。
func defer_deadline(ms: int) -> void:
	_deadline_ms += maxi(0, ms)


func _arm_turn_deadline() -> void:
	var secs := 10
	for step in TURN_TIME_STEPS:
		if battle.turn_number >= int(step[0]):
			secs = int(step[1])
			break
	_deadline_ms = int(now_ms.call()) + secs * 1000 + DEADLINE_GRACE_MS


## M3b 服务端计时（宿主每帧调·net_session.pump）：超时方由服务器代提交——
## 选招=攒·死亡换人=首个存活替补。拖时/挂机/断网不再能锁死对局（服务端权威计时·客户端计时=纯显示）。
func check_deadline() -> void:
	if phase == Phase.OVER or int(now_ms.call()) < _deadline_ms:
		return
	if phase == Phase.SELECT:
		var turn := battle.turn_number
		var missing: Array[int] = []
		for p in 2:
			if _pending[p] == null:
				missing.append(p)
		for p in missing:
			_on_submit(p, NetProtocol.msg_submit_turn(turn, ActionDef.Action.CHARGE, -1, []))
	elif phase == Phase.DEATH_SWITCH:
		for p in 2:
			if battle.pending_death_switch[p]:
				var res: Array = battle.living_reserves(p)
				if res.size() > 0:
					_on_death_switch(p, int(res[0]))


## M3b 防洪令牌桶：突发 RATE_BURST·每秒回填 RATE_REFILL_PER_SEC。超额静默丢、首超回一次 rate_limited。
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


## 经济操作门（2026-07-17 审计修复）：本回合已提交动作 = 经济状态冻结。
## 否则提交后的抽卡/补充/升级会改变真局 → _commit_and_resolve 重放缓存动作时预检结论失效
## （能量已花/道具已换 → use_slot/apply_choice 失败 → 状态部分应用）。
func _econ_gate(player: int) -> bool:
	if phase != Phase.SELECT:
		_send.call(player, NetProtocol.msg_error("bad_phase"))
		return false
	if _pending[player] != null:
		_send.call(player, NetProtocol.msg_error("already_submitted"))
		return false
	return true


## 付能补充空槽（start_refill 内部扣能+置 OPENED+缓存 3 选 1）→ 选项私发本人 + 双方视图刷新（扣能公开）。
func _on_econ_refill(player: int, slot: int) -> void:
	if not _econ_gate(player):
		return
	if not battle.can_refill(player, slot):
		_send.call(player, NetProtocol.msg_error("draft_unavailable"))
		return
	var options: Array = battle.start_refill(player, slot)
	if options.is_empty():
		_send.call(player, NetProtocol.msg_error("draft_unavailable"))
		return
	var ids: Array = []
	for it in options:
		ids.append((it as ItemData).item_id)
	_send.call(player, {v = NetProtocol.PROTO_VERSION, kind = "draft_offer",
		slot = slot, upgrade = false, options = ids})
	for p in 2:
		_send.call(p, _msg_view(p))


func _on_econ_draft(player: int, slot: int, upgrade: bool) -> void:
	if not _econ_gate(player):
		return
	# 权威门：begin_* 本身不校验槽状态（本地 UI 先查再调）——服务端必须先把门，
	# 否则恶意客户端可对未解锁槽强刷 rng / 提前窥探卡池（本用例测试抓出的真漏洞）。
	if (upgrade and not battle.can_upgrade(player, slot)) \
			or (not upgrade and not battle.can_draw_slot(player, slot)):
		_send.call(player, NetProtocol.msg_error("draft_unavailable"))
		return
	var options: Array = battle.begin_upgrade_draft(player, slot) if upgrade else battle.begin_draft(player, slot)
	if options.is_empty():
		_send.call(player, NetProtocol.msg_error("draft_unavailable"))
		return
	var ids: Array = []
	for it in options:
		ids.append((it as ItemData).item_id)
	# 私有信息：3 选 1 选项只发本人（对手只该看到结果）
	_send.call(player, {v = NetProtocol.PROTO_VERSION, kind = "draft_offer",
		slot = slot, upgrade = upgrade, options = ids})


func _on_econ_pick(player: int, d: Dictionary) -> void:
	if not _econ_gate(player):
		return
	var slot := int(d["slot"])
	var ok: bool = battle.pick_upgrade(player, slot, int(d["choice"])) if bool(d["upgrade"]) \
		else battle.pick_draft(player, slot, int(d["choice"]))
	if not ok:
		_send.call(player, NetProtocol.msg_error("pick_rejected"))
		return
	for p in 2:   # 槽位内容/能量变化=公开信息（明牌博弈）→ 双方刷新视图
		_send.call(p, _msg_view(p))


func _on_death_switch(player: int, slot: int) -> void:
	if phase != Phase.DEATH_SWITCH or not battle.pending_death_switch[player]:
		_send.call(player, NetProtocol.msg_error("bad_phase"))
		return
	if not battle.execute_death_switch(player, slot):
		_send.call(player, NetProtocol.msg_error("illegal_switch"))
		return
	for p in 2:
		_send.call(p, _msg_view(p))
	if not battle.pending_death_switch[0] and not battle.pending_death_switch[1]:
		_begin_turn()


func _msg_view(viewer: int) -> Dictionary:
	return {v = NetProtocol.PROTO_VERSION, kind = "view", view = _view(), snap = _snap_for(viewer)}


## 按接收者过滤的权威快照（2026-07-17 审计修复·ADR-004「视图过滤」首段落地）：
## 对方槽位的 draft/upg_draft 候选清空——3 选 1 候选=私有信息，全量快照广播等于
## 把"只发本人"的 draft_offer 从后门泄漏（改包客户端可偷看）；对方 info_distortion 同剥
## （预留机制·同属私有面）。自己侧原样 → 本端 UI/断线重连镜像零影响。
func _snap_for(viewer: int) -> Dictionary:
	var s: Dictionary = battle.to_snapshot()
	var opp: int = 1 - viewer
	for sl in (s["slots"] as Array)[opp]:
		(sl as Dictionary)["draft"] = []
		(sl as Dictionary)["upg_draft"] = []
	(s["info_distortion"] as Array)[opp] = {}
	return s


## 公开视图（MVP=全量公开·本作明牌博弈）。信息扭曲道具（幻影/迷雾）的按视角过滤=ADR-004 M3。
func _view() -> Dictionary:
	return {
		turn = battle.turn_number,
		hp = battle.hp.duplicate(true),
		max_hp = battle.max_hp.duplicate(true),
		shield = battle.shield.duplicate(true),
		energy = battle.energy.duplicate(),
		active_index = battle.active_index.duplicate(),
		pending_death_switch = battle.pending_death_switch.duplicate(),
		game_over = battle.game_over,
		winner = battle.winner,
		slots = [_pack_slots(0), _pack_slots(1)],
	}


func _pack_team(p: int) -> Array:
	var out: Array = []
	for h in battle.heroes[p]:
		var hd: HeroData = h
		out.append({id = hd.hero_id, name = hd.hero_name, max_hp = hd.max_hp})
	return out


func _pack_slots(p: int) -> Array:
	var out: Array = []
	for sl in battle.slots[p]:
		var it: ItemData = sl["item"]
		out.append({state = int(sl["state"]), item = ("" if it == null else it.item_id),
			since = int(sl["since"]), used = bool(sl["used"])})
	return out
