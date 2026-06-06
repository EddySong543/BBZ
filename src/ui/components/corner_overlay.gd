extends Control

## 头像框四角阵营宝石（独立节点，排在边框之上 → 稳定可见，不依赖 show_behind_parent）。
## 颜色由父 HeroFrame 通过 set("corner_color", ...) 按阵营设置 → 这是当前的敌我区分方式（边框统一中性色）。
## inset 较大 → 宝石落在头像内部、脱离边框；每颗宝石 = 暗边 + 阵营主体 + 高光核(三层菱形)。

@export var inset: float = 13.0
@export var radius: float = 4.0

@export var corner_color: Color = Color(0.5, 0.7, 1.0):
	set(v):
		corner_color = v
		if is_node_ready():
			queue_redraw()

## 死亡时：对角宝石连线成 X，强化"阵亡"含义。由父 HeroFrame 按 is_dead 设置。
var dead: bool = false:
	set(v):
		dead = v
		if is_node_ready():
			queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var sz := size
	var cs := [
		Vector2(inset, inset),
		Vector2(sz.x - inset, inset),
		Vector2(inset, sz.y - inset),
		Vector2(sz.x - inset, sz.y - inset),
	]
	# 死亡：四角宝石对角连线成 X（逐格行走的干净像素台阶，与像素边框同格）；宝石再叠其上。
	if dead:
		_pixel_line(cs[0], cs[3], corner_color)   # ↘
		_pixel_line(cs[1], cs[2], corner_color)   # ↙
	for c in cs:
		_diamond(c, radius + 1.2, Color(0.03, 0.03, 0.05, 0.85))  # 暗边(衬底)
		_diamond(c, radius, corner_color)                          # 阵营主体
		_diamond(c, radius * 0.42, corner_color.lightened(0.55))   # 高光核


func _diamond(c: Vector2, r: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(0.0, -r), c + Vector2(r, 0.0),
		c + Vector2(0.0, r), c + Vector2(-r, 0.0),
	]), col)


## 像素台阶连线：把 a、b 量化到「格坐标」，再逐格行走（每格恰一个方块）→ 干净 1 格宽台阶，
## 无重复格、无糊。block≈框宽/24，与像素边框同格。
func _pixel_line(a: Vector2, b: Vector2, col: Color) -> void:
	var block: float = maxf(round(size.x / 24.0), 3.0)
	var ca := Vector2(round(a.x / block), round(a.y / block))
	var cb := Vector2(round(b.x / block), round(b.y / block))
	var steps: int = int(maxf(absf(cb.x - ca.x), absf(cb.y - ca.y)))
	if steps <= 0:
		draw_rect(Rect2(ca.x * block, ca.y * block, block, block), col)
		return
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var cx: float = round(lerpf(ca.x, cb.x, t))
		var cy: float = round(lerpf(ca.y, cb.y, t))
		draw_rect(Rect2(cx * block, cy * block, block, block), col)
