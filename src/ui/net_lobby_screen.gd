extends Control

## 联机大厅（M1·2026-07-12·局域网直连 1v1）：建房=开门等一个对手；加入=输 IP 拨号。
## 链路建立 → 房主开局（MVP=固定默认阵容·BP 联机化=M2b）→ 双方收到 match_start → 进战斗。
## 会话经 BattleSetup.net_session 交接给 battle_screen（其退场时负责 close+置空）。

const MENU_SCENE := "res://src/ui/main_menu.tscn"
const BATTLE_SCENE := "res://src/ui/battle_screen.tscn"
const HERO_DATA_DIR := "res://assets/data/heroes/"
const NetSession := preload("res://src/net/net_session.gd")
const TEAM_HOST: Array = ["h01", "h05", "h06"]   # MVP 固定阵容（与本地默认一致·BP 联机化=M2b）
const TEAM_JOIN: Array = ["h02", "h09", "h12"]
const JOIN_TIMEOUT := 8.0

var _session: RefCounted = null
var _mode := ""            # "" / "host" / "join"
var _join_waited := 0.0

var _status: Label
var _ip_edit: LineEdit
var _host_btn: Button
var _join_btn: Button


func _ready() -> void:
	FontManager.apply($TopBand/Title, 32)
	FontManager.apply_btn($TopBand/BackButton, 24)
	($TopBand/BackButton as Button).pressed.connect(_on_back)
	var box: VBoxContainer = $Panel

	_host_btn = Button.new()
	_host_btn.text = "建 房（端口 %d）" % NetSession.DEFAULT_PORT
	_host_btn.custom_minimum_size = Vector2(0, 72)
	FontManager.apply_btn(_host_btn, 20)
	_host_btn.pressed.connect(_on_host)
	box.add_child(_host_btn)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_ip_edit = LineEdit.new()
	_ip_edit.placeholder_text = "对方 IP（如 192.168.1.5）"
	_ip_edit.custom_minimum_size = Vector2(380, 64)
	FontManager.apply(_ip_edit, 16)
	row.add_child(_ip_edit)
	_join_btn = Button.new()
	_join_btn.text = "加 入"
	_join_btn.custom_minimum_size = Vector2(180, 64)
	FontManager.apply_btn(_join_btn, 20)
	_join_btn.pressed.connect(_on_join)
	row.add_child(_join_btn)
	box.add_child(row)

	_status = Label.new()
	_status.text = "同一局域网内：一方建房，另一方输入房主 IP 加入。"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(600, 0)
	_status.add_theme_color_override("font_color", Color(0.78, 0.74, 0.66))
	FontManager.apply(_status, 16)
	box.add_child(_status)
	_host_btn.grab_focus()


func _process(delta: float) -> void:
	if _session == null:
		return
	_session.pump()
	if _mode == "host":
		if _session.room == null and _session.is_link_ready():
			_status.text = "对方已连入，开局中…"
			_session.start_room(_load_team(TEAM_HOST), _load_team(TEAM_JOIN), randi())
	elif _mode == "join":
		_join_waited += delta
		if not _session.is_link_ready() and _join_waited > JOIN_TIMEOUT:
			_status.text = "连接失败：请确认对方已建房、IP 正确、同一局域网。"
			_session.close()
			_session = null
			_mode = ""
			_set_controls_enabled(true)
			return
	# 双方：收到 match_start（分到玩家位）→ 交接会话进战斗
	if int(_session.client.you) >= 0:
		BattleSetup.net_session = _session
		_session = null   # 所有权移交 battle_screen
		TransitionManager.transition_to(BATTLE_SCENE)


func _on_host() -> void:
	_session = NetSession.create_host()
	if _session == null:
		_status.text = "建房失败：端口 %d 被占用（是否已开着另一个游戏窗口？）" % NetSession.DEFAULT_PORT
		return
	_mode = "host"
	_status.text = "已建房，等待对方加入…（把你的局域网 IP 告诉对方）"
	_set_controls_enabled(false)


func _on_join() -> void:
	var ip := _ip_edit.text.strip_edges()
	if not ip.is_valid_ip_address():
		_status.text = "IP 格式不对：例如 192.168.1.5"
		return
	_session = NetSession.create_join(ip)
	if _session == null:
		_status.text = "拨号失败（网络不可用？）"
		return
	_mode = "join"
	_join_waited = 0.0
	_status.text = "连接 %s 中…" % ip
	_set_controls_enabled(false)


func _on_back() -> void:
	if _session != null:
		_session.close()
		_session = null
	TransitionManager.transition_to(MENU_SCENE)


func _set_controls_enabled(on: bool) -> void:
	_host_btn.disabled = not on
	_join_btn.disabled = not on
	_ip_edit.editable = on


func _load_team(ids: Array) -> Array:
	var t: Array = []
	for id in ids:
		var path: String = HERO_DATA_DIR + String(id) + ".tres"
		if ResourceLoader.exists(path):
			t.append(load(path))
	return t
