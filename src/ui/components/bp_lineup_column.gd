class_name BPLineupColumn
extends Control

## BP 对峙阵容柱（BP 重做 1A 决议）：屏幕左右缘各一根，标题 + 3 个竖排槽。
## 每槽 = HeroFrame 像素框头像 + 名字 —— 与战斗 HUD 阵容同一套视觉语言。
## 我方柱：PICK 阶段实时显示当前勾选；对手柱：REVEAL 前盖牌呼吸（对手同时盲选中），
## REVEAL 时逐槽翻面亮相（盲选揭幕演出）。
## placeholder —— 后期换美术素材时整体替换本 .tscn / .gd。

const P1_COLOR := Color("#3388dd")
const P2_COLOR := Color("#dd3333")
const EMPTY_TEXT := "空位"
const FACEDOWN_TEXT := "？？？"

@export_enum("P1:0", "P2:1") var player: int = 0:
	set(v):
		player = v
		if is_node_ready():
			_apply_player_style()

@onready var _title: Label = $TitleLabel

var _slots: Array[Control] = []
var _frames: Array[HeroFrame] = []
var _names: Array[Label] = []
var _breaths: Array = []   # 每槽盖牌呼吸 Tween（无则 null）


func _ready() -> void:
	for n in ["Slot0", "Slot1", "Slot2"]:
		var s := get_node(n) as Control
		_slots.append(s)
		_frames.append(s.get_node("Frame") as HeroFrame)
		_names.append(s.get_node("Name") as Label)
		_breaths.append(null)
	_style_labels()
	_apply_player_style()
	clear_all()


## 用 picks（英雄索引数组）+ all_heroes 填充槽位；不足的槽位显示空状态。
func set_picks(picks: Array, all_heroes: Array) -> void:
	if not is_node_ready():
		return
	for i in range(_slots.size()):
		if i < picks.size():
			_set_slot_hero(i, all_heroes[picks[i]])
		else:
			_set_slot_empty(i)


## 全部槽位清空（空位态）。
func clear_all() -> void:
	for i in range(_slots.size()):
		_set_slot_empty(i)


## 全部槽位盖牌（对手同时盲选中：阵营色框呼吸 + ？？？）。
func set_facedown_all() -> void:
	for i in range(_slots.size()):
		_set_slot_facedown(i)


## 盲选揭幕：逐槽翻面亮相（scale.x 收拢 → 换内容 → 回弹张开），错落 0.12s。
func reveal_picks(picks: Array, all_heroes: Array) -> void:
	var delay := 0.0
	for i in range(_slots.size()):
		var s := _slots[i]
		s.pivot_offset = s.size * 0.5
		var h: HeroData = all_heroes[picks[i]] if i < picks.size() else null
		var tw := create_tween()
		tw.tween_interval(delay)
		tw.tween_property(s, "scale:x", 0.0, 0.12)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(_fill_slot.bind(i, h))
		tw.tween_property(s, "scale:x", 1.0, 0.14)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		delay += 0.12


## 第 i 槽头像框的全局矩形（卡片"飞入"演出的落点）。
func get_slot_frame_rect(i: int) -> Rect2:
	if i < 0 or i >= _frames.size():
		return Rect2()
	return _frames[i].get_global_rect()


func _fill_slot(i: int, h: HeroData) -> void:
	if h != null:
		_set_slot_hero(i, h)
	else:
		_set_slot_empty(i)


func _set_slot_hero(i: int, h: HeroData) -> void:
	_kill_breath(i)
	var color := P1_COLOR if player == 0 else P2_COLOR
	_frames[i].is_dead = false
	_frames[i].player_color = color
	_frames[i].portrait_path = h.portrait_path
	_names[i].text = h.hero_name
	_names[i].add_theme_color_override("font_color", Color.WHITE)


func _set_slot_empty(i: int) -> void:
	_kill_breath(i)
	_frames[i].portrait_path = ""
	_frames[i].is_dead = true   # 借用阵亡态 → 灰边灰宝石占位（视觉="未填"，同旧阵容栏）
	_names[i].text = EMPTY_TEXT
	_names[i].add_theme_color_override("font_color", Color(0.55, 0.57, 0.66))


func _set_slot_facedown(i: int) -> void:
	_kill_breath(i)
	var color := P1_COLOR if player == 0 else P2_COLOR
	_frames[i].portrait_path = ""
	_frames[i].is_dead = false
	_frames[i].player_color = color
	_names[i].text = FACEDOWN_TEXT
	_names[i].add_theme_color_override("font_color", color.lightened(0.35))
	var tw := create_tween().set_loops()
	tw.tween_property(_frames[i], "modulate:a", 0.55, 0.8)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_frames[i], "modulate:a", 1.0, 0.8)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_breaths[i] = tw


func _kill_breath(i: int) -> void:
	var tw: Tween = _breaths[i]
	if tw != null and tw.is_valid():
		tw.kill()
	_breaths[i] = null
	_frames[i].modulate.a = 1.0


## 标题/名字：像素字体·加粗·深描边（波动背景上清晰，与旧阵容栏同标准）。
func _style_labels() -> void:
	FontManager.apply(_title, 20)
	var bold := FontVariation.new()
	bold.base_font = FontManager.f16
	bold.variation_embolden = 0.9
	_title.add_theme_font_override("font", bold)
	_title.add_theme_font_size_override("font_size", 20)
	_title.add_theme_constant_override("outline_size", 5)
	_title.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.05, 0.95))
	var name_bold := FontVariation.new()
	name_bold.base_font = FontManager.f16
	name_bold.variation_embolden = 0.6
	for lbl in _names:
		FontManager.apply(lbl, 16)
		lbl.add_theme_font_override("font", name_bold)
		lbl.add_theme_constant_override("outline_size", 4)
		lbl.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.05, 0.95))


func _apply_player_style() -> void:
	if _title == null:
		return
	var color := P1_COLOR if player == 0 else P2_COLOR
	_title.text = "你的阵容" if player == 0 else "对手阵容"
	_title.add_theme_color_override("font_color", color)
	for f in _frames:
		f.player_color = color
