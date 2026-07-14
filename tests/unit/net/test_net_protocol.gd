extends GutTest

## 联机协议入包校验 行为锁定测试（联机线批A·2026-07-12）。
## 锁：版本化拒绝/未知类型拒绝/字段范围校验/JSON 降级（int→float）兼容/自产消息必过自家校验。

const NetProtocol := preload("res://src/net/net_protocol.gd")


func test_net_protocol_own_messages_pass_validation() -> void:
	# Arrange + Act + Assert：构造器产的每种消息都过校验
	assert_eq(NetProtocol.validate_c2s(NetProtocol.msg_submit_turn(0, 1, -1, [0, 2])), "")
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
