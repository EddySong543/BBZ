extends GutTest

## 局域网房间发现 行为锁定测试（好友开房准备批·2026-07-14）。
## 锁：信标包校验（含 JSON 降级兼容）/房间表进出（去重·过期·上限）/非法包静默丢弃。
## ⚠ 真 UDP 收发归 tools/lan_probe（单元测试禁网络依赖=tests/ 规则）——这里只测纯逻辑口。

const LanDiscovery := preload("res://src/net/lan_discovery.gd")


func _payload() -> Dictionary:
	return LanDiscovery.Beacon.make_payload("Eddy 的房", 47777, "0.1.0", true)


func test_lan_discovery_valid_payload_passes_validation() -> void:
	# Arrange + Act + Assert
	assert_true(LanDiscovery.Browser.validate_payload(_payload()))


func test_lan_discovery_payload_survives_json_wire_degradation() -> void:
	# Arrange：模拟真网络 JSON 往返（int→float）
	var wire: Variant = JSON.parse_string(JSON.stringify(_payload()))
	# Act + Assert
	assert_true(LanDiscovery.Browser.validate_payload(wire))


func test_lan_discovery_bad_payloads_rejected() -> void:
	# Arrange：魔数错/端口类型错/空房名/缺口令标志/端口越界/超长房名 + 非字典
	var bad_magic := _payload()
	bad_magic["m"] = "other_game"
	var bad_port_type := _payload()
	bad_port_type["port"] = "47777"
	var empty_name := _payload()
	empty_name["name"] = ""
	var no_flag := _payload()
	no_flag.erase("has_pass")
	var low_port := _payload()
	low_port["port"] = 80
	var long_name := _payload()
	long_name["name"] = "很".repeat(25)
	# Act + Assert
	for b in [bad_magic, bad_port_type, empty_name, no_flag, low_port, long_name, null, [], "x"]:
		assert_false(LanDiscovery.Browser.validate_payload(b), str(b))


func test_lan_discovery_browser_ingest_lists_and_expires_room() -> void:
	# Arrange
	var br := LanDiscovery.Browser.new()
	# Act：t=0 收信标 → t=1000 未过期 → t=99999 过期
	br._ingest(_payload(), "192.168.1.5", 0)
	br._expire(1000)
	var alive: Array = br.list()
	br._expire(99999)
	var gone: Array = br.list()
	# Assert
	assert_eq(alive.size(), 1)
	assert_eq(String((alive[0] as Dictionary)["ip"]), "192.168.1.5")
	assert_true(bool((alive[0] as Dictionary)["has_pass"]))
	assert_eq(gone.size(), 0)


func test_lan_discovery_browser_same_ip_dedupes_and_refreshes() -> void:
	# Arrange
	var br := LanDiscovery.Browser.new()
	# Act：同一 IP 两拍信标（第二拍刷新 seen）
	br._ingest(_payload(), "192.168.1.5", 0)
	br._ingest(_payload(), "192.168.1.5", 3000)
	br._expire(4000)   # 距第二拍仅 1000ms —— 不该过期
	# Assert
	assert_eq(br.list().size(), 1)


func test_lan_discovery_browser_invalid_beacon_ignored_silently() -> void:
	# Arrange
	var br := LanDiscovery.Browser.new()
	# Act
	br._ingest({m = "nope"}, "192.168.1.9", 0)
	br._ingest("garbage", "192.168.1.9", 0)
	# Assert
	assert_eq(br.list().size(), 0)


func test_lan_discovery_browser_room_table_capped_against_flood() -> void:
	# Arrange
	var br := LanDiscovery.Browser.new()
	# Act：25 个不同源 IP 洪水信标
	for i in 25:
		br._ingest(_payload(), "192.168.9.%d" % i, 0)
	# Assert：表上限 16
	assert_eq(br.list().size(), 16)
