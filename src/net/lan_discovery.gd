extends RefCounted

## 局域网房间发现（好友开房准备批·2026-07-14·ADR-004）：
## - Beacon（房主）：每秒 UDP 广播房间信标（255.255.255.255 + 127.0.0.1 双投·后者供同机双开测试）。
## - Browser（找房）：绑定发现端口收信标 → 房间表（按源 IP 去重·3.5s 无信标过期）。
## 纯局域网零服务器；信标只带公开信息（房名/端口/版本/是否有口令），口令本体绝不进信标。
## ⚠ 同机同时只能有一个 Browser（UDP 端口独占）：开房即停自家 Browser；bind 失败=静默降级手输 IP。
## ⚠ GDScript 内部类无法引用外部常量 → 端口/魔数在两个内部类里各有副本（改动必须三处同步）。

const DISCOVERY_PORT := 47778   # = 对局端口 47777 + 1（外部调用者引用用；内部类持有副本）


## 本机私网 IPv4 列表（192.168./10./172.16-31.）——供大厅展示房号。
static func local_ipv4s() -> Array:
	var out: Array = []
	for a in IP.get_local_addresses():
		var ip := String(a)
		if ip.count(".") != 3:
			continue   # 只收 IPv4
		if ip.begins_with("192.168.") or ip.begins_with("10."):
			out.append(ip)
		elif ip.begins_with("172."):
			var second := int(ip.get_slice(".", 1))
			if second >= 16 and second <= 31:
				out.append(ip)
	out.sort()
	return out


## 房主信标：start(payload) 后每帧喂 tick(delta)，间隔到点广播一发。对局开始/退大厅必须 stop()。
class Beacon extends RefCounted:
	const PORT := 47778             # = LanDiscovery.DISCOVERY_PORT 副本
	const MAGIC := "bobozan_room"
	const MAX_NAME_LEN := 24
	const INTERVAL := 1.0

	var _udp := PacketPeerUDP.new()
	var _wire: PackedByteArray
	var _accum := INTERVAL          # 起手立即发第一拍
	var _on := false

	## 信标包构造（纯逻辑·单测口）。
	static func make_payload(room_name: String, port: int, gv: String, has_pass: bool) -> Dictionary:
		return {m = MAGIC, v = 1, name = room_name.substr(0, MAX_NAME_LEN), port = port,
			gv = gv, has_pass = has_pass}

	func start(payload: Dictionary) -> void:
		_wire = JSON.stringify(payload).to_utf8_buffer()
		_udp.set_broadcast_enabled(true)
		_on = true

	func tick(delta: float) -> void:
		if not _on:
			return
		_accum += delta
		if _accum < INTERVAL:
			return
		_accum = 0.0
		for dest in ["255.255.255.255", "127.0.0.1"]:   # 广播 + 环回（同机双开测试）
			if _udp.set_dest_address(String(dest), PORT) == OK:
				_udp.put_packet(_wire)   # 尽力而为：个别网卡/防火墙失败不炸流程

	func stop() -> void:
		_on = false
		_udp.close()


## 找房端：start() 绑发现端口（同机被占则返回 false=降级手输 IP），poll() 每帧收包+过期清理。
class Browser extends RefCounted:
	const PORT := 47778             # = LanDiscovery.DISCOVERY_PORT 副本
	const MAGIC := "bobozan_room"
	const MAX_NAME_LEN := 24
	const MAX_GV_LEN := 16
	const EXPIRE_MS := 3500
	const MAX_PACKET := 512         # 信标包体上限（超限即丢·洪水防护）
	const MAX_ROOMS := 16           # 房间表上限（信标洪水防护）

	var _udp := PacketPeerUDP.new()
	var _bound := false
	var _rooms: Dictionary = {}     # ip -> {name, port, gv, has_pass, seen_ms}

	func start() -> bool:
		_bound = _udp.bind(PORT) == OK
		return _bound

	func poll() -> void:
		if not _bound:
			return
		var now := Time.get_ticks_msec()
		while _udp.get_available_packet_count() > 0:
			var pkt := _udp.get_packet()
			var ip := _udp.get_packet_ip()
			if pkt.size() > MAX_PACKET:
				continue
			_ingest(JSON.parse_string(pkt.get_string_from_utf8()), ip, now)
		_expire(now)

	## 收一条信标（纯逻辑·单测口）：非法静默丢弃·合法进/刷房间表。
	func _ingest(payload: Variant, ip: String, now_ms: int) -> void:
		if not validate_payload(payload):
			return
		if not _rooms.has(ip) and _rooms.size() >= MAX_ROOMS:
			return
		var d: Dictionary = payload
		_rooms[ip] = {name = String(d["name"]), port = int(d["port"]), gv = String(d["gv"]),
			has_pass = bool(d["has_pass"]), seen_ms = now_ms}

	## 过期清理（纯逻辑·单测口）。
	func _expire(now_ms: int) -> void:
		for ip in _rooms.keys():
			if now_ms - int((_rooms[ip] as Dictionary)["seen_ms"]) > EXPIRE_MS:
				_rooms.erase(ip)

	## 活跃房间列表（按 ip 排序·每项补 ip 字段·深拷不泄内部表）。
	func list() -> Array:
		var out: Array = []
		var ips: Array = _rooms.keys()
		ips.sort()
		for ip in ips:
			var r: Dictionary = (_rooms[ip] as Dictionary).duplicate()
			r["ip"] = ip
			out.append(r)
		return out

	func stop() -> void:
		_bound = false
		_udp.close()

	## 信标包校验（陌生网段/恶意包一律丢）。
	static func validate_payload(d: Variant) -> bool:
		if not (d is Dictionary):
			return false
		var dd: Dictionary = d
		if String(dd.get("m", "")) != MAGIC:
			return false
		if not _is_int(dd.get("v")) or int(dd["v"]) != 1:
			return false
		var n: Variant = dd.get("name")
		if not (n is String) or (n as String).is_empty() or (n as String).length() > MAX_NAME_LEN:
			return false
		if not _is_int(dd.get("port")) or int(dd["port"]) < 1024 or int(dd["port"]) > 65535:
			return false
		var gv: Variant = dd.get("gv")
		if not (gv is String) or (gv as String).length() > MAX_GV_LEN:
			return false
		if not (dd.get("has_pass") is bool):
			return false
		return true

	## JSON 往返后 int 会变 float —— 整数判定两者都收（与 net_protocol 同款）。
	static func _is_int(v: Variant) -> bool:
		return v is int or (v is float and is_equal_approx(v, roundf(v)))
