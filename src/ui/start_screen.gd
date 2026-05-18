extends Control

## Title screen (tscn) + Ban/Pick (code-built — children of BPGroup don't resolve from tscn in 4.6).

enum Phase {
	P1_BAN1, P2_BAN1, P1_PICK1, P2_PICK1,
	P2_BAN2, P1_BAN2, P2_PICK2, P1_PICK2,
	P1_BAN3, P2_BAN3, P1_PICK3, P2_PICK3,
	DONE
}

const CARD_W := 130
const CARD_H := 130
const COLS := 8
const GAP := 10
const BP_TIME := 10

var all_heroes: Array[HeroData] = []
var p1_picks: Array[int] = []
var p2_picks: Array[int] = []
var banned: Array[int] = []
var phase: int = -1
var selected_idx: int = -1

# Title screen (from tscn — these work)
@onready var title_group: Control = $TitleGroup
@onready var title_label: Label = $TitleGroup/TitleLabel
@onready var subtitle_label: Label = $TitleGroup/SubtitleLabel
@onready var start_button: Button = $TitleGroup/StartButton

# BP UI (created in code)
@onready var bp_group: Control = $BPGroup
var phase_label: Label
var info_label: Label
var timer_label: Label
var confirm_btn: Button
var card_area: Control
var p1_title: Label
var p2_title: Label
var p1_slots: Array[Panel] = []
var p2_slots: Array[Panel] = []
var p1_slot_labels: Array[Label] = []
var p2_slot_labels: Array[Label] = []

var card_cards: Array[HeroCard] = []
var card_data: Array[int] = []
var bp_timer: Timer
var bp_timer_seconds: int = BP_TIME
var _portrait_cache: Dictionary = {}


func _ready() -> void:
	all_heroes = HeroData.create_pool_heroes()
	title_group.visible = true
	bp_group.visible = false
	_setup_title_ui()


func _setup_title_ui() -> void:
	title_label.text = "波波攒之王"
	FontManager.apply(title_label, 48)
	title_label.add_theme_color_override("font_color", Color("#f5c518"))

	subtitle_label.text = "1v1 同时回合制英雄对战"
	FontManager.apply(subtitle_label, 24)
	subtitle_label.add_theme_color_override("font_color", Color("#888899"))

	start_button.text = "开始匹配"
	FontManager.apply_btn(start_button, 32)
	start_button.pressed.connect(_on_start_pressed)


func _on_start_pressed() -> void:
	title_group.visible = false
	bp_group.visible = true
	_build_bp_ui()
	_enter_phase(Phase.P1_BAN1)


func _build_bp_ui() -> void:
	# Clear any existing BP children
	for c in bp_group.get_children():
		c.queue_free()

	var bp_bg := ColorRect.new()
	bp_bg.color = Color(0.102, 0.102, 0.18, 1)
	bp_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bp_group.add_child(bp_bg)

	# Phase / info / timer labels
	phase_label = _make_label("PhaseLabel", "", 24, Color("#f5c518"), Vector2(460, 10), Vector2(1000, 32), bp_group)
	info_label = _make_label("InfoLabel", "", 16, Color("#777799"), Vector2(460, 44), Vector2(1000, 22), bp_group)
	timer_label = _make_label("TimerLabel", "", 24, Color("#ffaa00"), Vector2(810, 70), Vector2(300, 32), bp_group)

	# Preview panels
	_build_preview_panel(0, Vector2(30, 120))
	_build_preview_panel(1, Vector2(30, 340))

	# Scroll + card area
	var scroll := ScrollContainer.new()
	scroll.name = "ScrollContainer"
	scroll.position = Vector2(240, 120)
	scroll.size = Vector2(1650, 850)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bp_group.add_child(scroll)

	card_area = Control.new()
	card_area.name = "CardArea"
	scroll.add_child(card_area)

	# Confirm button
	confirm_btn = Button.new()
	confirm_btn.text = "确认选择"
	confirm_btn.position = Vector2(810, 970)
	confirm_btn.size = Vector2(300, 60)
	FontManager.apply_btn(confirm_btn, 24)
	confirm_btn.pressed.connect(_on_confirm)
	bp_group.add_child(confirm_btn)

	# Timer
	bp_timer = Timer.new()
	bp_timer.one_shot = false
	bp_timer.timeout.connect(_on_bp_timer_tick)
	bp_group.add_child(bp_timer)

	# Hero cards
	_build_hero_cards()


func _build_preview_panel(player: int, pos: Vector2) -> void:
	var color := Color("#3388dd") if player == 0 else Color("#dd3333")
	var title_lbl := _make_label("P%dTitle" % (player + 1), "P%d 阵容" % (player + 1), 16, color, Vector2(0, 0), Vector2(180, 24), bp_group)
	title_lbl.position = pos
	if player == 0:
		p1_title = title_lbl
	else:
		p2_title = title_lbl

	var slots: Array[Panel] = []
	var labels: Array[Label] = []

	for i in range(3):
		var slot_y := pos.y + 36 + i * 58
		var slot := Panel.new()
		slot.position = Vector2(pos.x, slot_y)
		slot.size = Vector2(180, 50)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#1e1e36")
		sb.border_width_left = 2; sb.border_width_right = 2
		sb.border_width_top = 2; sb.border_width_bottom = 2
		sb.border_color = Color("#444466")
		sb.set_corner_radius_all(6)
		slot.add_theme_stylebox_override("panel", sb)
		bp_group.add_child(slot)
		slots.append(slot)

		var lbl := Label.new()
		lbl.text = "英雄 %d" % (i + 1)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.position = Vector2(pos.x, slot_y)
		lbl.size = Vector2(180, 50)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		FontManager.apply(lbl, 12)
		lbl.add_theme_color_override("font_color", Color("#aaaacc"))
		bp_group.add_child(lbl)
		labels.append(lbl)

	if player == 0:
		p1_slots = slots
		p1_slot_labels = labels
	else:
		p2_slots = slots
		p2_slot_labels = labels


func _build_hero_cards() -> void:
	var count := all_heroes.size()
	var rows := ceili(float(count) / COLS)
	card_area.custom_minimum_size = Vector2(0, rows * (CARD_H + GAP))

	for i in range(count):
		var row := i / COLS
		var col := i % COLS
		var x := 150 + col * (CARD_W + GAP)
		var y := row * (CARD_H + GAP)

		var h := all_heroes[i]
		var card := HeroCard.new()
		card.hero_id = h.hero_id
		card.hero_name = h.hero_name
		card.max_hp = h.max_hp
		card.role_text = h.role
		card.position_text = h.position
		card.portrait_path = h.portrait_path
		card.position = Vector2(x, y)
		card.pressed.connect(_on_card_clicked.bind(i))
		card_area.add_child(card)
		card_cards.append(card)
		card_data.append(i)


func _make_label(nm: String, text: String, size_px: int, color: Color, pos: Vector2, sz: Vector2, parent: Node) -> Label:
	var lbl := Label.new()
	lbl.name = nm
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = pos
	lbl.size = sz
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	FontManager.apply(lbl, size_px)
	lbl.add_theme_color_override("font_color", color)
	parent.add_child(lbl)
	return lbl


func _get_portrait_tex(portrait_path: String) -> Texture2D:
	if portrait_path == "" or not ResourceLoader.exists(portrait_path):
		return null
	if _portrait_cache.has(portrait_path):
		return _portrait_cache[portrait_path]
	var tex: Texture2D = load(portrait_path)
	_portrait_cache[portrait_path] = tex
	return tex


func _ensure_slot_portrait(slot: Panel, portrait_path: String) -> void:
	for child in slot.get_children():
		if child is TextureRect:
			var tex := _get_portrait_tex(portrait_path)
			if tex:
				(child as TextureRect).texture = tex
				(child as TextureRect).visible = true
			else:
				(child as TextureRect).visible = false
			return
	var tex := _get_portrait_tex(portrait_path)
	if tex:
		var portrait := TextureRect.new()
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		portrait.position = Vector2(4, 5)
		portrait.size = Vector2(40, 40)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait.texture = tex
		slot.add_child(portrait)


func _clear_slot_portrait(slot: Panel) -> void:
	for child in slot.get_children():
		if child is TextureRect:
			(child as TextureRect).visible = false


func _on_card_clicked(idx: int) -> void:
	if idx in banned or idx in p1_picks or idx in p2_picks:
		return
	selected_idx = idx if selected_idx != idx else -1
	_update_all_cards()
	confirm_btn.disabled = selected_idx < 0


func _update_all_cards() -> void:
	for i in range(card_cards.size()):
		var card := card_cards[i]
		var hero_idx: int = card_data[i]
		if hero_idx in banned:
			card.card_state = HeroCard.CardState.BANNED
		elif hero_idx in p1_picks:
			card.card_state = HeroCard.CardState.PICKED_P1
		elif hero_idx in p2_picks:
			card.card_state = HeroCard.CardState.PICKED_P2
		elif hero_idx == selected_idx:
			card.card_state = HeroCard.CardState.SELECTED
		else:
			card.card_state = HeroCard.CardState.NORMAL


func _update_previews() -> void:
	_update_slot_previews(0, p1_picks, p1_slots, p1_slot_labels)
	_update_slot_previews(1, p2_picks, p2_slots, p2_slot_labels)


func _update_slot_previews(player: int, picks: Array[int], slots: Array[Panel], labels: Array[Label]) -> void:
	for i in range(3):
		if i >= slots.size():
			continue
		var slot := slots[i]
		var label := labels[i]
		var sb := slot.get_theme_stylebox("panel", "Panel") as StyleBoxFlat
		if not sb:
			continue

		if i < picks.size():
			var h := all_heroes[picks[i]]
			_ensure_slot_portrait(slot, h.portrait_path)
			label.text = "%s\n❤%d" % [h.hero_name, h.max_hp]
			label.add_theme_color_override("font_color", Color.WHITE)
			sb.border_color = Color("#3388dd") if player == 0 else Color("#dd3333")
			sb.border_width_left = 3; sb.border_width_right = 3
			sb.border_width_top = 3; sb.border_width_bottom = 3
		else:
			_clear_slot_portrait(slot)
			label.text = "英雄 %d" % (i + 1)
			label.add_theme_color_override("font_color", Color("#aaaacc"))
			sb.border_color = Color("#444466")
			sb.border_width_left = 2; sb.border_width_right = 2
			sb.border_width_top = 2; sb.border_width_bottom = 2


func _enter_phase(new_phase: int) -> void:
	bp_timer.stop()
	phase = new_phase
	selected_idx = -1
	bp_timer_seconds = BP_TIME
	_update_all_cards()
	_update_previews()
	_update_phase_label()

	if phase == Phase.DONE:
		confirm_btn.visible = false
		timer_label.visible = false
		_start_battle()
	else:
		confirm_btn.visible = true
		confirm_btn.disabled = true
		confirm_btn.text = "确认选择"
		timer_label.visible = true
		_update_timer_label()
		bp_timer.start(1.0)


func _update_phase_label() -> void:
	var player := "P1" if _phase_player() == 0 else "P2"
	var action := "禁用" if _is_ban_phase() else "选择"
	var nth := ""
	match phase:
		Phase.P1_PICK1, Phase.P2_PICK1: nth = "第1个"
		Phase.P2_PICK2, Phase.P1_PICK2: nth = "第2个"
		Phase.P1_BAN3, Phase.P2_BAN3: nth = "第3个"
		Phase.P1_PICK3, Phase.P2_PICK3: nth = "第3个"
		Phase.P1_BAN1, Phase.P2_BAN1: nth = "第1个"
		Phase.P2_BAN2, Phase.P1_BAN2: nth = "第2个"

	phase_label.text = "%s — %s%s英雄" % [player, action, nth]
	var remaining := 0
	for i in range(all_heroes.size()):
		if not (i in banned or i in p1_picks or i in p2_picks):
			remaining += 1
	info_label.text = "可选: %d | 已禁: %d | P1: %d | P2: %d" % [remaining, banned.size(), p1_picks.size(), p2_picks.size()]


func _is_ban_phase() -> bool:
	return phase in [Phase.P1_BAN1, Phase.P2_BAN1, Phase.P2_BAN2, Phase.P1_BAN2, Phase.P1_BAN3, Phase.P2_BAN3]


func _phase_player() -> int:
	match phase:
		Phase.P1_BAN1, Phase.P1_PICK1, Phase.P1_BAN2, Phase.P1_PICK2, Phase.P1_BAN3, Phase.P1_PICK3:
			return 0
	return 1


func _on_bp_timer_tick() -> void:
	bp_timer_seconds -= 1
	_update_timer_label()
	if bp_timer_seconds <= 0:
		bp_timer.stop()
		_auto_random_select()


func _update_timer_label() -> void:
	timer_label.text = "剩余 %ds" % bp_timer_seconds
	if bp_timer_seconds <= 3:
		timer_label.add_theme_color_override("font_color", Color("#ff4444"))
	else:
		timer_label.add_theme_color_override("font_color", Color("#ffaa00"))


func _auto_random_select() -> void:
	var available: Array[int] = []
	for i in range(all_heroes.size()):
		if not (i in banned or i in p1_picks or i in p2_picks):
			available.append(i)
	if available.size() == 0:
		return
	selected_idx = available[randi_range(0, available.size() - 1)]
	_update_all_cards()
	_on_confirm()


func _on_confirm() -> void:
	bp_timer.stop()
	if selected_idx < 0:
		return
	match phase:
		Phase.P1_BAN1, Phase.P2_BAN1, Phase.P2_BAN2, Phase.P1_BAN2, Phase.P1_BAN3, Phase.P2_BAN3:
			banned.append(selected_idx)
		Phase.P1_PICK1, Phase.P1_PICK2, Phase.P1_PICK3:
			p1_picks.append(selected_idx)
		Phase.P2_PICK1, Phase.P2_PICK2, Phase.P2_PICK3:
			p2_picks.append(selected_idx)
	_enter_phase(phase + 1)


func _start_battle() -> void:
	var p1_lineup: Array[HeroData] = [
		all_heroes[p1_picks[0]],
		all_heroes[p1_picks[1]],
		all_heroes[p1_picks[2]],
	]
	var p2_lineup: Array[HeroData] = [
		all_heroes[p2_picks[0]],
		all_heroes[p2_picks[1]],
		all_heroes[p2_picks[2]],
	]
	get_tree().change_scene_to_file("res://src/ui/battle_screen.tscn")
	BattleSetup.p1_heroes = p1_lineup
	BattleSetup.p2_heroes = p2_lineup
