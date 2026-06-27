extends Control

## 道具格「祥云纹」装饰——**仅传说道具**用（背景层·在道具美术之下·不压美术）。
## 参 ref14 取神不照抄：四角各一朵干净涡卷云头（tone-on-tone 低对比·金压深金底），
## 中心大留白给道具美术。专业取向 = 工整、对称、克制，云纹只在四角衬底、不进中心。
## 用几何线条 _draw 画 → 螺旋干净可控（非 shader 噪声）。idle = 极轻呼吸明灭（错相位）。
## ⚠ 不用 class_name → 消费方 const ItemCellDeco := preload("res://src/ui/components/item_cell_deco.gd")。
## 用法：ItemCellDeco.add(parent, pos, size, idx)

const SELF_PATH := "res://src/ui/components/item_cell_deco.gd"

# ── 旋钮 ──
const GOLD := Color(0.97, 0.84, 0.50)   # 云纹金
const ALPHA := 0.20                      # tone-on-tone 低对比衬底（克制）
const CURL_R := 0.135                    # 四角涡卷半径（占 min(w,h) 比例）
const CURL_TURNS := 1.3                  # 螺旋圈数（云头打卷）
const INSET := 1.55                      # 涡卷心离角的内缩（×半径）
const BREATH_SPEED := 1.3
const BREATH_AMT := 0.16

var _w := 64.0
var _h := 64.0
var _phase := 0.0
var _t := 0.0


static func add(parent: Control, pos: Vector2, size: Vector2, idx: int = 0) -> Control:
	var d: Control = load(SELF_PATH).new()
	d.name = "CloudDeco"
	d.setup(pos, size, idx)
	parent.add_child(d)
	return d


func setup(pos: Vector2, sz: Vector2, idx: int) -> void:
	position = pos
	size = sz
	_w = sz.x
	_h = sz.y
	_phase = fmod(idx * 0.37, 1.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func _process(delta: float) -> void:
	_t += delta
	modulate.a = (1.0 - BREATH_AMT) + BREATH_AMT * sin(_t * BREATH_SPEED + _phase * TAU)


func _draw() -> void:
	var col := Color(GOLD.r, GOLD.g, GOLD.b, ALPHA)
	var lw: float = maxf(1.5, _w / 50.0)
	var rad: float = minf(_w, _h) * CURL_R
	var d: float = rad * INSET
	# 四角各一朵涡卷云头（对角同旋向·相邻镜像 → 对称工整）；只在角·不进中心
	_spiral(Vector2(d, d), rad, 1.0, PI * 0.25, col, lw)               # 左上
	_spiral(Vector2(_w - d, d), rad, -1.0, PI * 0.75, col, lw)         # 右上（镜像）
	_spiral(Vector2(d, _h - d), rad, -1.0, -PI * 0.25, col, lw)        # 左下（镜像）
	_spiral(Vector2(_w - d, _h - d), rad, 1.0, -PI * 0.75, col, lw)    # 右下


## 一朵涡卷云头：内→外的螺旋（dir=±1 旋向·start 起始角控开口朝向）。
func _spiral(c: Vector2, rad: float, dir: float, start: float, col: Color, lw: float) -> void:
	var pts := PackedVector2Array()
	var n := 26
	for i in n + 1:
		var t := i / float(n)
		var ang := start + dir * CURL_TURNS * TAU * t
		var r := rad * (0.16 + 0.84 * t)   # 半径由内向外长 → 螺旋
		pts.append(c + Vector2(cos(ang), sin(ang)) * r)
	draw_polyline(pts, col, lw, true)
