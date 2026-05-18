extends Control

## BP (Ban/Pick) 屏（P1-4e: 从 start_screen 拆出）。
## 进入：title_screen StartButton 切场。
## 退出：BP 完成 → 设置 BattleSetup → 切场到 battle_screen。

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

@onready var phase_label: Label = $PhaseLabel
@onready var info_label: Label = $InfoLabel
@onready var timer_label: Label = $TimerLabel
@onready var p1_preview: BPPreviewPanel = $P1PreviewPanel
@onready var p2_preview: BPPreviewPanel = $P2PreviewPanel
@onready var card_area: Control = $CardScrollContainer/CardArea
@onready var confirm_btn: Button = $ConfirmButton
@onready var bp_timer: Timer = $BPTimer

var card_cards: Array[HeroCard] = []
var card_data: Array[int] = []
var bp_timer_seconds: int = BP_TIME


func _ready() -> void:
	all_heroes = HeroData.create_pool_heroes()
	_setup_ui()
	_enter_phase(Phase.P1_BAN1)


func _setup_ui() -> void:
	FontManager.apply(phase_label, 24)
	phase_label.add_theme_color_override("font_color", Color("#f5c518"))
	FontManager.apply(info_label, 16)
	info_label.add_theme_color_override("font_color", Color("#777799"))
	FontManager.apply(timer_label, 24)
	timer_label.add_theme_color_override("font_color", Color("#ffaa00"))
	FontManager.apply_btn(confirm_btn, 24)

	confirm_btn.pressed.connect(_on_confirm)
	bp_timer.one_shot = false
	bp_timer.timeout.connect(_on_bp_timer_tick)

	_build_hero_cards()


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
	p1_preview.set_picks(p1_picks, all_heroes)
	p2_preview.set_picks(p2_picks, all_heroes)


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
	var nth := "第%d个" % (phase / 4 + 1)

	phase_label.text = "%s — %s%s英雄" % [player, action, nth]
	var remaining := 0
	for i in range(all_heroes.size()):
		if not (i in banned or i in p1_picks or i in p2_picks):
			remaining += 1
	info_label.text = "可选: %d | 已禁: %d | P1: %d | P2: %d" % [remaining, banned.size(), p1_picks.size(), p2_picks.size()]


# P1-4f: 12 个 Phase 的数学规律（phase ∈ [0, 11]，DONE=12 不会调到这两个 helper）
# - 是否 ban：phase % 4 < 2（每 4 个一轮，前 2 个是 ban，后 2 个是 pick）
# - 哪方：第 2 轮 (phase / 4 == 1) P2 先，其他轮 P1 先；轮内 phase % 2 == 0 是先手

func _is_ban_phase() -> bool:
	return (phase % 4) < 2


func _phase_player() -> int:
	var round_starter := 1 if (phase / 4) == 1 else 0
	return round_starter ^ (phase % 2)


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
	# 必须先 set BattleSetup，再切场景；否则 battle_screen._ready() 可能拿到空 lineup
	BattleSetup.p1_heroes = p1_lineup
	BattleSetup.p2_heroes = p2_lineup
	get_tree().change_scene_to_file("res://src/ui/battle_screen.tscn")
