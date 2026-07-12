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


func test_net_protocol_json_wire_degradation_accepted() -> void:
	# JSON 往返 int→float：真实传输路径上的合法包仍须通过
	var wire: Variant = JSON.parse_string(JSON.stringify(NetProtocol.msg_submit_turn(4, 2, -1, [0])))
	assert_eq(NetProtocol.validate_c2s(wire), "")
