extends Control

## Start screen with title, start button, and hero pick. 1920x1080.

var all_heroes: Array[HeroData] = []
var picks: Array[int] = [-1, -1]
var pick_buttons: Array[Button] = []
var title_label: Label
var start_button: Button
var pick_label: Label
var pick_container: Control


func _ready() -> void:
	all_heroes = HeroData.create_mvp_heroes()
	_build_ui()


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color("#1a1a2e")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	title_label = Label.new()
	title_label.text = "波波攒之王"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 64)
	title_label.add_theme_color_override("font_color", Color("#f5c518"))
	title_label.position = Vector2(460, 200)
	title_label.size = Vector2(1000, 80)
	add_child(title_label)

	start_button = Button.new()
	start_button.text = "开始匹配"
	start_button.add_theme_font_size_override("font_size", 32)
	start_button.position = Vector2(810, 450)
	start_button.size = Vector2(300, 80)
	start_button.pressed.connect(_on_start_pressed)
	add_child(start_button)

	# Pick UI (hidden initially)
	pick_container = Control.new()
	pick_container.visible = false
	pick_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(pick_container)

	var pick_bg := ColorRect.new()
	pick_bg.color = Color("#1a1a2e")
	pick_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pick_container.add_child(pick_bg)

	pick_label = Label.new()
	pick_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pick_label.add_theme_font_size_override("font_size", 36)
	pick_label.add_theme_color_override("font_color", Color.WHITE)
	pick_label.position = Vector2(460, 150)
	pick_label.size = Vector2(1000, 60)
	pick_container.add_child(pick_label)


func _on_start_pressed() -> void:
	start_button.visible = false
	title_label.text = "选择英雄"
	title_label.add_theme_font_size_override("font_size", 40)
	pick_container.visible = true
	_start_pick(0)


func _start_pick(player: int) -> void:
	_clear_pick_buttons()
	pick_label.text = "P%d - 选择英雄" % (player + 1)

	const BTN_W := 360
	const BTN_H := 140
	const GAP := 80
	var count := all_heroes.size()
	var total_w := count * BTN_W + (count - 1) * GAP
	var start_x := (1920.0 - total_w) / 2.0

	for i in range(count):
		if player == 1 and i == picks[0]:
			continue
		var h := all_heroes[i]
		var btn := Button.new()
		btn.text = "%s\nHP: %d\n%s" % [h.hero_name, h.max_hp, h.skill_description]
		btn.add_theme_font_size_override("font_size", 18)
		btn.position = Vector2(start_x + i * (BTN_W + GAP), 300)
		btn.size = Vector2(BTN_W, BTN_H)
		btn.pressed.connect(_on_hero_picked.bind(player, i))
		pick_container.add_child(btn)
		pick_buttons.append(btn)


func _clear_pick_buttons() -> void:
	for b in pick_buttons:
		b.queue_free()
	pick_buttons.clear()


func _on_hero_picked(player: int, hero_index: int) -> void:
	picks[player] = hero_index
	if player == 0:
		_start_pick(1)
	else:
		_start_battle()


func _start_battle() -> void:
	get_tree().change_scene_to_file("res://src/ui/battle_screen.tscn")
	BattleSetup.p1_hero = all_heroes[picks[0]]
	BattleSetup.p2_hero = all_heroes[picks[1]]
