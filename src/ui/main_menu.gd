extends Control

## 主菜单（Main Menu）—— boot_screen 之后的主画面。
## 复用 scene1 夜景做活背景（鼠标视差）+ featured 角色 idle 展示 + 浮于夜空的菜单按钮。
## 展示角色为 @export 可换（对接未来"玩家更换角色"；换场景后续做）。
## 现仅"匹配对战"接入实际流程（→ bp_screen → 战斗），其余按钮占位（点击弹"敬请期待"）。

const BP_SCENE := "res://src/ui/bp_screen.tscn"
const HERO_DATA_DIR := "res://assets/data/heroes/"

## 左侧展示用英雄（未来玩家可换）。默认 h10 酉鸡。
@export var featured_hero_id: String = "h10"

@onready var _char_display: CharacterDisplay = $CharacterDisplay
@onready var _coming_soon: Label = $UI/ComingSoon

var _toast_tween: Tween


func _ready() -> void:
	_load_featured_hero()
	_setup_buttons()
	_coming_soon.modulate.a = 0.0
	_play_intro()


## 入场转场：承接 boot 决堤白幕 —— 全屏白幕淡出，主菜单从光中浮现（衔接 boot→menu，去硬切感）。
func _play_intro() -> void:
	var fade := ColorRect.new()
	fade.color = Color.WHITE
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.z_index = 4096   # 盖住一切，最后淡出
	add_child(fade)
	var tw := create_tween()
	tw.tween_interval(0.05)
	tw.tween_property(fade, "modulate:a", 0.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(fade.queue_free)


## 把 featured 英雄的 idle 立绘喂给左侧展示组件。
func _load_featured_hero() -> void:
	var path: String = HERO_DATA_DIR + featured_hero_id + ".tres"
	if not ResourceLoader.exists(path):
		push_warning("main_menu: 展示英雄数据不存在 " + path)
		return
	var hero: HeroData = load(path)
	if hero != null and hero.sprite_frames_path != "":
		_char_display.sprite_frames_path = hero.sprite_frames_path


func _setup_buttons() -> void:
	# 主行动：匹配对战 → 进入 BP 选人 → 战斗
	var match_btn: Button = $UI/MatchButton
	FontManager.apply_btn(match_btn, 40)
	match_btn.pressed.connect(_on_match_pressed)

	# 占位按钮（点击弹"敬请期待"）：[按钮, 功能名]
	var placeholders: Array = [
		[$UI/ProfileButton, "个人资料"],
		[$UI/SettingsButton, "设置"],
		[$UI/TowerButton, "爬塔模式"],
		[$UI/StoryButton, "故事模式"],
		[$UI/NavHeroes, "英雄"],
		[$UI/NavSquad, "小队"],
		[$UI/NavItems, "道具"],
		[$UI/NavShop, "商店"],
	]
	for entry in placeholders:
		var btn: Button = entry[0]
		FontManager.apply_btn(btn, 26)
		btn.pressed.connect(_on_placeholder_pressed.bind(entry[1]))

	FontManager.apply(_coming_soon, 40)


func _on_match_pressed() -> void:
	get_tree().change_scene_to_file(BP_SCENE)


## 占位功能提示：淡入 → 停留 → 淡出。
func _on_placeholder_pressed(feature: String) -> void:
	_coming_soon.text = feature + " · 敬请期待"
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_coming_soon.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(_coming_soon, "modulate:a", 1.0, 0.2)
	_toast_tween.tween_interval(0.9)
	_toast_tween.tween_property(_coming_soon, "modulate:a", 0.0, 0.4)
