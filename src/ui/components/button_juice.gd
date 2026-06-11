class_name ButtonJuice
extends Node

## 挂为 [BaseButton] 的子节点，给父按钮加交互"手感"（收敛克制·去 Q弹）：
##   悬停 → 从中心轻微放大（平滑收敛，无过冲）；
##   按下 → 快速缩小（干脆按压感）；
##   松开 → 平滑回位；
##   选中 → 放大保持（外部调 [method set_selected]）。
##
## **职责单一**：只动父按钮的 scale + pivot。颜色(modulate) 完全留给外部
##   （选中亮蓝 / 确认暖金 / disabled 变暗），两者互不打架。
## 父按钮 disabled 时不反馈（保持原尺寸）。
##
## 用法（代码挂载）：
## [codeblock]
## var bj := ButtonJuice.new()
## bj.name = "ButtonJuice"
## button.add_child(bj)
## [/codeblock]

## 悬停放大倍率。（收敛：去 Q弹，幅度更克制）
@export var hover_scale: float = 1.035
## 按下缩小倍率（物理按压感，轻一点）。
@export var press_scale: float = 0.955
## 选中保持的放大倍率。
@export var selected_scale: float = 1.05
## 悬停 / 松开归位的时长（秒，短=干脆无回弹）。
@export var settle_time: float = 0.08
## 按下缩小的时长（秒，要快、干脆）。
@export var press_time: float = 0.05
## 基准缩放：父按钮常驻缩放 ≠ 1 时设置（如 BP 牌库卡 0.846），所有反馈倍率在其上相乘。
@export var base_scale: float = 1.0

var _btn: BaseButton
var _hovering: bool = false
var _pressing: bool = false
var _selected: bool = false
var _tween: Tween


func _ready() -> void:
	var par := get_parent()
	if par is BaseButton:
		_btn = par as BaseButton
		_btn.pivot_offset = _btn.size * 0.5
		_connect(_btn.mouse_entered, _on_enter)
		_connect(_btn.mouse_exited, _on_exit)
		_connect(_btn.button_down, _on_down)
		_connect(_btn.button_up, _on_up)
		_connect(_btn.resized, _on_resized)   # 编辑器摆位 / 布局变 → pivot 跟随


func _connect(sig: Signal, callable: Callable) -> void:
	if not sig.is_connected(callable):
		sig.connect(callable)


func _on_resized() -> void:
	if _btn:
		_btn.pivot_offset = _btn.size * 0.5


## 外部设置选中态（与 hover/press 叠加；选中时即便不悬停也保持放大）。
func set_selected(on: bool) -> void:
	if _selected == on:
		return
	_selected = on
	_apply(true)


func _on_enter() -> void:
	if _btn and _btn.disabled:
		return
	_hovering = true
	_apply(true)


func _on_exit() -> void:
	_hovering = false
	_pressing = false
	_apply(true)


func _on_down() -> void:
	if _btn and _btn.disabled:
		return
	_pressing = true
	_apply(false)   # 按下：快速干脆，不弹


func _on_up() -> void:
	_pressing = false
	_apply(true)    # 松开：弹性回弹


## 合成目标 scale 并 tween。bouncy=true 用 overshoot 弹性，false 用快速（按下）。
func _apply(bouncy: bool) -> void:
	if _btn == null:
		return
	var target := 1.0
	if _btn.disabled:
		target = 1.0
	elif _pressing:
		target = press_scale
	elif _selected:
		target = selected_scale * (1.02 if _hovering else 1.0)   # 选中再悬停略再大
	elif _hovering:
		target = hover_scale
	_btn.pivot_offset = _btn.size * 0.5
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	if bouncy:
		# 去回弹：短促直接归位(TRANS_QUAD EASE_OUT)，不软着陆、不过冲 —— 干脆稳重。
		_tween.tween_property(_btn, "scale", Vector2.ONE * (base_scale * target), settle_time)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		_tween.tween_property(_btn, "scale", Vector2.ONE * (base_scale * target), press_time)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
