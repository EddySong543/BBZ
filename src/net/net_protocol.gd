extends RefCounted

## 联机协议（联机线批A·2026-07-12·ADR-004）：消息构造 + 入包校验。纯逻辑零依赖（GUT 可测）。
## 规则（.claude/rules/network-code.md）：所有消息版本化；入包校验字段存在性/类型/范围；
## 服务器绝不信任客户端——本文件的 validate_c2s 是服务端第一道门（业务合法性在 match_room 二道门）。
##
## C2S（客户端→服务器）kind：
##   submit_turn  {v, kind, turn, action:int, target:int, item_slots:Array[int], item_slot_targets:Array[int],
##                 item_slot_choices:Array[int],
##                 double:bool(保留字段·须为false),
##                 empowered_wave:bool, split_big_wave:bool, blood_payment:bool,
##                 free_switches:Array[int], blood_payment_step:int, energy_cap_discount:bool,
##                 second_action:int, second_target:int}
##   econ_draft   {v, kind, turn, slot}            → 服务器回 draft_offer（仅发本人）
##   econ_upgrade {v, kind, turn, slot}            → 服务器回 draft_offer(upgrade)（仅发本人）
##   econ_refill  {v, kind, turn, slot}            → 付能补充（start_refill）→ draft_offer（仅发本人）
##   econ_pick    {v, kind, turn, slot, choice, upgrade:bool}
##   item_draft   {v, kind, turn, slot, target}     → 点金石传说道具 3 选 1（仅私发本人）
##   death_switch {v, kind, turn, slot}
##   resync       {v, kind}                        → 服务器回 snapshot（断线重连）
##   hello        {v, kind, team:[hero_id×3]|[], pass?, gv?} → 开局前=报到+交换阵容；开局后=重连（房间回 snapshot+turn_begin）
##                pass=房间口令（可选·好友房准入·2026-07-14）·gv=游戏版本（版本握手）·门在 net_session.poll_prestart
##                **空 team=BP 流程报到（2026-07-17 BP 联机化）**：阵容不在大厅定·由 BP 阶段决出
##   bp_progress  {v, kind, n:0..3}                → BP 期：我方已亮张数（服务器转发对方=盖牌演出真信号·不带内容）
##   bp_confirm   {v, kind, picks:[hero_id×3]}     → BP 期：最终盲选提交（bp_room 二道门校验）
## S2C（服务器→客户端）kind：
##   match_start / turn_begin / draft_offer / resolve / view / game_over / snapshot / error
##   （match_start/turn_begin/resolve/view 均带 snap=权威全量快照 → 客户端镜像同步·M1）
##   bp_start {you, pool} / bp_progress {n=对方张数} / bp_reveal {picks:[双方×3]·绝对视角}（BP 阶段·2026-07-17）

const PROTO_VERSION := 1
const C2S_KINDS: Array[String] = ["submit_turn", "econ_draft", "econ_upgrade", "econ_refill", "econ_pick", "item_draft", "death_switch", "resync", "hello", "bp_progress", "bp_confirm"]
const TEAM_SIZE := 3
const MAX_HERO_ID_LEN := 8
const MAX_PASS_LEN := 16       # 房间口令上限（好友房准入·2026-07-14）
const MAX_GV_LEN := 16         # 版本串上限（版本握手）
const MAX_RTK_LEN := 64        # 重连令牌上限（中局重连身份凭据·2026-07-17 审计修复）

const MAX_ITEM_SLOTS := 3      # 与 BattleCore.SLOT_COUNT 一致（入包范围校验用·防超长数组）
const MAX_ACTION := 16         # 动作枚举安全上限（真合法性由 match_room 按 legal_actions 判）
const MAX_TEAM_SLOT := 2       # 槽位 0..2
const MAX_FREE_SWITCHES := 1   # h07 每回合最多一次免费切换；协议入口同步收紧


## 校验客户端入包。返回 ""=通过，否则错误码（服务器直接回 error 不进业务层）。
static func validate_c2s(msg: Variant) -> String:
	if not (msg is Dictionary):
		return "bad_payload"
	var d: Dictionary = msg
	# 版本门先验类型（2026-07-17 终审修复）：旧写法 int(d.get("v")) 有两病——
	# ① v 是 Array/Dictionary 时 int() 直接运行时脚本错误（10 万畸形包实测 3.5 万次报错=
	#    12.7MB 日志放大·预连接阶段可达）；② int() 宽松转换让 v="1"/true/1.9 全部过门。
	# 只接受 int 或值为整数的 float（JSON 数字线上形态）——_is_int 收口。
	if not _is_int(d.get("v")) or int(d["v"]) != PROTO_VERSION:
		return "version_mismatch"
	var kind: String = String(d.get("kind", ""))
	if not C2S_KINDS.has(kind):
		return "unknown_kind"
	if kind == "resync":
		var rr: Variant = d.get("rtk", "")
		if not (rr is String) or (rr as String).length() > MAX_RTK_LEN:
			return "bad_rtk_field"
		return ""
	if kind == "hello":
		# 空 team=BP 流程报到（阵容由 BP 阶段决出）；非空必须 3 个合法且不重复的 id
		# （队内去重=2026-07-17 审计修复：旧 LAN 直开局路径可被恶意客户端塞同队重复英雄）。
		var team: Variant = d.get("team")
		if not (team is Array) or ((team as Array).size() != TEAM_SIZE and not (team as Array).is_empty()):
			return "bad_team"
		if not _ids_ok(team):
			return "bad_team"
		var seen := {}
		for id in team:
			if seen.has(id):
				return "bad_team"
			seen[id] = true
		var pass_v: Variant = d.get("pass", "")   # 可选字段：缺省=空串（旧包兼容）·带则限型限长
		if not (pass_v is String) or (pass_v as String).length() > MAX_PASS_LEN:
			return "bad_pass_field"
		var gv_v: Variant = d.get("gv", "")
		if not (gv_v is String) or (gv_v as String).length() > MAX_GV_LEN:
			return "bad_gv_field"
		var rtk_v: Variant = d.get("rtk", "")   # 重连令牌（可选·开局后重连报到必带·2026-07-17）
		if not (rtk_v is String) or (rtk_v as String).length() > MAX_RTK_LEN:
			return "bad_rtk_field"
		return ""
	if kind == "bp_progress":
		if not _is_int(d.get("n")) or int(d["n"]) < 0 or int(d["n"]) > TEAM_SIZE:
			return "bad_n"
		return ""
	if kind == "bp_confirm":
		var picks: Variant = d.get("picks")
		if not (picks is Array) or (picks as Array).size() != TEAM_SIZE or not _ids_ok(picks):
			return "bad_picks"
		return ""
	if not _is_int(d.get("turn")) or int(d["turn"]) < 0:
		return "bad_turn"
	match kind:
		"submit_turn":
			if not _is_int(d.get("action")) or int(d["action"]) < 0 \
					or (int(d["action"]) > MAX_ACTION and int(d["action"]) != ActionDef.ACTIVE):
				return "bad_action"
			if not _is_int(d.get("target")) or int(d["target"]) < -1 or int(d["target"]) > MAX_TEAM_SLOT:
				return "bad_target"
			var second_action: Variant = d.get("second_action", -1)
			if not _is_int(second_action) or int(second_action) < -1 \
					or int(second_action) > ActionDef.Action.BIG_DEFEND:
				return "bad_second_action"
			var second_target: Variant = d.get("second_target", -1)
			if not _is_int(second_target) or int(second_target) < -1 \
					or int(second_target) > MAX_TEAM_SLOT:
				return "bad_second_target"
			if int(second_action) < 0 and int(second_target) >= 0:
				return "bad_second_target"
			var slots: Variant = d.get("item_slots")
			if not (slots is Array) or (slots as Array).size() > MAX_ITEM_SLOTS:
				return "bad_item_slots"
			for s in slots:
				if not _is_int(s) or int(s) < 0 or int(s) > MAX_ITEM_SLOTS - 1:
					return "bad_item_slots"
			# 与 item_slots 逐位对应：-1=道具默认目标，0..2=道具槽目标（当前供随身熔炉选燃料）。
			# 旧客户端没有该字段时等价于全 -1；显式携带时必须严格等长，防索引错配。
			var item_slot_targets: Array = []
			if d.has("item_slot_targets"):
				var targets_v: Variant = d["item_slot_targets"]
				if not (targets_v is Array):
					return "bad_item_slot_targets"
				item_slot_targets = targets_v
				if item_slot_targets.size() != (slots as Array).size():
					return "bad_item_slot_targets"
			else:
				item_slot_targets.resize((slots as Array).size())
				item_slot_targets.fill(-1)
			for item_target in item_slot_targets:
				if not _is_int(item_target) or int(item_target) < -1 or int(item_target) > MAX_TEAM_SLOT:
					return "bad_item_slot_targets"
			# 与 item_slots 逐位对应；-1=该道具无需选择，0..2=点金石私有候选下标。
			var item_slot_choices: Array = []
			if d.has("item_slot_choices"):
				var choices_v: Variant = d["item_slot_choices"]
				if not (choices_v is Array):
					return "bad_item_slot_choices"
				item_slot_choices = choices_v
				if item_slot_choices.size() != (slots as Array).size():
					return "bad_item_slot_choices"
			else:
				item_slot_choices.resize((slots as Array).size())
				item_slot_choices.fill(-1)
			for item_choice in item_slot_choices:
				if not _is_int(item_choice) or int(item_choice) < -1 or int(item_choice) > 2:
					return "bad_item_slot_choices"
			if not (d.get("double", false) is bool):
				return "bad_double_flag"
			if not (d.get("empowered_wave", false) is bool):
				return "bad_empowered_wave_flag"
			if not (d.get("split_big_wave", false) is bool):
				return "bad_split_big_wave_flag"
			if not (d.get("blood_payment", false) is bool):
				return "bad_blood_payment_flag"
			if not (d.get("energy_cap_discount", false) is bool):
				return "bad_energy_cap_discount_flag"
			var free_switches: Variant = d.get("free_switches", [])
			if not (free_switches is Array) or (free_switches as Array).size() > MAX_FREE_SWITCHES:
				return "bad_free_switches"
			for target in free_switches:
				if not _is_int(target) or int(target) < 0 or int(target) > MAX_TEAM_SLOT:
					return "bad_free_switches"
			var blood_step: Variant = d.get("blood_payment_step", -1)
			if not _is_int(blood_step) or int(blood_step) < -1 \
					or int(blood_step) > (free_switches as Array).size():
				return "bad_blood_payment_step"
			if not bool(d.get("blood_payment", false)) and int(blood_step) != -1:
				return "bad_blood_payment_step"
		"econ_draft", "econ_upgrade", "econ_refill":
			if not _slot_ok(d):
				return "bad_slot"
		"item_draft":
			if not _slot_ok(d):
				return "bad_slot"
			if not _is_int(d.get("target")) or int(d["target"]) < 0 \
					or int(d["target"]) > MAX_TEAM_SLOT or int(d["target"]) == int(d["slot"]):
				return "bad_item_target"
		"econ_pick":
			if not _slot_ok(d):
				return "bad_slot"
			if not _is_int(d.get("choice")) or int(d["choice"]) < 0 or int(d["choice"]) > 2:
				return "bad_choice"
			if not (d.get("upgrade") is bool):
				return "bad_upgrade_flag"
		"death_switch":
			if not _is_int(d.get("slot")) or int(d["slot"]) < 0 or int(d["slot"]) > MAX_TEAM_SLOT:
				return "bad_slot"
	return ""


static func _slot_ok(d: Dictionary) -> bool:
	return _is_int(d.get("slot")) and int(d["slot"]) >= 0 and int(d["slot"]) <= MAX_ITEM_SLOTS - 1


## 英雄 id 数组形状校验（hello team / bp_confirm picks 共用）：每个都是合法标识符且限长。
static func _ids_ok(arr: Variant) -> bool:
	for id in arr:
		if not (id is String) or (id as String).is_empty() or (id as String).length() > MAX_HERO_ID_LEN \
				or not (id as String).is_valid_identifier():
			return false
	return true


## JSON 往返后 int 会变 float —— 整数判定两者都收。
static func _is_int(v: Variant) -> bool:
	return v is int or (v is float and is_equal_approx(v, roundf(v)))


# —— C2S 构造（客户端用·保证自家包永远过校验）——

static func msg_submit_turn(turn: int, action: int, target: int, item_slots: Array,
		double: bool = false, empowered_wave: bool = false, split_big_wave: bool = false,
		blood_payment: bool = false, free_switches: Array = [],
		blood_payment_step: int = -1, energy_cap_discount: bool = false,
		item_slot_targets: Array = [], item_slot_choices: Array = [],
		second_action: int = -1, second_target: int = -1) -> Dictionary:
	var normalized_item_targets: Array = item_slot_targets.duplicate()
	if normalized_item_targets.is_empty() and not item_slots.is_empty():
		normalized_item_targets.resize(item_slots.size())
		normalized_item_targets.fill(-1)
	var normalized_item_choices: Array = item_slot_choices.duplicate()
	if normalized_item_choices.is_empty() and not item_slots.is_empty():
		normalized_item_choices.resize(item_slots.size())
		normalized_item_choices.fill(-1)
	return {v = PROTO_VERSION, kind = "submit_turn", turn = turn, action = action, target = target,
		item_slots = item_slots.duplicate(), item_slot_targets = normalized_item_targets,
		item_slot_choices = normalized_item_choices,
		double = double, empowered_wave = empowered_wave,
		split_big_wave = split_big_wave, blood_payment = blood_payment,
		free_switches = free_switches.duplicate(), blood_payment_step = blood_payment_step,
		energy_cap_discount = energy_cap_discount, second_action = second_action,
		second_target = second_target}


static func msg_item_draft(turn: int, slot: int, target: int) -> Dictionary:
	return {v = PROTO_VERSION, kind = "item_draft", turn = turn, slot = slot, target = target}


static func msg_econ_draft(turn: int, slot: int, upgrade: bool) -> Dictionary:
	return {v = PROTO_VERSION, kind = ("econ_upgrade" if upgrade else "econ_draft"), turn = turn, slot = slot}


static func msg_econ_refill(turn: int, slot: int) -> Dictionary:
	return {v = PROTO_VERSION, kind = "econ_refill", turn = turn, slot = slot}


static func msg_econ_pick(turn: int, slot: int, choice: int, upgrade: bool) -> Dictionary:
	return {v = PROTO_VERSION, kind = "econ_pick", turn = turn, slot = slot, choice = choice, upgrade = upgrade}


static func msg_death_switch(turn: int, slot: int) -> Dictionary:
	return {v = PROTO_VERSION, kind = "death_switch", turn = turn, slot = slot}


## rtk=重连令牌（开局后向房间要快照必带·2026-07-17 身份门）。
static func msg_resync(rtk: String = "") -> Dictionary:
	return {"v": PROTO_VERSION, "kind": "resync", "rtk": rtk.substr(0, MAX_RTK_LEN)}


## room_pass=房间口令（空=公开房）·gv=游戏版本（版本握手·默认取本机）·rtk=重连令牌
## （开局后重连报到必带·match_start 下发·空=首次报到）。⚠ "pass" 是 GDScript 关键字，
## 参数/键名分别用 room_pass / 字符串键 "pass"。
static func msg_hello(team: Array, room_pass: String = "", gv: String = "", rtk: String = "") -> Dictionary:
	return {"v": PROTO_VERSION, "kind": "hello", "team": team.duplicate(),
		"pass": room_pass.substr(0, MAX_PASS_LEN), "gv": (game_version() if gv.is_empty() else gv),
		"rtk": rtk.substr(0, MAX_RTK_LEN)}


## 本机游戏版本（版本握手用·真相源=project.godot application/config/version）。
static func game_version() -> String:
	return String(ProjectSettings.get_setting("application/config/version", "0"))


# —— BP 阶段 C2S（2026-07-17 BP 联机化逻辑层）——

static func msg_bp_progress(n: int) -> Dictionary:
	return {v = PROTO_VERSION, kind = "bp_progress", n = clampi(n, 0, TEAM_SIZE)}


static func msg_bp_confirm(picks: Array) -> Dictionary:
	return {v = PROTO_VERSION, kind = "bp_confirm", picks = picks.duplicate()}


# —— S2C 构造（服务器用）——

## detail=附加信息（可选·如 bad_version 附房主版本号·客户端展示为 code:detail）。
static func msg_error(code: String, detail: String = "") -> Dictionary:
	if detail.is_empty():
		return {v = PROTO_VERSION, kind = "error", code = code}
	return {v = PROTO_VERSION, kind = "error", code = code, detail = detail}


static func msg_game_over(winner: int) -> Dictionary:
	return {v = PROTO_VERSION, kind = "game_over", winner = winner}
