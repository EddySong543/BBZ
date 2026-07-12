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
##   - 断线重连：resync → 全量快照（to_snapshot）。⚠ MVP 快照含双方 draft 选项（私有信息
##     过滤=ADR-004 M3·信息扭曲道具的视角过滤同批）。
##   - 平局=直接结案（线上加时赛=后续立项·同故事模式先例）。回合计时=M3（服务端计时）。
##
## 用法（测试/未来 match_host 同款）：
##   var room := MatchRoom.new()   # preload 引用
##   room.start(team0, team1, seed, func(p, msg): transport[p].send(msg))
##   room.handle(0, msg_from_client0)   # 传输层收到包 → 喂这里

const NetProtocol := preload("res://src/net/net_protocol.gd")

enum Phase { SELECT, DEATH_SWITCH, OVER }

var battle: BattleCore
var phase: int = Phase.SELECT
var _send: Callable                    # (player:int, msg:Dictionary) -> void
var _pending: Array = [null, null]     # 本回合已收提交（先到先锁·拒绝重复提交）


func start(team0: Array, team1: Array, seed_v: int, send_cb: Callable) -> void:
	_send = send_cb
	battle = BattleCore.new()
	battle.setup(team0, team1, seed_v)
	battle.econ_init()
	phase = Phase.SELECT
	_pending = [null, null]
	for p in 2:
		_send.call(p, {v = NetProtocol.PROTO_VERSION, kind = "match_start", you = p,
			heroes = [_pack_team(0), _pack_team(1)], turn = battle.turn_number, view = _view()})


## 传输层入口：一切客户端包从这进。协议校验（一道门）→ 回合号校验 → 业务校验（二道门）。
func handle(player: int, msg: Variant) -> void:
	var err := NetProtocol.validate_c2s(msg)
	if err != "":
		_send.call(player, NetProtocol.msg_error(err))
		return
	var d: Dictionary = msg
	var kind := String(d["kind"])
	if kind == "resync":
		_send.call(player, {v = NetProtocol.PROTO_VERSION, kind = "snapshot", you = player,
			phase = phase, snap = battle.to_snapshot()})
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
	return core.apply_choice(player, {action = want_action, target = want_target})


func _commit_and_resolve() -> void:
	for p in 2:
		_apply_payload(battle, p, _pending[p])   # 预检已过·此处必成（固定 p0→p1 序=确定性）
	var r: Dictionary = battle.resolve()
	var pending := battle.pending_death_switch.duplicate()
	if battle.game_over:
		phase = Phase.OVER
	elif bool(pending[0]) or bool(pending[1]):
		phase = Phase.DEATH_SWITCH
	for p in 2:
		_send.call(p, {v = NetProtocol.PROTO_VERSION, kind = "resolve",
			actions = [r.get("p1_action", -1), r.get("p2_action", -1)],
			events = r.get("events", []), pending = pending, view = _view()})
	if phase == Phase.OVER:
		for p in 2:
			_send.call(p, NetProtocol.msg_game_over(battle.winner))
	elif phase == Phase.SELECT:
		_begin_turn()


func _begin_turn() -> void:
	phase = Phase.SELECT
	_pending = [null, null]
	for p in 2:
		_send.call(p, {v = NetProtocol.PROTO_VERSION, kind = "turn_begin",
			turn = battle.turn_number, view = _view()})


func _on_econ_draft(player: int, slot: int, upgrade: bool) -> void:
	if phase != Phase.SELECT:
		_send.call(player, NetProtocol.msg_error("bad_phase"))
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
	if phase != Phase.SELECT:
		_send.call(player, NetProtocol.msg_error("bad_phase"))
		return
	var slot := int(d["slot"])
	var ok: bool = battle.pick_upgrade(player, slot, int(d["choice"])) if bool(d["upgrade"]) \
		else battle.pick_draft(player, slot, int(d["choice"]))
	if not ok:
		_send.call(player, NetProtocol.msg_error("pick_rejected"))
		return
	for p in 2:   # 槽位内容/能量变化=公开信息（明牌博弈）→ 双方刷新视图
		_send.call(p, {v = NetProtocol.PROTO_VERSION, kind = "view", view = _view()})


func _on_death_switch(player: int, slot: int) -> void:
	if phase != Phase.DEATH_SWITCH or not battle.pending_death_switch[player]:
		_send.call(player, NetProtocol.msg_error("bad_phase"))
		return
	if not battle.execute_death_switch(player, slot):
		_send.call(player, NetProtocol.msg_error("illegal_switch"))
		return
	for p in 2:
		_send.call(p, {v = NetProtocol.PROTO_VERSION, kind = "view", view = _view()})
	if not battle.pending_death_switch[0] and not battle.pending_death_switch[1]:
		_begin_turn()


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
