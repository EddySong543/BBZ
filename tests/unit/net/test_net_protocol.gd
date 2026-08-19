extends GutTest

## 联机协议入包校验 行为锁定测试（联机线批A·2026-07-12）。
## 锁：版本化拒绝/未知类型拒绝/字段范围校验/JSON 降级（int→float）兼容/自产消息必过自家校验。

const NetProtocol := preload("res://src/net/net_protocol.gd")


func test_net_protocol_own_messages_pass_validation() -> void:
	# Arrange + Act + Assert：构造器产的每种消息都过校验
	var submit: Dictionary = NetProtocol.msg_submit_turn(0, 1, -1, [0, 2])
	assert_eq(submit["item_slot_choices"], [-1, -1])
	assert_eq(submit["item_slot_targets"], [-1, -1], "缺省目标应与 item_slots 等长并全部归一为 -1")
	assert_eq(int(submit["second_action"]), -1)
	assert_eq(int(submit["second_target"]), -1)
	assert_eq(NetProtocol.validate_c2s(submit), "")
	assert_eq(NetProtocol.validate_c2s(NetProtocol.msg_item_draft(0, 0, 2)), "")
	assert_eq(NetProtocol.validate_c2s(NetProtocol.msg_econ_draft(3, 1, false)), "")
	assert_eq(NetProtocol.validate_c2s(NetProtocol.msg_econ_draft(3, 1, true)), "")
	assert_eq(NetProtocol.validate_c2s(NetProtocol.msg_econ_pick(3, 1, 2, false)), "")
	assert_eq(NetProtocol.validate_c2s(NetProtocol.msg_death_switch(5, 2)), "")
	assert_eq(NetProtocol.validate_c2s(NetProtocol.msg_resync()), "")


func test_net_protocol_version_mismatch_rejected() -> void:
	var bad := NetProtocol.msg_resync()
	bad["v"] = 999
	assert_eq(NetProtocol.validate_c2s(bad), "version_mismatch")


func test_net_protocol_unknown_kind_and_payload_rejected() -> void:
	assert_eq(NetProtocol.validate_c2s({v = NetProtocol.PROTO_VERSION, kind = "hack"}), "unknown_kind")
	assert_eq(NetProtocol.validate_c2s("not a dict"), "bad_payload")
	assert_eq(NetProtocol.validate_c2s(null), "bad_payload")


func test_net_protocol_field_ranges_rejected() -> void:
	# 动作/目标/道具槽/选择号 越界全拒（入包范围校验规则）
	assert_eq(NetProtocol.validate_c2s(NetProtocol.msg_submit_turn(0, 99, -1, [])), "bad_action")
	assert_eq(NetProtocol.validate_c2s(NetProtocol.msg_submit_turn(0, 1, 9, [])), "bad_target")
	assert_eq(NetProtocol.validate_c2s(NetProtocol.msg_submit_turn(0, 1, -1, [0, 1, 2, 0])), "bad_item_slots")
	assert_eq(NetProtocol.validate_c2s(NetProtocol.msg_submit_turn(0, 1, -1, [7])), "bad_item_slots")
	assert_eq(NetProtocol.validate_c2s(NetProtocol.msg_submit_turn(-1, 1, -1, [])), "bad_turn")
	assert_eq(NetProtocol.validate_c2s(NetProtocol.msg_econ_pick(0, 1, 3, false)), "bad_choice")
	var no_flag := NetProtocol.msg_econ_pick(0, 1, 1, false)
	no_flag.erase("upgrade")
	assert_eq(NetProtocol.validate_c2s(no_flag), "bad_upgrade_flag")
	var bad_empowered := NetProtocol.msg_submit_turn(0, 1, -1, [])
	bad_empowered["empowered_wave"] = 1
	assert_eq(NetProtocol.validate_c2s(bad_empowered), "bad_empowered_wave_flag")
	var bad_split := NetProtocol.msg_submit_turn(0, 3, -1, [])
	bad_split["split_big_wave"] = 1
	assert_eq(NetProtocol.validate_c2s(bad_split), "bad_split_big_wave_flag")
	var bad_blood := NetProtocol.msg_submit_turn(0, 3, -1, [])
	bad_blood["blood_payment"] = 1
	assert_eq(NetProtocol.validate_c2s(bad_blood), "bad_blood_payment_flag")
	var bad_discount := NetProtocol.msg_submit_turn(0, 3, -1, [])
	bad_discount["energy_cap_discount"] = 1
	assert_eq(NetProtocol.validate_c2s(bad_discount), "bad_energy_cap_discount_flag")
	var bad_second_action := NetProtocol.msg_submit_turn(0, 1, -1, [])
	bad_second_action["second_action"] = ActionDef.ACTIVE
	assert_eq(NetProtocol.validate_c2s(bad_second_action), "bad_second_action")
	var orphan_second_target := NetProtocol.msg_submit_turn(0, 1, -1, [])
	orphan_second_target["second_target"] = 0
	assert_eq(NetProtocol.validate_c2s(orphan_second_target), "bad_second_target")
	var bad_switches := NetProtocol.msg_submit_turn(0, 1, -1, [])
	bad_switches["free_switches"] = [3]
	assert_eq(NetProtocol.validate_c2s(bad_switches), "bad_free_switches")
	var too_many_switches := NetProtocol.msg_submit_turn(0, 1, -1, [])
	too_many_switches["free_switches"] = [1, 2]
	assert_eq(NetProtocol.validate_c2s(too_many_switches), "bad_free_switches")
	var bad_step := NetProtocol.msg_submit_turn(0, 1, -1, [])
	bad_step["blood_payment_step"] = 0
	assert_eq(NetProtocol.validate_c2s(bad_step), "bad_blood_payment_step")
	var bad_item_target_type := NetProtocol.msg_submit_turn(0, 1, -1, [0])
	bad_item_target_type["item_slot_targets"] = true
	assert_eq(NetProtocol.validate_c2s(bad_item_target_type), "bad_item_slot_targets")
	var bad_item_target_length := NetProtocol.msg_submit_turn(0, 1, -1, [0, 1])
	bad_item_target_length["item_slot_targets"] = [-1]
	assert_eq(NetProtocol.validate_c2s(bad_item_target_length), "bad_item_slot_targets")
	for bad_target: Variant in [-2, 3, "1"]:
		var bad_item_target := NetProtocol.msg_submit_turn(0, 1, -1, [0])
		bad_item_target["item_slot_targets"] = [bad_target]
		assert_eq(NetProtocol.validate_c2s(bad_item_target), "bad_item_slot_targets")
	var bad_item_choice_type := NetProtocol.msg_submit_turn(0, 1, -1, [0])
	bad_item_choice_type["item_slot_choices"] = true
	assert_eq(NetProtocol.validate_c2s(bad_item_choice_type), "bad_item_slot_choices")
	var bad_item_choice_length := NetProtocol.msg_submit_turn(0, 1, -1, [0, 1])
	bad_item_choice_length["item_slot_choices"] = [-1]
	assert_eq(NetProtocol.validate_c2s(bad_item_choice_length), "bad_item_slot_choices")
	for bad_choice: Variant in [-2, 3, "1"]:
		var bad_item_choice := NetProtocol.msg_submit_turn(0, 1, -1, [0])
		bad_item_choice["item_slot_choices"] = [bad_choice]
		assert_eq(NetProtocol.validate_c2s(bad_item_choice), "bad_item_slot_choices")
	assert_eq(NetProtocol.validate_c2s(NetProtocol.msg_item_draft(0, 1, 1)), "bad_item_target")


func test_net_protocol_submit_turn_preserves_empowered_wave_flag() -> void:
	var msg: Dictionary = NetProtocol.msg_submit_turn(4, 1, -1, [], false, true)
	assert_true(bool(msg["empowered_wave"]))
	assert_eq(NetProtocol.validate_c2s(msg), "")
	var wire: Variant = JSON.parse_string(JSON.stringify(msg))
	assert_true(bool(wire["empowered_wave"]))
	assert_eq(NetProtocol.validate_c2s(wire), "")


func test_net_protocol_submit_turn_preserves_split_big_wave_flag() -> void:
	var msg: Dictionary = NetProtocol.msg_submit_turn(4, 3, -1, [], false, false, true)
	assert_true(bool(msg["split_big_wave"]))
	assert_eq(NetProtocol.validate_c2s(msg), "")
	var wire: Variant = JSON.parse_string(JSON.stringify(msg))
	assert_true(bool(wire["split_big_wave"]))
	assert_eq(NetProtocol.validate_c2s(wire), "")


func test_net_protocol_submit_turn_preserves_blood_payment_flag() -> void:
	var msg: Dictionary = NetProtocol.msg_submit_turn(4, 3, -1, [], false, false, false, true)
	assert_true(bool(msg["blood_payment"]))
	assert_eq(NetProtocol.validate_c2s(msg), "")
	var wire: Variant = JSON.parse_string(JSON.stringify(msg))
	assert_true(bool(wire["blood_payment"]))
	assert_eq(NetProtocol.validate_c2s(wire), "")


func test_net_protocol_submit_turn_preserves_energy_cap_discount_flag() -> void:
	var msg: Dictionary = NetProtocol.msg_submit_turn(
		4, 3, -1, [], false, false, false, false, [], -1, true)
	assert_true(bool(msg["energy_cap_discount"]))
	assert_eq(NetProtocol.validate_c2s(msg), "")
	var wire: Variant = JSON.parse_string(JSON.stringify(msg))
	assert_true(bool(wire["energy_cap_discount"]))
	assert_eq(NetProtocol.validate_c2s(wire), "")


func test_net_protocol_submit_turn_preserves_single_free_switch_and_blood_step() -> void:
	var msg: Dictionary = NetProtocol.msg_submit_turn(
		4, ActionDef.ACTIVE, -1, [], false, false, false, true, [1], 0)
	assert_eq(msg["free_switches"], [1])
	assert_eq(int(msg["blood_payment_step"]), 0)
	assert_eq(NetProtocol.validate_c2s(msg), "")
	var wire: Variant = JSON.parse_string(JSON.stringify(msg))
	assert_eq(wire["free_switches"], [1.0])
	assert_eq(int(wire["blood_payment_step"]), 0)
	assert_eq(NetProtocol.validate_c2s(wire), "")


func test_net_protocol_submit_turn_preserves_item_targets_choices_and_legacy_omission() -> void:
	var msg: Dictionary = NetProtocol.msg_submit_turn(
		4, 2, -1, [0, 2], false, false, false, false, [], -1, false,
		[2, -1], [1, -1])
	assert_eq(msg["item_slot_targets"], [2, -1])
	assert_eq(msg["item_slot_choices"], [1, -1])
	assert_eq(NetProtocol.validate_c2s(msg), "")
	var wire: Variant = JSON.parse_string(JSON.stringify(msg))
	assert_eq(wire["item_slot_targets"], [2.0, -1.0])
	assert_eq(wire["item_slot_choices"], [1.0, -1.0])
	assert_eq(NetProtocol.validate_c2s(wire), "")

	var legacy: Dictionary = msg.duplicate(true)
	legacy.erase("item_slot_targets")
	legacy.erase("item_slot_choices")
	assert_eq(NetProtocol.validate_c2s(legacy), "", "旧客户端缺省目标字段时应按全 -1 放行")


func test_net_protocol_submit_turn_preserves_lianhuan_second_action() -> void:
	var msg: Dictionary = NetProtocol.msg_submit_turn(
		4, ActionDef.Action.CHARGE, -1, [0], false, false, false, false, [], -1,
		false, [-1], [-1], ActionDef.Action.ATTACK, 2)
	assert_eq(int(msg["second_action"]), ActionDef.Action.ATTACK)
	assert_eq(int(msg["second_target"]), 2)
	assert_eq(NetProtocol.validate_c2s(msg), "")
	var wire: Variant = JSON.parse_string(JSON.stringify(msg))
	assert_eq(int(wire["second_action"]), ActionDef.Action.ATTACK)
	assert_eq(int(wire["second_target"]), 2)
	assert_eq(NetProtocol.validate_c2s(wire), "")


func test_net_protocol_hello_team_validation() -> void:
	# 合法 3 人队过·人数/伪造 id（路径穿越/超长）全拒
	assert_eq(NetProtocol.validate_c2s(NetProtocol.msg_hello(["h01", "h02", "h03"])), "")
	assert_eq(NetProtocol.validate_c2s(NetProtocol.msg_hello(["h01"])), "bad_team")
	assert_eq(NetProtocol.validate_c2s(NetProtocol.msg_hello(["h01", "h02", "../evil"])), "bad_team")
	assert_eq(NetProtocol.validate_c2s(NetProtocol.msg_hello(["h01", "h02", "reallylongheroid"])), "bad_team")


func test_net_protocol_json_wire_degradation_accepted() -> void:
	# JSON 往返 int→float：真实传输路径上的合法包仍须通过
	var wire: Variant = JSON.parse_string(JSON.stringify(NetProtocol.msg_submit_turn(4, 2, -1, [0])))
	assert_eq(NetProtocol.validate_c2s(wire), "")


func test_net_protocol_hello_pass_and_version_fields_validated() -> void:
	# Arrange + Act + Assert（好友开房准备批·2026-07-14）
	# 带口令+版本的 hello 过校验；构造器默认自动带本机版本
	var msg := NetProtocol.msg_hello(["h01", "h02", "h03"], "sesame")
	assert_eq(NetProtocol.validate_c2s(msg), "")
	assert_eq(String(msg["gv"]), NetProtocol.game_version())
	# 旧式无 pass/gv 字段仍过（可选字段·后向兼容）
	var legacy := {v = NetProtocol.PROTO_VERSION, kind = "hello", team = ["h01", "h02", "h03"]}
	assert_eq(NetProtocol.validate_c2s(legacy), "")
	# 超长/非字符串口令拒；非字符串版本拒（⚠ pass 是关键字→整个字面量用字符串键·禁混风格）
	var long_pass := {"v": NetProtocol.PROTO_VERSION, "kind": "hello", "team": ["h01", "h02", "h03"],
		"pass": "x".repeat(NetProtocol.MAX_PASS_LEN + 1)}
	assert_eq(NetProtocol.validate_c2s(long_pass), "bad_pass_field")
	var num_pass := {"v": NetProtocol.PROTO_VERSION, "kind": "hello", "team": ["h01", "h02", "h03"], "pass": 5}
	assert_eq(NetProtocol.validate_c2s(num_pass), "bad_pass_field")
	var bad_gv := {"v": NetProtocol.PROTO_VERSION, "kind": "hello", "team": ["h01", "h02", "h03"], "gv": 1.0}
	assert_eq(NetProtocol.validate_c2s(bad_gv), "bad_gv_field")


func test_net_protocol_error_detail_attached_only_when_given() -> void:
	# Arrange + Act
	var bare := NetProtocol.msg_error("bad_pass")
	var rich := NetProtocol.msg_error("bad_version", "0.1.0")
	# Assert
	assert_false(bare.has("detail"))
	assert_eq(String(rich["detail"]), "0.1.0")


func test_net_protocol_session_pass_gate_matches_exactly() -> void:
	# Arrange：口令门纯逻辑（net_session.hello_pass_ok·不开任何 socket）
	var NetSession := preload("res://src/net/net_session.gd")
	var open_room: RefCounted = NetSession.new()
	var locked: RefCounted = NetSession.new()
	locked.password = "sesame"
	# Act + Assert：公开房全放行；口令房全等才放行（缺字段=空串=不匹配）
	assert_true(open_room.hello_pass_ok({}))
	assert_true(open_room.hello_pass_ok({"pass": "whatever"}))
	assert_true(locked.hello_pass_ok({"pass": "sesame"}))
	assert_false(locked.hello_pass_ok({"pass": "SESAME"}))
	assert_false(locked.hello_pass_ok({}))
