extends Control

## Title screen + Ban/Pick with 10s countdown per phase. 1920x1080.

enum Phase {
	P1_BAN1, P2_BAN1, P1_PICK1, P2_PICK1,
	P2_BAN2, P1_BAN2, P2_PICK2, P1_PICK2,
	P1_BAN3, P2_BAN3, P1_PICK3, P2_PICK3,
	DONE
}

const CARD_W := 160
const CARD_H := 90
const COLS := 8
const GAP := 10
const BP_TIME := 10

var all_heroes: Array[HeroData] = []
var p1_picks: Array = []
var p2_picks: Array = []
var banned: Array = []
var phase: int = -1
var selected_idx: int = -1

var bp_root: Control
var phase_label: Label
var info_label: Label
var timer_label: Label
var confirm_btn: Button
var scroll: ScrollContainer
var card_area: Control
var card_buttons: Array[Button] = []
var card_data: Array = []
var p1_slots: Array[Panel] = []
var p1_slot_labels: Array[Label] = []
var p2_slots: Array[Panel] = []
var p2_slot_labels: Array[Label] = []

var bp_timer: Timer
var bp_timer_seconds: int = BP_TIME


func _ready() -> void:
	all_heroes = HeroData.create_pool_heroes()
	_build_title_ui()


func _build_title_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color("#1a1a2e")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := Label.new()
	title.text = "波波攒之王"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color("#f5c518"))
	title.position = Vector2(460, 300)
	title.size = Vector2(1000, 80)
	add_child(title)

	var subtitle := Label.new()
	subtitle.text = "1v1 同时回合制英雄对战"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.add_theme_color_override("font_color", Color("#888899"))
	subtitle.position = Vector2(460, 380)
	subtitle.size = Vector2(1000, 36)
	add_child(subtitle)

	var btn := Button.new()
	btn.text = "开始匹配"
	btn.add_theme_font_size_override("font_size", 32)
	btn.position = Vector2(810, 500)
	btn.size = Vector2(300, 80)
	btn.pressed.connect(_on_start_pressed)
	add_child(btn)


func _on_start_pressed() -> void:
	for c in get_children():
		c.queue_free()
	_build_bp_ui()
	_enter_phase(Phase.P1_BAN1)


func _build_bp_ui() -> void:
	bp_root = Control.new()
	bp_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bp_root)

	var bg := ColorRect.new()
	bg.color = Color("#1a1a2e")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bp_root.add_child(bg)

	phase_label = Label.new()
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_label.add_theme_font_size_override("font_size", 28)
	phase_label.add_theme_color_override("font_color", Color("#f5c518"))
	phase_label.position = Vector2(460, 10)
	phase_label.size = Vector2(1000, 40)
	bp_root.add_child(phase_label)

	info_label = Label.new()
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.add_theme_font_size_override("font_size", 16)
	info_label.add_theme_color_override("font_color", Color("#777799"))
	info_label.position = Vector2(460, 48)
	info_label.size = Vector2(1000, 22)
	bp_root.add_child(info_label)

	# Timer label
	timer_label = Label.new()
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 22)
	timer_label.add_theme_color_override("font_color", Color("#ffaa00"))
	timer_label.position = Vector2(810, 75)
	timer_label.size = Vector2(300, 30)
	bp_root.add_child(timer_label)

	_build_preview_panel(0, 30, 120)
	_build_preview_panel(1, 30, 350)

	scroll = ScrollContainer.new()
	scroll.position = Vector2(240, 120)
	scroll.size = Vector2(1650, 850)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bp_root.add_child(scroll)

	card_area = Control.new()
	scroll.add_child(card_area)

	_build_hero_cards()

	confirm_btn = Button.new()
	confirm_btn.text = "确认选择"
	confirm_btn.add_theme_font_size_override("font_size", 24)
	confirm_btn.position = Vector2(810, 970)
	confirm_btn.size = Vector2(300, 60)
	confirm_btn.pressed.connect(_on_confirm)
	bp_root.add_child(confirm_btn)

	bp_timer = Timer.new()
	bp_timer.one_shot = false
	bp_timer.timeout.connect(_on_bp_timer_tick)
	bp_root.add_child(bp_timer)


func _build_preview_panel(player: int, px: float, py: float) -> void:
	var color := Color("#3388dd") if player == 0 else Color("#dd3333")

	var title := Label.new()
	title.text = "P%d 阵容" % (player + 1)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", color)
	title.position = Vector2(px, py)
	title.size = Vector2(180, 28)
	bp_root.add_child(title)

	for i in range(3):
		var slot_y := py + 36 + i * 58
		var slot := Panel.new()
		slot.position = Vector2(px, slot_y)
		slot.size = Vector2(180, 50)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#1e1e36")
		sb.border_width_left = 2
		sb.border_width_right = 2
		sb.border_width_top = 2
		sb.border_width_bottom = 2
		sb.border_color = Color("#444466")
		sb.set_corner_radius_all(6)
		slot.add_theme_stylebox_override("panel", sb)
		bp_root.add_child(slot)

		var lbl := Label.new()
		lbl.text = "英雄 %d" % (i + 1)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color("#aaaacc"))
		lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot.add_child(lbl)

		if player == 0:
			p1_slots.append(slot)
			p1_slot_labels.append(lbl)
		else:
			p2_slots.append(slot)
			p2_slot_labels.append(lbl)


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
		var card := Button.new()
		card.position = Vector2(x, y)
		card.size = Vector2(CARD_W, CARD_H)
		card.pressed.connect(_on_card_clicked.bind(i))

		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#252540")
		sb.border_width_left = 2
		sb.border_width_right = 2
		sb.border_width_top = 2
		sb.border_width_bottom = 2
		sb.border_color = Color("#3a3a5a")
		sb.set_corner_radius_all(6)
		card.add_theme_stylebox_override("normal", sb)

		var sb_hover := sb.duplicate() as StyleBoxFlat
		sb_hover.bg_color = Color("#303055")
		sb_hover.border_color = Color("#5a5a8a")
		card.add_theme_stylebox_override("hover", sb_hover)

		_add_card_label(card, h.hero_name, 16, Color.WHITE, 8, 22)
		_add_card_label(card, "❤ %d" % h.max_hp, 14, Color("#ff6666"), 32, 20)
		_add_card_label(card, h.role, 12, _role_color(h.role), 54, 18)
		_add_card_label(card, h.position, 11, Color("#777799"), 70, 16)

		card_area.add_child(card)
		card_buttons.append(card)
		card_data.append(i)


func _add_card_label(card: Button, text: String, size: int, color: Color, y: float, h: float) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.position = Vector2(0, y)
	lbl.size = Vector2(CARD_W, h)
	card.add_child(lbl)


func _role_color(role: String) -> Color:
	match role:
		"进攻型": return Color("#dd4444")
		"防御型": return Color("#4488dd")
		"反制型": return Color("#dd8833")
		"经济型": return Color("#33aa33")
		"骗招型": return Color("#aa44aa")
		"爆发型": return Color("#dd3333")
		"赌博型": return Color("#ddaa33")
		"切换型": return Color("#33aaaa")
		"蓄势型": return Color("#8888cc")
	return Color("#888899")


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
	var available: Array = []
	for i in range(all_heroes.size()):
		if not _is_unavailable(i):
			available.append(i)
	if available.size() == 0:
		return
	selected_idx = available[randi_range(0, available.size() - 1)]
	_update_all_cards()
	_on_confirm()


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
	var remaining := _available_count()
	info_label.text = "可选: %d | 已禁: %d | P1: %d | P2: %d" % [remaining, banned.size(), p1_picks.size(), p2_picks.size()]


func _is_ban_phase() -> bool:
	return phase in [Phase.P1_BAN1, Phase.P2_BAN1, Phase.P2_BAN2, Phase.P1_BAN2, Phase.P1_BAN3, Phase.P2_BAN3]


func _phase_player() -> int:
	match phase:
		Phase.P1_BAN1, Phase.P1_PICK1, Phase.P1_BAN2, Phase.P1_PICK2, Phase.P1_BAN3, Phase.P1_PICK3:
			return 0
	return 1


func _available_count() -> int:
	var count := 0
	for i in range(all_heroes.size()):
		if not _is_unavailable(i):
			count += 1
	return count


func _is_unavailable(idx: int) -> bool:
	return idx in banned or idx in p1_picks or idx in p2_picks


func _on_card_clicked(idx: int) -> void:
	if _is_unavailable(idx):
		return
	selected_idx = idx if selected_idx != idx else -1
	_update_all_cards()
	confirm_btn.disabled = selected_idx < 0


func _update_all_cards() -> void:
	for i in range(card_buttons.size()):
		var btn := card_buttons[i]
		var hero_idx: int = card_data[i]
		var sb := btn.get_theme_stylebox("normal", "Button") as StyleBoxFlat
		if not sb:
			continue

		sb.bg_color = Color("#252540")
		sb.border_color = Color("#3a3a5a")
		sb.border_width_left = 2
		sb.border_width_right = 2
		sb.border_width_top = 2
		sb.border_width_bottom = 2

		if hero_idx in banned:
			sb.bg_color = Color("#1a1a1a")
			sb.border_color = Color("#442222")
		elif hero_idx in p1_picks:
			sb.border_color = Color("#4488ff")
			sb.border_width_left = 3
			sb.border_width_right = 3
			sb.border_width_top = 3
			sb.border_width_bottom = 3
		elif hero_idx in p2_picks:
			sb.border_color = Color("#ff4444")
			sb.border_width_left = 3
			sb.border_width_right = 3
			sb.border_width_top = 3
			sb.border_width_bottom = 3

		if hero_idx == selected_idx:
			sb.border_color = Color("#ffdd44")
			sb.border_width_left = 4
			sb.border_width_right = 4
			sb.border_width_top = 4
			sb.border_width_bottom = 4


func _update_previews() -> void:
	_update_player_preview(0, p1_picks, p1_slots, p1_slot_labels)
	_update_player_preview(1, p2_picks, p2_slots, p2_slot_labels)


func _update_player_preview(player: int, picks: Array, slots: Array[Panel], labels: Array[Label]) -> void:
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
			label.text = "%s\n❤%d" % [h.hero_name, h.max_hp]
			label.add_theme_color_override("font_color", Color.WHITE)
			sb.border_color = Color("#3388dd") if player == 0 else Color("#dd3333")
			sb.border_width_left = 3
			sb.border_width_right = 3
			sb.border_width_top = 3
			sb.border_width_bottom = 3
		else:
			label.text = "英雄 %d" % (i + 1)
			label.add_theme_color_override("font_color", Color("#aaaacc"))
			sb.border_color = Color("#444466")
			sb.border_width_left = 2
			sb.border_width_right = 2
			sb.border_width_top = 2
			sb.border_width_bottom = 2


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
