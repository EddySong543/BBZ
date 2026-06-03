@tool
class_name ArcHealthBar
extends Node2D

## 纯代码绘制的弧形分格血条（无任何贴图）。
##
## 形状：1/4 圆弧（左上象限◜ 或镜像右上象限◝）。圆心 = 本节点原点(position)，
## 半径/角度固定写死；格子数 N = ceil(max_hp)，N 只改变分格疏密，弧整体形状恒定。
##
## 像素：硬边"方块拼弧"——遍历 pixel_scale 网格，对每块用 step/floor 判定是否在弧带内、
## 第几格、什么状态，填 pixel_scale×pixel_scale 的实心方块。无抗锯齿、无贴图、对齐网格，
## 颗粒度与角色像素一致（pixel_scale 应≈角色有效放大倍数，Inspector 可调）。
##
## 血量：set_health(cur_hp, max_hp)，半点制。从起点(12点)向侧边依次填：满格/半格/空格。
## 半格 = 该格沿弧长一分为二，靠起点半边满色、靠末端半边空色，硬分界。
## 掉血时格子变暗不消失（位置保留）。变更只重算每格状态并 queue_redraw，布局不重算。

@export_group("形状")
## 弧整体跨度（度），写死恒定。不同 N 只改每格角度 = span/N，弧形状不变。
@export var span_degrees: float = 90.0:
	set(v):
		span_degrees = v
		queue_redraw()
## 内半径（物理像素）。
@export var inner_radius: float = 46.0:
	set(v):
		inner_radius = v
		queue_redraw()
## 外半径（物理像素）。外 - 内 = 弧带厚度。
@export var outer_radius: float = 74.0:
	set(v):
		outer_radius = v
		queue_redraw()
## 镜像：false = 左上象限◜（左侧角色）；true = 右上象限◝（右侧角色）。
@export var mirror: bool = false:
	set(v):
		mirror = v
		queue_redraw()
## 掉血方向：true = 从上(12点)往下空（满格锚定侧边端）；false = 从侧边往上空。
@export var drain_from_top: bool = true:
	set(v):
		drain_from_top = v
		queue_redraw()
## 仅画填充：true=正常画自带外框；false=不画外圈环/封口casing（外框交给美术素材
## healthBar.png），只画血珠+分格分隔线，叠进美术凹槽里。
@export var draw_frame: bool = true:
	set(v):
		draw_frame = v
		queue_redraw()

@export_group("像素")
## 一个"血条像素" = pixel_scale × pixel_scale 物理像素（应≈角色放大倍数，保证颗粒一致）。
@export_range(1, 8) var pixel_scale: int = 2:
	set(v):
		pixel_scale = maxi(v, 1)
		queue_redraw()

@export_group("配色")
@export var full_color: Color = Color("e5443c"):       # 满格暖 crimson
	set(v):
		full_color = v
		queue_redraw()
@export var full_highlight: Color = Color("ff6a5c"):   # 满格内侧高光（亮一档）
	set(v):
		full_highlight = v
		queue_redraw()
@export var empty_fill: Color = Color("0b101f"):       # 空格夜墨槽
	set(v):
		empty_fill = v
		queue_redraw()
@export var stroke_color: Color = Color("d5d9e0"):     # 描边/分隔 浅灰白
	set(v):
		stroke_color = v
		queue_redraw()
@export var warn_color: Color = Color("ff9442"):       # 低血警示橘（描边转橘）
	set(v):
		warn_color = v
		queue_redraw()
## 当前血量 ≤ 此值(HP) 时描边转橘警示（颜色不是唯一信号）。
@export var warn_threshold: float = 1.0

@export_group("编辑器预览")
## @tool 下无血量数据时用这组值预览，便于编辑器里可视化摆位/调形；运行时被实际血量覆盖。
@export var preview_max: float = 6.0:
	set(v):
		preview_max = v
		queue_redraw()
@export var preview_cur: float = 4.5:
	set(v):
		preview_cur = v
		queue_redraw()

var _cur: float = 0.0
var _max: float = 0.0


## 设置血量（显示用 HP，半点制，如 3.5 / 6）。只更新状态 + 重绘，布局不重算。
func set_health(cur_hp: float, max_hp: float) -> void:
	_cur = maxf(cur_hp, 0.0)
	_max = maxf(max_hp, 0.0)
	queue_redraw()


func _draw() -> void:
	var mx := _max
	var cr := _cur
	if Engine.is_editor_hint() and mx <= 0.0:               # 编辑器无血量数据 → 用预览值，方便可视化摆位/调形
		mx = preview_max
		cr = preview_cur
	if mx <= 0.0:
		return
	var n := ceili(mx)
	if n <= 0:
		return
	var sp := float(pixel_scale)
	var span := deg_to_rad(span_degrees)
	if span <= 0.0 or outer_radius <= inner_radius:
		return

	var a_top := -PI / 2.0                                  # 12 点（正上）
	var mid_r := (inner_radius + outer_radius) * 0.5
	var low := cr > 0.0 and cr <= warn_threshold
	var stroke := warn_color if low else stroke_color

	# 包围盒（相对圆心=本节点原点）：仅扫描对应象限，量化到 pixel_scale 网格
	var x0 := 0.0 if mirror else -outer_radius
	var x1 := outer_radius if mirror else 0.0
	var by := floorf(-outer_radius / sp) * sp
	while by <= 0.0:
		var bx := floorf(x0 / sp) * sp
		while bx <= x1:
			var px := bx + sp * 0.5
			var py := by + sp * 0.5
			var r := sqrt(px * px + py * py)
			if r >= inner_radius and r <= outer_radius:
				var ang := atan2(py, px)
				var t := (ang - a_top) / span if mirror else (a_top - ang) / span
				if drain_from_top:
					t = 1.0 - t                             # 满格锚定侧边端 → 掉血从 12 点往下空
				if t >= 0.0 and t <= 1.0:
					draw_rect(Rect2(bx, by, sp, sp), _block_color(t, r, n, cr, sp, mid_r, span, stroke))
			bx += sp
		by += sp


## 单个方块的颜色：描边(环/分隔/封口) > 三态填充。
func _block_color(t: float, r: float, n: int, cur: float, sp: float, mid_r: float, span: float, stroke: Color) -> Color:
	var seg := clampi(floori(t * float(n)), 0, n - 1)
	var t_in_seg := t * float(n) - float(seg)               # 段内位置 0..1（0=靠起点）
	# 分隔/封口阈值按"本块所在半径"算 → 每个半径恰好覆盖 1 方块，分隔线沿半径连续不断（修缝隙）
	var bdt := (sp / maxf(r, 1.0)) / span                   # 本半径处一个方块占的 t（全局）
	var is_ring := r > outer_radius - sp or r < inner_radius + sp
	var at_seg_start := t_in_seg < bdt * float(n)
	var is_global_end := t > 1.0 - bdt
	if draw_frame:
		if is_ring or at_seg_start or is_global_end:
			return stroke
	elif at_seg_start and seg > 0:
		# 仅画填充模式：外圈环/封口由美术框提供，这里只留分格间的分隔线分开血珠
		return stroke
	# 三态填充
	match _seg_state(seg, cur):
		1:                                                  # 满（内侧高光）
			return full_highlight if r < mid_r else full_color
		2:                                                  # 半（靠起点半边满色、靠末端半边空色，硬分界）
			return full_color if t_in_seg < 0.5 else empty_fill
		_:                                                  # 空
			return empty_fill


## 段状态：0=空 1=满 2=半。从起点(12点)依次填。半点制下小数恒为 0 或 0.5。
func _seg_state(seg: int, cur: float) -> int:
	var full_n := floori(cur)
	if seg < full_n:
		return 1
	if seg == full_n and (cur - float(full_n)) >= 0.5:
		return 2
	return 0
