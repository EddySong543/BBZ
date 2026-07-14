extends Node

## 局域网发现+好友房准入探针（好友开房准备批·2026-07-14）：真 UDP / 真 ENet on 127.0.0.1。
## ① 房号短码：本机地址全量编解码往返。
## ② 信标↔找房：Beacon 广播 → Browser 收到房间（名/端口/口令标志不失真）。
## ③ 准入门（走真实 net_session.poll_prestart）：错口令→bad_pass 拒+踢；错版本→bad_version:<房主版本>；
##    对口令→开局，双端玩家位就位（房主 0 / 加入 1）。
## 跑法（headless 可）：godot --headless --path . res://tools/lan_probe.tscn

const NetSession := preload("res://src/net/net_session.gd")
const NetProtocol := preload("res://src/net/net_protocol.gd")
const LanDiscovery := preload("res://src/net/lan_discovery.gd")
const RoomCode := preload("res://src/net/room_code.gd")
const PORT := 47901   # 避开真实对局端口（防撞正在跑的游戏窗口）
const TEAM_IDS: Array = ["h01", "h02", "h03"]


func _ready() -> void:
	var fails: Array[String] = []

	# —— ① 房号短码：本机地址全量往返 ——
	var all_ips: Array = LanDiscovery.local_ipv4s()
	all_ips.append("127.0.0.1")
	for ip in all_ips:
		var code: String = RoomCode.encode(String(ip))
		if RoomCode.decode(code) != String(ip):
			fails.append("房号往返失败 %s→%s" % [ip, code])

	# —— ② 信标 ↔ 找房（真 UDP·环回投递）——
	var browser := LanDiscovery.Browser.new()
	if not browser.start():
		fails.append("Browser 端口绑定失败（同机是否有别的实例在找房？）")
	else:
		var beacon := LanDiscovery.Beacon.new()
		beacon.start(LanDiscovery.Beacon.make_payload("probe房", PORT, NetProtocol.game_version(), true))
		var waited := 0.0
		var found: Dictionary = {}
		while waited < 4.0 and found.is_empty():
			beacon.tick(0.25)
			browser.poll()
			for r in browser.list():
				if int((r as Dictionary)["port"]) == PORT:
					found = r
			await get_tree().create_timer(0.25).timeout
			waited += 0.25
		if found.is_empty():
			fails.append("4s 内 Browser 未收到信标")
		elif String(found["name"]) != "probe房" or not bool(found["has_pass"]) \
				or String(found["gv"]) != NetProtocol.game_version():
			fails.append("信标字段失真: %s" % str(found))
		beacon.stop()
		browser.stop()

	# —— ③ 准入门（真 ENet + 真实 poll_prestart）——
	var host: RefCounted = NetSession.create_host(PORT, "sesame")
	if host == null:
		fails.append("建房失败（端口 %d）" % PORT)
	else:
		# 错口令 → bad_pass 拒 + 踢
		var deny := await _join_and_hello(host, "wrong", "")
		if deny != "bad_pass":
			fails.append("错口令未被拒（收到: %s）" % deny)
		if String(host.last_reject) != "bad_pass":
			fails.append("host.last_reject=%s（期望 bad_pass）" % host.last_reject)
		host.last_reject = ""

		# 错版本 → bad_version:<房主版本> 拒 + 踢
		deny = await _join_and_hello(host, "sesame", "9.9.9")
		if deny != "bad_version:" + NetProtocol.game_version():
			fails.append("错版本未被拒（收到: %s）" % deny)

		# 对口令 → 开局·双端玩家位就位
		var friend: RefCounted = NetSession.create_join("127.0.0.1", PORT)
		var waited2 := 0.0
		var hello_ok := false
		var friend_sent := false
		while waited2 < 5.0 and not hello_ok:
			for msg in host.poll_prestart():
				if not hello_ok:   # 只开一次局（防 hello 重复触发 start_room）
					hello_ok = true
					host.start_room(_team("a"), _team("b"), 777)
			if friend.is_link_ready() and not friend_sent:
				friend_sent = true
				friend.client.send_hello(TEAM_IDS, "sesame")
			friend.pump()
			await get_tree().create_timer(0.05).timeout
			waited2 += 0.05
		waited2 = 0.0
		while waited2 < 5.0 and (host.client.you != 0 or friend.client.you != 1):
			host.pump()
			friend.pump()
			await get_tree().create_timer(0.05).timeout
			waited2 += 0.05
		if host.client.you != 0 or friend.client.you != 1:
			fails.append("对口令开局失败（玩家位 %d/%d）" % [host.client.you, friend.client.you])
		if not friend.client.errors.is_empty():
			fails.append("好友端出现拒绝: %s" % str(friend.client.errors))
		friend.close()
		host.close()

	print("LAN_PROBE: %s" % ("PASS" if fails.is_empty() else "FAIL " + str(fails)))
	get_tree().quit()


## 起一个加入端 → 连上后发指定口令/版本的 hello → 等被拒（返回收到的错误码·超时返回 timeout）。
func _join_and_hello(host: RefCounted, room_pass: String, gv: String) -> String:
	var join: RefCounted = NetSession.create_join("127.0.0.1", PORT)
	if join == null:
		return "dial_failed"
	var sent := false
	var waited := 0.0
	while waited < 5.0 and join.client.errors.is_empty():
		host.poll_prestart()   # 泵主机侧（门内置）
		if join.is_link_ready() and not sent:
			sent = true
			join.client.send_hello(TEAM_IDS, room_pass, gv)
		join.client.poll()
		await get_tree().create_timer(0.05).timeout
		waited += 0.05
	var got := "timeout" if join.client.errors.is_empty() else String(join.client.errors[0])
	join.close()
	return got


func _team(prefix: String) -> Array:
	var out: Array = []
	for i in 3:
		var h := HeroData.new()
		h.hero_id = "%s%d" % [prefix, i]
		h.hero_name = h.hero_id
		h.max_hp = 5
		h.skill_type = HeroData.SkillType.PASSIVE
		out.append(h)
	return out
