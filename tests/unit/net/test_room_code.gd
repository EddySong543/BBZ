extends GutTest

## 房号短码 行为锁定测试（好友开房准备批·2026-07-14）。
## 锁：IPv4↔码往返/格式/校验和抓错/易混字符归一化/非法输入拒绝。

const RoomCode := preload("res://src/net/room_code.gd")


func test_room_code_roundtrip_common_ips_restores_ip() -> void:
	# Arrange：局域网常见段 + 边界值
	var ips: Array = ["192.168.1.5", "10.0.0.1", "172.31.255.254", "127.0.0.1", "0.0.0.0", "255.255.255.255"]
	for ip in ips:
		# Act
		var code: String = RoomCode.encode(String(ip))
		# Assert
		assert_eq(RoomCode.decode(code), String(ip), "往返 %s（码 %s）" % [ip, code])


func test_room_code_encode_format_is_grouped_eight_chars() -> void:
	# Arrange + Act
	var code := RoomCode.encode("192.168.1.5")
	# Assert：4-4 分组 + 连字符
	assert_eq(code.length(), 9)
	assert_eq(code[4], "-")


func test_room_code_decode_wrong_checksum_returns_empty() -> void:
	# Arrange：篡改末位校验字符（换成字母表里另一个字符）
	var code := RoomCode.encode("192.168.1.5")
	var last := code[code.length() - 1]
	var swapped := "2" if last != "2" else "3"
	var tampered := code.substr(0, code.length() - 1) + swapped
	# Act + Assert
	assert_eq(RoomCode.decode(tampered), "")


func test_room_code_normalize_maps_confusables_and_noise() -> void:
	# Arrange + Act + Assert：小写/连字符/空格/易混字符全部归一
	assert_eq(RoomCode.normalize(" k7q3-n2p8 "), "K7Q3N2P8")
	assert_eq(RoomCode.normalize("oIlu"), "011V")


func test_room_code_decode_lowercase_with_hyphen_still_works() -> void:
	# Arrange
	var code := RoomCode.encode("192.168.1.77")
	# Act：模拟语音抄号后的粗糙输入（小写+去连字符）
	var sloppy := code.to_lower().replace("-", "")
	# Assert
	assert_eq(RoomCode.decode(sloppy), "192.168.1.77")


func test_room_code_invalid_inputs_rejected() -> void:
	# Arrange + Act + Assert：长度不对/非法字符/非法 IP 编码
	assert_eq(RoomCode.decode("ABC"), "")
	assert_eq(RoomCode.decode("!!!!-!!!!"), "")
	assert_eq(RoomCode.encode("999.1.1.1"), "")
	assert_eq(RoomCode.encode("1.2.3"), "")
	assert_eq(RoomCode.encode("a.b.c.d"), "")
