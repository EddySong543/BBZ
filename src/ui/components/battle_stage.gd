class_name BattleStage
extends Control

## 多层视差对战舞台（屋顶夜战）。
##
## 各子节点通过 metadata `parallax_factor` 声明视差强度：
## 0 = 静止背景（天空），1 = 与舞台地面同步，>1 = 前景（飘叶等）。
## 脚本在 _ready 缓存各层基准位置，随后按 idle 漂移 / 命中抖动 / 可选鼠标视差
## 偏移各层位置。素材到位后，在编辑器里直接替换对应 TextureRect 的 texture
## 即可，无需改动脚本。
##
## 用法示例：
## [codeblock]
## @onready var stage: BattleStage = $BattleStage
## stage.shake(14.0)              # 命中/大招时抖屏（各层按视差强度分摊）
## stage.pointer_parallax = true  # 主菜单中开启鼠标视差
## [/codeblock]

## 是否启用明月/前景的缓慢 idle 漂移（让静态画面有呼吸感）。
@export var idle_drift: bool = true
## idle 漂移幅度（像素，乘以各层视差强度）。
@export var idle_amplitude: float = 6.0
## idle 漂移速度。
@export var idle_speed: float = 0.35
## 视为"静止参考平面"的视差强度（= 角色站立的地面层，通常 1.0）。
## idle 漂移与鼠标视差都以此层为零点：该层不漂移、与脚下角色同参考系，越远的层相对漂移越大。
## 注意：shake（受击震屏）不受此影响，仍全层按 parallax_factor 缩放跟抖。
@export var ground_parallax: float = 1.0
## 是否随鼠标做视差（适合主菜单；战斗中通常关闭）。
@export var pointer_parallax: bool = false
## 鼠标视差最大偏移（像素，乘以各层视差强度）。
@export var pointer_strength: float = 16.0
## 命中抖动衰减速度（越大停得越快）。
@export var shake_decay: float = 6.0
## 在 standalone 预览中点击鼠标触发一次抖动演示（集成进战斗后可关）。
@export var demo_click_shake: bool = true

var _layers: Array[Control] = []
var _bases: PackedVector2Array = PackedVector2Array()
var _factors: PackedFloat32Array = PackedFloat32Array()
var _time: float = 0.0
var _shake_amp: float = 0.0
var _pointer: Vector2 = Vector2.ZERO


func _ready() -> void:
	# 一次性缓存所有带 parallax_factor 的层及其基准位置（避免热路径查询/分配）。
	for child in get_children():
		if child is Control and child.has_meta("parallax_factor"):
			_layers.append(child)
			_bases.append(child.position)
			_factors.append(float(child.get_meta("parallax_factor")))


## 触发一次命中抖动；amp 为像素幅度（取较大值，不打断更强的抖动）。
func shake(amp: float) -> void:
	_shake_amp = maxf(_shake_amp, amp)


func _unhandled_input(event: InputEvent) -> void:
	if demo_click_shake and event is InputEventMouseButton and event.pressed:
		shake(16.0)


func _process(delta: float) -> void:
	_time += delta
	if _shake_amp > 0.0:
		_shake_amp = maxf(0.0, _shake_amp - shake_decay * delta * _shake_amp)
		if _shake_amp < 0.05:
			_shake_amp = 0.0

	if pointer_parallax:
		var vp: Vector2 = get_viewport_rect().size
		if vp.x > 0.0 and vp.y > 0.0:
			var m: Vector2 = get_local_mouse_position()
			_pointer = ((m / vp) - Vector2(0.5, 0.5)) * 2.0 * pointer_strength
	else:
		_pointer = Vector2.ZERO

	var drift_x: float = (sin(_time * idle_speed) * idle_amplitude) if idle_drift else 0.0
	var drift_y: float = (cos(_time * idle_speed * 0.7) * idle_amplitude * 0.5) if idle_drift else 0.0
	var shake_x: float = sin(_time * 57.0) * _shake_amp
	var shake_y: float = cos(_time * 43.0) * _shake_amp

	# idle 漂移 / 鼠标视差以 ground_parallax（地面层）为静止参考：地面 idle_f=0 不漂、
	# 与脚下角色同参考系；越远的层（factor 越小）相对漂移越大 → 自然纵深。
	# shake 则全层按 factor 缩放（受击瞬时震屏，近景抖得明显）。
	for i in _layers.size():
		var f: float = _factors[i]
		var idle_f: float = f - ground_parallax
		var off := Vector2(
			(drift_x - _pointer.x) * idle_f + shake_x * f,
			drift_y * idle_f + shake_y * f)
		_layers[i].position = _bases[i] + off
