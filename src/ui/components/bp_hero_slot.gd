class_name BPHeroSlot
extends Panel

## BP 阶段阵容预览中的单个英雄槽位（像素化重做·任务2）：
##   左 = HeroFrame 像素方框头像（四角阵营宝石）；右 = 名字（白·加粗·描边·垂直居中）。
##   面板边框随阵营色（P1 蓝 / P2 红），填充时提亮。空位 = 框压暗 + "空位" 灰字。
##   （阵容栏不显示血量·任务2修订：血量信息留给卡池/战斗界面。）
## placeholder — 后期换美术素材时整体替换本 .tscn / .gd。

@export var player_color: Color = Color("#444466"):
	set(v):
		player_color = v
		if is_node_ready():
			_apply_player_color()

@onready var _frame: HeroFrame = $Frame
@onready var _name_label: Label = $NameLabel

static var _portrait_cache: Dictionary = {}


func _ready() -> void:
	_style_name()
	_apply_player_color()
	clear()


## 名字：像素字体·加粗·深描边 → 在波动背景上清晰（修"太细/看不清"）。
func _style_name() -> void:
	FontManager.apply(_name_label, 16)
	var bold := FontVariation.new()
	bold.base_font = FontManager.f16
	bold.variation_embolden = 0.6
	_name_label.add_theme_font_override("font", bold)
	_name_label.add_theme_constant_override("outline_size", 4)
	_name_label.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.05, 0.95))
	_name_label.add_theme_constant_override("shadow_offset_y", 2)
	_name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))


## 用一个英雄填充槽位（头像 + 名字，边框提亮为阵营色）。
func set_hero(h: HeroData) -> void:
	if not is_node_ready():
		return
	_frame.visible = true
	_frame.is_dead = false
	_frame.player_color = player_color
	_frame.portrait_path = h.portrait_path
	_name_label.text = h.hero_name
	_name_label.add_theme_color_override("font_color", Color.WHITE)
	_set_border_active(true)


## 清空槽位（框压暗占位 + "空位"灰字，边框暗）。
func clear() -> void:
	if not is_node_ready():
		return
	_frame.visible = true
	_frame.portrait_path = ""
	_frame.is_dead = true          # 借用阵亡态 → 灰边/灰宝石占位（视觉="未填"）
	_name_label.text = "空位"
	_name_label.add_theme_color_override("font_color", Color(0.55, 0.57, 0.66))
	_set_border_active(false)


func _apply_player_color() -> void:
	if _frame:
		_frame.player_color = player_color
	# 已填充 = 框非阵亡态；据此决定边框是否提亮为阵营色。
	_set_border_active(_frame != null and not _frame.is_dead)


## 面板边框：inactive=暗中性；active=阵营色提亮。复制基础 stylebox 改 border_color/width。
func _set_border_active(active: bool) -> void:
	var base := get_theme_stylebox("panel", "Panel") as StyleBoxFlat
	if base == null:
		return
	var sb := base.duplicate() as StyleBoxFlat
	if active:
		sb.border_color = player_color
		sb.set_border_width_all(3)
	else:
		sb.border_color = Color(0.26, 0.27, 0.34)
		sb.set_border_width_all(2)
	add_theme_stylebox_override("panel", sb)
