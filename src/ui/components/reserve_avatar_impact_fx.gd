class_name ReserveAvatarImpactFx
extends Control

## 小尺寸替补头像的局部受击标记：沿既有菱形轮廓向外扩散一圈像素块。
## 不填黑底、不震整排，也不替代公共伤害数字。

const OUTLINE: Color = Color("211b1a")
const EDGE_SAMPLES: int = 6

var impact_color: Color = Color("d8c8b2")
var progress: float = 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()


func configure(color: Color) -> void:
	impact_color = color
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	progress = 0.0


func play(duration: float = 0.34) -> Tween:
	var tween := create_tween().set_ignore_time_scale(true)
	tween.tween_property(self, "progress", 1.0, maxf(0.01, duration)) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(queue_free)
	return tween


func debug_visible_block_count() -> int:
	return EDGE_SAMPLES * 4 if progress > 0.0 and progress < 1.0 else 0


func _draw() -> void:
	if progress <= 0.0 or progress >= 1.0:
		return
	var spread := roundf(lerpf(1.0, 12.0, progress))
	var alpha := pow(1.0 - progress, 0.72)
	var center := size * 0.5
	var half_extents := size * 0.5 + Vector2.ONE * spread
	var corners: Array[Vector2] = [
		center + Vector2(0.0, -half_extents.y),
		center + Vector2(half_extents.x, 0.0),
		center + Vector2(0.0, half_extents.y),
		center + Vector2(-half_extents.x, 0.0),
	]
	var block_size := 6.0 if progress < 0.52 else 4.0
	for edge: int in 4:
		var from_point := corners[edge]
		var to_point := corners[(edge + 1) % 4]
		for sample: int in EDGE_SAMPLES:
			var edge_t := (float(sample) + 0.5) / float(EDGE_SAMPLES)
			_draw_block(from_point.lerp(to_point, edge_t).round(), block_size, alpha)


func _draw_block(center: Vector2, block_size: float, alpha: float) -> void:
	var rect := Rect2(
		(center - Vector2.ONE * block_size * 0.5).round(),
		Vector2.ONE * block_size)
	draw_rect(rect.grow(2.0), Color(OUTLINE, alpha * 0.92))
	draw_rect(rect, Color(impact_color, alpha))
