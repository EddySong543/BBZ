extends Control

## 联机大厅（M1 建·M2b 扩·2026-07-12·局域网直连 1v1｜好友开房准备批·2026-07-14）：
## - 阵容自选：24 英雄格选 3（默认预选）——加入方经 hello 报到并上交阵容·房主收 hello 开局
## - 断线重连：对局进行中再次「加入同一 IP」→ hello 被房间当重连报到 → 快照续战（同一条加入路径·零特殊操作）
## - 房间发现：房主 UDP 信标广播 → 空闲端「附近的房间」列表点击即入（lan_discovery）
## - 好友房：可选口令（准入门在 net_session.poll_prestart·拒后踢席位）+ 版本握手 + 房号短码（room_code）
## 会话经 BattleSetup.net_session 交接给 battle_screen（其退场时负责 close+置空）。BP 博弈联机化=后续。

const MENU_SCENE := "res://src/ui/main_menu.tscn"
const BATTLE_SCENE := "res://src/ui/battle_screen1.tscn"
const HERO_DATA_DIR := "res://assets/data/heroes/"
const NetSession := preload("res://src/net/net_session.gd")
const NetProtocol := preload("res://src/net/net_protocol.gd")
const LanDiscovery := preload("res://src/net/lan_discovery.gd")
const RoomCode := preload("res://src/net/room_code.gd")
const DEFAULT_PICK: Array = ["h01", "h05", "h06"]
const JOIN_TIMEOUT := 8.0
const PICK_MAX := 3
const ROOMS_REFRESH := 0.5     # 房间列表 UI 重建间隔（秒）

var _session: RefCounted = null
var _mode := ""            # "" / "host" / "join"
var _join_waited := 0.0
var _picked: Array = []    # 我的阵容（hero_id·有序）
var _joiner_team: Array = []   # 房主：收到的加入方阵容
var _hello_sent := false       # 加入方：hello 只发一次

var _status: Label
var _pick_label: Label
var _ip_edit: LineEdit
var _pass_edit: LineEdit
var _host_btn: Button
var _join_btn: Button
var _hero_btns: Dictionary = {}   # hero_id -> Button
var _rooms_label: Label
var _rooms_box: VBoxContainer
var _beacon: LanDiscovery.Beacon = null     # 仅房主等待期广播
var _browser: LanDiscovery.Browser = null   # 空闲/加入期找房（同机端口被占=null 降级手输）
var _rooms_accum := 1.0                     # 首帧即刷一次列表


func _ready() -> void:
	FontManager.apply($TopBand/Title, 32)
	FontManager.apply_btn($TopBand/BackButton, 24)
	($TopBand/BackButton as Button).pressed.connect(_on_back)
	var box: VBoxContainer = $Panel

	# —— 阵容自选（24 英雄·选 3·默认预选）——
	_pick_label = Label.new()
	_pick_label.add_theme_color_override("font_color", Color(0.85, 0.78, 0.62))
	FontManager.apply(_pick_label, 20)
	box.add_child(_pick_label)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for id in _roster():
		var h: HeroData = load(HERO_DATA_DIR + id + ".tres")
		var b := Button.new()
		b.toggle_mode = true
		b.text = tr(h.hero_name)
		b.custom_minimum_size = Vector2(148, 52)
		FontManager.apply_btn(b, 16)
		b.toggled.connect(_on_hero_toggled.bind(id))
		grid.add_child(b)
		_hero_btns[id] = b
	box.add_child(grid)
	for id in DEFAULT_PICK:
		if _hero_btns.has(id):
			(_hero_btns[id] as Button).button_pressed = true   # 触发 toggled → 入 _picked

	box.add_child(HSeparator.new())

	# —— 建房（口令可选）——
	var host_row := HBoxContainer.new()
	host_row.add_theme_constant_override("separation", 16)
	_pass_edit = LineEdit.new()
	_pass_edit.placeholder_text = tr("房间口令（可选·好友对暗号）")
	_pass_edit.max_length = NetProtocol.MAX_PASS_LEN
	_pass_edit.custom_minimum_size = Vector2(340, 60)
	host_row.add_child(_pass_edit)   # LineEdit 用默认字体（FontManager.apply 只收 Label）
	_host_btn = Button.new()
	_host_btn.text = tr("建 房（端口 %d）") % NetSession.DEFAULT_PORT
	_host_btn.custom_minimum_size = Vector2(0, 60)
	_host_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	FontManager.apply_btn(_host_btn, 20)
	_host_btn.pressed.connect(_on_host)
	host_row.add_child(_host_btn)
	box.add_child(host_row)

	# —— 附近的房间（UDP 信标自动发现·点击即加入）——
	_rooms_label = Label.new()
	_rooms_label.add_theme_color_override("font_color", Color(0.85, 0.78, 0.62))
	FontManager.apply(_rooms_label, 20)
	_rooms_label.text = tr("附近的房间：搜索中…")
	box.add_child(_rooms_label)
	_rooms_box = VBoxContainer.new()
	_rooms_box.add_theme_constant_override("separation", 8)
	box.add_child(_rooms_box)

	# —— 手动加入（IP 或房号）——
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_ip_edit = LineEdit.new()
	_ip_edit.placeholder_text = tr("对方 IP 或房号（如 192.168.1.5 / K7Q3-N2P8）")
	_ip_edit.custom_minimum_size = Vector2(420, 60)
	row.add_child(_ip_edit)   # LineEdit 用默认字体（FontManager.apply 只收 Label）
	_join_btn = Button.new()
	_join_btn.text = tr("加 入 / 重连")
	_join_btn.custom_minimum_size = Vector2(200, 60)
	FontManager.apply_btn(_join_btn, 20)
	_join_btn.pressed.connect(_on_join)
	row.add_child(_join_btn)
	box.add_child(row)

	_status = Label.new()
	_status.text = tr("选好 3 人阵容 → 一方建房（可设口令），另一方点列表里的房、或输 IP/房号加入。掉线后同一路径重进即续战。")
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(920, 0)
	_status.add_theme_color_override("font_color", Color(0.78, 0.74, 0.66))
	FontManager.apply(_status, 16)
	box.add_child(_status)
	_host_btn.grab_focus()

	_browser = LanDiscovery.Browser.new()
	if not _browser.start():   # 同机另一窗口占了发现端口 → 降级手输 IP/房号
		_rooms_label.text = tr("附近的房间：本机已有窗口在找房（这里改用 IP/房号加入）")
		_browser = null


func _process(delta: float) -> void:
	_refresh_rooms(delta)
	if _beacon != null:
		_beacon.tick(delta)
	if _session == null:
		return
	_session.pump()
	if _mode == "host":
		if _session.room == null:
			# 收加入方 hello（报到+阵容）——口令/版本准入门内置在 net_session.poll_prestart
			for msg in _session.poll_prestart():
				_joiner_team = _sanitize_team(msg.get("team", []))
				_status.text = tr("对方已就位，开局中…")
				_stop_discovery()
				_session.start_room(_load_team(_picked), _load_team(_joiner_team), randi())
			if _session.last_reject != "":
				var why := tr("口令不对") if String(_session.last_reject) == "bad_pass" \
					else tr("版本不一致（对方 %s）") % String(_session.last_reject).get_slice(":", 1)
				_status.text = tr("有人想加入但被拒（%s），继续等待…") % why
				_session.last_reject = ""
	elif _mode == "join":
		_join_waited += delta
		if _session.is_link_ready() and not _hello_sent:
			_hello_sent = true
			# rtk=重连令牌（2026-07-17 身份门）：断线重连=凭上局 match_start 留底的令牌取回席位；
			# 首次加入=空串（房间开局前不查·开局时会下发新令牌覆盖留底）。
			_session.client.send_hello(_picked, _pass_edit.text.strip_edges(), "", BattleSetup.net_rtk)
			_status.text = tr("已连上，等待开局/续战…")
		if not _session.client.errors.is_empty():   # 被房主拒（口令/版本）→ 收摊重来
			_status.text = _reject_text(String(_session.client.errors[0]))
			_reset_join()
			return
		if not _session.is_link_ready() and _join_waited > JOIN_TIMEOUT:
			_status.text = tr("连接失败：请确认对方已建房、IP/房号正确、同一局域网。")
			_reset_join()
			return
	# 双方：拿到玩家位（新局=match_start·重连=snapshot)→ 交接会话进战斗
	if int(_session.client.you) >= 0:
		_stop_discovery()
		BattleSetup.net_session = _session
		_session = null   # 所有权移交 battle_screen
		TransitionManager.transition_to(BATTLE_SCENE)


func _on_hero_toggled(pressed: bool, id: String) -> void:
	if pressed:
		if _picked.size() >= PICK_MAX:
			(_hero_btns[id] as Button).set_pressed_no_signal(false)   # 满员拒入（先取消一个再选）
			return
		_picked.append(id)
	else:
		_picked.erase(id)
	_pick_label.text = tr("我的阵容（%d/%d）：%s") % [_picked.size(), PICK_MAX, "、".join(_team_names())]


func _team_names() -> Array:
	var names: Array = []
	for id in _picked:
		names.append((_hero_btns[id] as Button).text)
	return names


func _on_host() -> void:
	if not _pick_ready():
		return
	var room_pass := _pass_edit.text.strip_edges()
	_session = NetSession.create_host(NetSession.DEFAULT_PORT, room_pass)
	if _session == null:
		_status.text = tr("建房失败：端口 %d 被占用（是否已开着另一个游戏窗口？）") % NetSession.DEFAULT_PORT
		return
	_mode = "host"
	# 房主停找房（腾出发现端口给同机其他窗口）→ 起信标广播房间
	if _browser != null:
		_browser.stop()
		_browser = null
	_beacon = LanDiscovery.Beacon.new()
	_beacon.start(LanDiscovery.Beacon.make_payload(_room_name(), NetSession.DEFAULT_PORT,
		NetProtocol.game_version(), not room_pass.is_empty()))
	_status.text = tr("已建房%s · 房号 %s · 等待加入…（同网好友的大厅列表能直接看到这个房）") % [
		tr("（有口令）") if not room_pass.is_empty() else "", _room_codes_text()]
	_set_controls_enabled(false)


func _on_join() -> void:
	if not _pick_ready():
		return
	var raw := _ip_edit.text.strip_edges()
	var ip := raw
	if not ip.is_valid_ip_address():
		ip = RoomCode.decode(raw)   # 不是 IP → 按房号解（容错大小写/连字符/易混字符）
	if ip.is_empty() or not ip.is_valid_ip_address():
		_status.text = tr("没认出来：请输对方 IP（如 192.168.1.5）或 8 位房号（如 K7Q3-N2P8）。")
		return
	_session = NetSession.create_join(ip)
	if _session == null:
		_status.text = tr("拨号失败（网络不可用？）")
		return
	_mode = "join"
	_join_waited = 0.0
	_hello_sent = false
	_status.text = tr("连接 %s 中…") % ip
	_set_controls_enabled(false)


func _pick_ready() -> bool:
	if _picked.size() != PICK_MAX:
		_status.text = tr("先把阵容选满 %d 人再开（当前 %d 人）。") % [PICK_MAX, _picked.size()]
		return false
	return true


func _on_back() -> void:
	_stop_discovery()
	if _session != null:
		_session.close()
		_session = null
	TransitionManager.transition_to(MENU_SCENE)


func _set_controls_enabled(on: bool) -> void:
	_host_btn.disabled = not on
	_join_btn.disabled = not on
	_ip_edit.editable = on
	_pass_edit.editable = on
	for id in _hero_btns:
		(_hero_btns[id] as Button).disabled = not on
	for c in _rooms_box.get_children():
		(c as Button).disabled = not on


# —— 局域网发现 / 好友房辅助（2026-07-14）——

## 找房刷新：每帧收信标；每 0.5s 重建一次列表 UI（仅空闲态——建房/加入中列表冻结禁点）。
func _refresh_rooms(delta: float) -> void:
	if _browser == null:
		return
	_browser.poll()
	_rooms_accum += delta
	if _rooms_accum < ROOMS_REFRESH or _mode != "":
		return
	_rooms_accum = 0.0
	for c in _rooms_box.get_children():
		c.queue_free()
	var rooms: Array = _browser.list()
	_rooms_label.text = tr("附近的房间：暂无（等好友建房，或直接输 IP/房号）") if rooms.is_empty() \
		else tr("附近的房间（%d 个·点击加入）：") % rooms.size()
	for r in rooms:
		var info: Dictionary = r
		var tags := ""
		if bool(info["has_pass"]):
			tags += tr("〔需口令〕")
		if String(info["gv"]) != NetProtocol.game_version():
			tags += tr("〔版本 %s·不一致〕") % info["gv"]
		var b := Button.new()
		b.text = "%s · %s%s" % [String(info["name"]), String(info["ip"]), tags]
		b.custom_minimum_size = Vector2(0, 52)
		FontManager.apply_btn(b, 16)
		b.pressed.connect(_on_room_clicked.bind(String(info["ip"]), bool(info["has_pass"])))
		_rooms_box.add_child(b)


func _on_room_clicked(ip: String, has_pass: bool) -> void:
	_ip_edit.text = ip
	if has_pass and _pass_edit.text.strip_edges().is_empty():
		_status.text = tr("这个房间设了口令：先在上面填口令，再点「加 入 / 重连」。")
		_pass_edit.grab_focus()
		return
	_on_join()


## 加入失败/被拒后的收摊复位（保留输入框内容便于改口令重试）。
func _reset_join() -> void:
	_session.close()
	_session = null
	_mode = ""
	_hello_sent = false
	_set_controls_enabled(true)


func _reject_text(code: String) -> String:
	if code == "bad_pass":
		return tr("房间口令不对：和房主核对后重试。")
	if code.begins_with("bad_version"):
		return tr("版本不一致：你 %s · 房主 %s。统一版本后再试。") % [
			NetProtocol.game_version(), code.get_slice(":", 1)]
	return tr("被房主拒绝（%s）。") % code


func _stop_discovery() -> void:
	if _beacon != null:
		_beacon.stop()
		_beacon = null
	if _browser != null:
		_browser.stop()
		_browser = null


## 房号文本：本机每个私网 IPv4 一个短码（通常 1 个；多网卡/VPN 时并列）。
func _room_codes_text() -> String:
	var parts: Array = []
	for ip in LanDiscovery.local_ipv4s():
		parts.append("%s（%s）" % [RoomCode.encode(String(ip)), String(ip)])
	return "、".join(parts) if not parts.is_empty() else tr("未检测到局域网地址")


## 房名=系统用户名（好友一眼认人·空则回退通用名）。
func _room_name() -> String:
	var n := OS.get_environment("USERNAME").strip_edges()   # Windows；Linux/mac 用 USER
	if n.is_empty():
		n = OS.get_environment("USER").strip_edges()
	if n.is_empty():
		n = tr("波波攒房主")
	return n.substr(0, 24)


## 全英雄名录（assets/data/heroes/*.tres·按 id 排序）。
func _roster() -> Array:
	var out: Array = []
	var da := DirAccess.open(HERO_DATA_DIR)
	if da == null:
		return out
	da.list_dir_begin()
	var f := da.get_next()
	while f != "":
		if f.ends_with(".tres"):
			out.append(f.get_basename())
		f = da.get_next()
	da.list_dir_end()
	out.sort()
	return out


## 房主侧净化加入方阵容：只留真实存在的英雄资源·不足 3 补默认（防伪造 id）。
func _sanitize_team(ids: Array) -> Array:
	var ok: Array = []
	for id in ids:
		if id is String and ResourceLoader.exists(HERO_DATA_DIR + String(id) + ".tres"):
			ok.append(String(id))
	for id in DEFAULT_PICK:
		if ok.size() >= PICK_MAX:
			break
		if not ok.has(id):
			ok.append(id)
	return ok.slice(0, PICK_MAX)


func _load_team(ids: Array) -> Array:
	var t: Array = []
	for id in ids:
		var path: String = HERO_DATA_DIR + String(id) + ".tres"
		if ResourceLoader.exists(path):
			t.append(load(path))
	return t
