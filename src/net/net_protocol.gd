extends RefCounted

## 联机协议（联机线批A·2026-07-12·ADR-004）：消息构造 + 入包校验。纯逻辑零依赖（GUT 可测）。
## 规则（.claude/rules/network-code.md）：所有消息版本化；入包校验字段存在性/类型/范围；
## 服务器绝不信任客户端——本文件的 validate_c2s 是服务端第一道门（业务合法性在 match_room 二道门）。
##
## C2S（客户端→服务器）kind：
##   submit_turn  {v, kind, turn, action:int, target:int, item_slots:Array[int], double:bool}
##   econ_draft   {v, kind, turn, slot}            → 服务器回 draft_offer（仅发本人）
##   econ_upgrade {v, kind, turn, slot}            → 服务器回 draft_offer(upgrade)（仅发本人）
##   econ_refill  {v, kind, turn, slot}            → 付能补充（start_refill）→ draft_offer（仅发本人）
##   econ_pick    {v, kind, turn, slot, choice, upgrade:bool}
##   death_switch {v, kind, turn, slot}
##   resync       {v, kind}                        → 服务器回 snapshot（断线重连）
##   hello        {v, kind, team:[hero_id×3], pass?, gv?} → 开局前=报到+交换阵容；开局后=重连（房间回 snapshot+turn_begin）
##                pass=房间口令（可选·好友房准入·2026-07-14）·gv=游戏版本（版本握手）·门在 net_session.poll_prestart
## S2C（服务器→客户端）kind：
##   match_start / turn_begin / draft_offer / resolve / view / game_over / snapshot / error
##   （match_start/turn_begin/resolve/view 均带 snap=权威全量快照 → 客户端镜像同步·M1）

const PROTO_VERSION := 1
const C2S_KINDS: Array[String] = ["submit_turn", "econ_draft", "econ_upgrade", "econ_refill", "econ_pick", "death_switch", "resync", "hello"]
const TEAM_SIZE := 3
const MAX_HERO_ID_LEN := 8
const MAX_PASS_LEN := 16       # 房间口令上限（好友房准入·2026-07-14）
const MAX_GV_LEN := 16         # 版本串上限（版本握手）

const MAX_ITEM_SLOTS := 3      # 与 BattleCore.SLOT_COUNT 一致（入包范围校验用·防超长数组）
const MAX_ACTION := 16         # 动作枚举安全上限（真合法性由 match_room 按 legal_actions 判）
const MAX_TEAM_SLOT := 2       # 槽位 0..2


## 校验客户端入包。返回 ""=通过，否则错误码（服务器直接回 error 不进业务层）。
static func validate_c2s(msg: Variant) -> String:
	if not (msg is Dictionary):
		return "bad_payload"
	var d: Dictionary = msg
	if int(d.get("v", -1)) != PROTO_VERSION:
		return "version_mismatch"
	var kind: String = String(d.get("kind", ""))
	if not C2S_KINDS.has(kind):
		return "unknown_kind"
	if kind == "resync":
		return ""
	if kind == "hello":
		var team: Variant = d.get("team")
		if not (team is Array) or (team as Array).size() != TEAM_SIZE:
			return "bad_team"
		for id in team:
			if not (id is String) or (id as String).is_empty() or (id as String).length() > MAX_HERO_ID_LEN \
					or not (id as String).is_valid_identifier():
				return "bad_team"
		var pass_v: Variant = d.get("pass", "")   # 可选字段：缺省=空串（旧包兼容）·带则限型限长
		if not (pass_v is String) or (pass_v as String).length() > MAX_PASS_LEN:
			return "bad_pass_field"
		var gv_v: Variant = d.get("gv", "")
		if not (gv_v is String) or (gv_v as String).length() > MAX_GV_LEN:
			return "bad_gv_field"
		return ""
	if not _is_int(d.get("turn")) or int(d["turn"]) < 0:
		return "bad_turn"
	match kind:
		"submit_turn":
			if not _is_int(d.get("action")) or int(d["action"]) < 0 or int(d["action"]) > MAX_ACTION:
				return "bad_action"
			if not _is_int(d.get("target")) or int(d["target"]) < -1 or int(d["target"]) > MAX_TEAM_SLOT:
				return "bad_target"
			var slots: Variant = d.get("item_slots")
			if not (slots is Array) or (slots as Array).size() > MAX_ITEM_SLOTS:
				return "bad_item_slots"
			for s in slots:
				if not _is_int(s) or int(s) < 0 or int(s) > MAX_ITEM_SLOTS - 1:
					return "bad_item_slots"
			if not (d.get("double", false) is bool):
				return "bad_double_flag"
		"econ_draft", "econ_upgrade", "econ_refill":
			if not _slot_ok(d):
				return "bad_slot"
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


## JSON 往返后 int 会变 float —— 整数判定两者都收。
static func _is_int(v: Variant) -> bool:
	return v is int or (v is float and is_equal_approx(v, roundf(v)))


# —— C2S 构造（客户端用·保证自家包永远过校验）——

static func msg_submit_turn(turn: int, action: int, target: int, item_slots: Array, double: bool = false) -> Dictionary:
	return {v = PROTO_VERSION, kind = "submit_turn", turn = turn, action = action, target = target,
		item_slots = item_slots.duplicate(), double = double}


static func msg_econ_draft(turn: int, slot: int, upgrade: bool) -> Dictionary:
	return {v = PROTO_VERSION, kind = ("econ_upgrade" if upgrade else "econ_draft"), turn = turn, slot = slot}


static func msg_econ_refill(turn: int, slot: int) -> Dictionary:
	return {v = PROTO_VERSION, kind = "econ_refill", turn = turn, slot = slot}


static func msg_econ_pick(turn: int, slot: int, choice: int, upgrade: bool) -> Dictionary:
	return {v = PROTO_VERSION, kind = "econ_pick", turn = turn, slot = slot, choice = choice, upgrade = upgrade}


static func msg_death_switch(turn: int, slot: int) -> Dictionary:
	return {v = PROTO_VERSION, kind = "death_switch", turn = turn, slot = slot}


static func msg_resync() -> Dictionary:
	return {v = PROTO_VERSION, kind = "resync"}


## room_pass=房间口令（空=公开房）·gv=游戏版本（版本握手·默认取本机）。⚠ "pass" 是 GDScript 关键字，
## 参数/键名分别用 room_pass / 字符串键 "pass"。
static func msg_hello(team: Array, room_pass: String = "", gv: String = "") -> Dictionary:
	return {"v": PROTO_VERSION, "kind": "hello", "team": team.duplicate(),
		"pass": room_pass.substr(0, MAX_PASS_LEN), "gv": (game_version() if gv.is_empty() else gv)}


## 本机游戏版本（版本握手用·真相源=project.godot application/config/version）。
static func game_version() -> String:
	return String(ProjectSettings.get_setting("application/config/version", "0"))


# —— S2C 构造（服务器用）——

## detail=附加信息（可选·如 bad_version 附房主版本号·客户端展示为 code:detail）。
static func msg_error(code: String, detail: String = "") -> Dictionary:
	if detail.is_empty():
		return {v = PROTO_VERSION, kind = "error", code = code}
	return {v = PROTO_VERSION, kind = "error", code = code, detail = detail}


static func msg_game_over(winner: int) -> Dictionary:
	return {v = PROTO_VERSION, kind = "game_over", winner = winner}
