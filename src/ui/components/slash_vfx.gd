class_name SlashVFX
extends Node2D

## 程序化斩击弧光（A 方案占位特效，无需美术资源）。
## 纯代码画一道弧形扫击；生命周期结束自动 queue_free。
## 用法：实例化 → 设 position/z_index/scale → 调 play()。
## 正式版可按武器分类换共用贴图特效（刀=弧光/枪=直刺/法杖=能量爆）。

@export var radius: float = 90.0        # 弧线半径（UI 尺度，比原型小）
@export var thickness: float = 36.0     # 刀光宽度
@export var span_deg: float = 130.0     # 扫击总角度
@export var base_rotation_deg: float = -120.0  # 起始角（朝左下扫向右上）
@export var duration: float = 0.18      # 生命周期（秒）
@export var color: Color = Color(1, 1, 1, 1)

var _t: float = 0.0
var _playing: bool = false
var _pts: PackedVector2Array = PackedVector2Array()   # 复用弧线顶点缓冲（避免每帧 _draw 分配）


func play() -> void:
	_t = 0.0
	_playing = true
	queue_redraw()


func _process(delta: float) -> void:
	if not _playing:
		return
	_t += delta / maxf(duration, 0.001)
	if _t >= 1.0:
		_playing = false
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	if _t <= 0.0:
		return
	var sweep: float = clampf(_t * 1.4, 0.0, 1.0)
	var fade: float = 1.0 - smoothstep(0.55, 1.0, _t)
	var a0: float = deg_to_rad(base_rotation_deg)
	var a1: float = a0 + deg_to_rad(span_deg) * sweep
	var steps: int = 24
	var r_out: float = radius + thickness * 0.5
	var r_in: float = radius - thickness * 0.5
	_pts.clear()
	for i in range(steps + 1):
		var a: float = lerpf(a0, a1, float(i) / float(steps))
		_pts.append(Vector2(cos(a), sin(a)) * r_out)
	for i in range(steps + 1):
		var a: float = lerpf(a1, a0, float(i) / float(steps))
		_pts.append(Vector2(cos(a), sin(a)) * r_in)
	var c: Color = color
	c.a *= fade
	draw_colored_polygon(_pts, c)
