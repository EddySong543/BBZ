extends Node2D

## 占位"刀光"特效 — 程序化绘制一道白色弧形扫击，无需美术资源。
## 正式版（A 方案）会换成"按武器分类"的共用贴图特效（刀=弧光/枪=直刺线/法杖=能量爆）。
## 这里只为验证"概念读不读得出来"，所以纯代码画。

@export var radius: float = 150.0       # 弧线半径
@export var thickness: float = 60.0     # 刀光宽度
@export var span_deg: float = 130.0     # 扫击总角度
@export var base_rotation_deg: float = -120.0  # 起始角（朝左下扫向右上）
@export var duration: float = 0.18      # 生命周期（秒）
@export var color: Color = Color(1, 1, 1, 1)

var _t: float = 0.0          # 0→1 生命进度
var _playing: bool = false


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
	# 弧从 0 扫到 span（随进度推进）；后段淡出
	var sweep: float = clampf(_t * 1.4, 0.0, 1.0)
	var fade: float = 1.0 - smoothstep(0.55, 1.0, _t)
	var a0: float = deg_to_rad(base_rotation_deg)
	var a1: float = a0 + deg_to_rad(span_deg) * sweep
	var steps: int = 24
	var r_out: float = radius + thickness * 0.5
	var r_in: float = radius - thickness * 0.5
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(steps + 1):
		var a: float = lerpf(a0, a1, float(i) / float(steps))
		pts.append(Vector2(cos(a), sin(a)) * r_out)
	for i in range(steps + 1):
		var a: float = lerpf(a1, a0, float(i) / float(steps))
		pts.append(Vector2(cos(a), sin(a)) * r_in)
	var c: Color = color
	c.a *= fade
	draw_colored_polygon(pts, c)
