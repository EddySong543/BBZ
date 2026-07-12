extends Control

## 联机大厅（M1 建·M2b 扩·2026-07-12·局域网直连 1v1）：
## - 阵容自选：24 英雄格选 3（默认预选）——加入方经 hello 报到并上交阵容·房主收 hello 开局
## - 断线重连：对局进行中再次「加入同一 IP」→ hello 被房间当重连报到 → 快照续战（同一条加入路径·零特殊操作）
## 会话经 BattleSetup.net_session 交接给 battle_screen（其退场时负责 close+置空）。BP 博弈联机化=后续。

const MENU_SCENE := "res://src/ui/main_menu.tscn"
const BATTLE_SCENE := "res://src/ui/battle_screen.tscn"
const HERO_DATA_DIR := "res://assets/data/heroes/"
const NetSession := preload("res://src/net/net_session.gd")
const NetProtocol := preload("res://src/net/net_protocol.gd")
const DEFAULT_PICK: Array = ["h01", "h05", "h06"]
const JOIN_TIMEOUT := 8.0
const PICK_MAX := 3

var _session: RefCounted = null
var _mode := ""            # "" / "host" / "join"
var _join_waited := 0.0
var _picked: Array = []    # 我的阵容（hero_id·有序）
var _joiner_team: Array = []   # 房主：收到的加入方阵容
var _hello_sent := false       # 加入方：hello 只发一次

var _status: Label
var _pick_label: Label
var _ip_edit: LineEdit
var _host_btn: Button
var _join_btn: Button
var _hero_btns: Dictionary = {}   # hero_id -> Button


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

	# —— 建房 / 加入 ——
	_host_btn = Button.new()
	_host_btn.text = tr("建 房（端口 %d）") % NetSession.DEFAULT_PORT
	_host_btn.custom_minimum_size = Vector2(0, 68)
	FontManager.apply_btn(_host_btn, 20)
	_host_btn.pressed.connect(_on_host)
	box.add_child(_host_btn)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_ip_edit = LineEdit.new()
	_ip_edit.placeholder_text = tr("对方 IP（如 192.168.1.5）")
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
	_status.text = tr("选好 3 人阵容 → 一方建房，另一方输入房主 IP 加入。掉线后从这里加入同一 IP 即可续战。")
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(920, 0)
	_status.add_theme_color_override("font_color", Color(0.78, 0.74, 0.66))
	FontManager.apply(_status, 16)
	box.add_child(_status)
	_host_btn.grab_focus()


func _process(delta: float) -> void:
	if _session == null:
		return
	_session.pump()
	if _mode == "host":
		if _session.room == null:
			# 收加入方 hello（报到+阵容）→ 校验 → 开局
			for msg in _session.poll_prestart():
				if NetProtocol.validate_c2s(msg) == "" and String(msg.get("kind", "")) == "hello":
					_joiner_team = _sanitize_team(msg.get("team", []))
					_status.text = tr("对方已就位，开局中…")
					_session.start_room(_load_team(_picked), _load_team(_joiner_team), randi())
	elif _mode == "join":
		_join_waited += delta
		if _session.is_link_ready() and not _hello_sent:
			_hello_sent = true
			_session.client.send_hello(_picked)
			_status.text = tr("已连上，等待开局/续战…")
		if not _session.is_link_ready() and _join_waited > JOIN_TIMEOUT:
			_status.text = tr("连接失败：请确认对方已建房、IP 正确、同一局域网。")
			_session.close()
			_session = null
			_mode = ""
			_hello_sent = false
			_set_controls_enabled(true)
			return
	# 双方：拿到玩家位（新局=match_start·重连=snapshot）→ 交接会话进战斗
	if int(_session.client.you) >= 0:
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
	_session = NetSession.create_host()
	if _session == null:
		_status.text = tr("建房失败：端口 %d 被占用（是否已开着另一个游戏窗口？）") % NetSession.DEFAULT_PORT
		return
	_mode = "host"
	_status.text = tr("已建房，等待对方加入…（把你的局域网 IP 告诉对方）")
	_set_controls_enabled(false)


func _on_join() -> void:
	if not _pick_ready():
		return
	var ip := _ip_edit.text.strip_edges()
	if not ip.is_valid_ip_address():
		_status.text = tr("IP 格式不对：例如 192.168.1.5")
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
	if _session != null:
		_session.close()
		_session = null
	TransitionManager.transition_to(MENU_SCENE)


func _set_controls_enabled(on: bool) -> void:
	_host_btn.disabled = not on
	_join_btn.disabled = not on
	_ip_edit.editable = on
	for id in _hero_btns:
		(_hero_btns[id] as Button).disabled = not on


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
