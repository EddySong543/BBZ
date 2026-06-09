extends Control

## 头像框四角阵营宝石（独立节点，排在边框之上 → 稳定可见，不依赖 show_behind_parent）。
## 颜色由父 HeroFrame 通过 set("corner_color", ...) 按阵营设置 → 这是当前的敌我区分方式（边框统一中性色）。
## inset 较大 → 宝石落在头像内部、脱离边框；每颗宝石 = 暗边 + 阵营主体 + 高光核(三层菱形)。

@export var inset: float = 13.0
@export var radius: float = 4.0

## 款式基准尺寸：>0 时，inset/radius 视为"该尺寸框下的目标值"，实际绘制按当前框尺寸等比缩放 →
## 不同尺寸的框呈现一致的宝石比例（让 HUD 小框对齐被迫切换 120px 浮窗的精致款式）。
## =0（默认）时沿用绝对像素、不缩放（skill_card 图鉴卡等保持原样）。
@export var ref_size: float = 0.0:
	set(v):
		ref_size = v
		if is_node_ready():
			queue_redraw()

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
	# ref_size>0：按当前框尺寸相对基准等比缩放 inset/radius，让不同尺寸的框宝石比例一致
	# （HUD 72/68px 小框对齐被迫切换 120px 浮窗款式）。=0 时 s=1，沿用绝对像素。
	var s: float = (sz.x / ref_size) if ref_size > 0.0 else 1.0
	var ins: float = inset * s
	var rad: float = radius * s
	var cs := [
		Vector2(ins, ins),
		Vector2(sz.x - ins, ins),
		Vector2(ins, sz.y - ins),
		Vector2(sz.x - ins, sz.y - ins),
	]
	# 死亡：四角宝石对角连线成 X（逐格行走的干净像素台阶，与像素边框同格）；宝石再叠其上。
	if dead:
		_pixel_line(cs[0], cs[3], corner_color)   # ↘
		_pixel_line(cs[1], cs[2], corner_color)   # ↙
	for c in cs:
		_diamond(c, rad + 1.2 * s, Color(0.03, 0.03, 0.05, 0.85))  # 暗边(衬底)
		_diamond(c, rad, corner_color)                              # 阵营主体
		_diamond(c, rad * 0.42, corner_color.lightened(0.55))      # 高光核


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
