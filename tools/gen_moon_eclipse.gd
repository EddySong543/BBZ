extends SceneTree

## 日食月亮资产生成器（Eddy 2026-07-10·加时赛"变天"月亮·Q2=暖金/紫两版供挑）：
##   96×96 像素源图（同 Scene1_moon.png 规格·场上 3× 放大）。
##   构成：暗盘（近黑带深靛余温+隐约环形山）+ 锯齿日冕环（角度噪声不均匀）
##       + 冕芒（若干束短光刺）+ 贝利珠（钻石环高光·破对称）+ 外圈淡晕。全部色阶化贴像素风。
##   godot --headless --path . --script res://tools/gen_moon_eclipse.gd
## 输出：assets/scenes/scene1/scene1_moon_eclipse_gold.png / _purple.png

const SIZE := 96
const CX := 47.5
const CY := 47.5
const R := 36.0                 # 暗盘半径
const BEAD_ANG := -0.66         # 贝利珠角度（右上·弧度）


func _init() -> void:
	_gen("gold", Color(1.0, 0.87, 0.56), Color(1.0, 0.6, 0.24), Color(1.0, 0.96, 0.85))
	_gen("purple", Color(0.8, 0.64, 1.0), Color(0.52, 0.34, 0.92), Color(0.95, 0.9, 1.0))
	print("MOON_ECLIPSE_DONE")
	quit(0)


func _hash(x: float) -> float:
	return fposmod(sin(x * 127.1 + 311.7) * 43758.5453, 1.0)


func _gen(suffix: String, c_in: Color, c_out: Color, c_bead: Color) -> void:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var bead := Vector2(CX + R * cos(BEAD_ANG), CY + R * sin(BEAD_ANG))
	for y in SIZE:
		for x in SIZE:
			var d := Vector2(x - CX, y - CY)
			var r := d.length()
			var ang := atan2(d.y, d.x)
			var col := Color(0, 0, 0, 0)
			# 日冕外径：24 扇区角度噪声（锯齿）+ 少数扇区拉长成冕芒
			var sector := floorf((ang + PI) / TAU * 24.0)
			var n := _hash(sector * 13.7)
			var ray := step_f(0.72, _hash(sector * 7.3)) * (5.0 + _hash(sector * 3.1) * 7.0)
			var r_out := R + 4.0 + n * 3.0 + ray
			if r <= R - 3.0:
				# 暗盘：近黑深靛 + 环形山微斑（6px 格噪声）
				var crater := step_f(0.82, _hash(floorf(x / 6.0) * 17.0 + floorf(y / 6.0) * 31.0)) * 0.05
				col = Color(0.045 + crater, 0.038 + crater, 0.085 + crater, 1.0)
			elif r <= R:
				# 盘缘：向边缘渐暖（被冕光烘出的一圈余温）
				var t := (r - (R - 3.0)) / 3.0
				t = floorf(t * 3.0) / 3.0
				var rim := Color(0.045, 0.038, 0.085).lerp(c_out * 0.35, t)
				col = Color(rim.r, rim.g, rim.b, 1.0)
			elif r <= r_out:
				# 日冕：内亮外深·色阶化 4 档
				var t2 := (r - R) / maxf(r_out - R, 0.001)
				t2 = floorf(t2 * 4.0) / 4.0
				var cc := c_in.lerp(c_out, t2)
				var a := (1.0 - t2 * 0.8)
				a = floorf(a * 4.0 + 0.5) / 4.0
				col = Color(cc.r, cc.g, cc.b, a)
			elif r <= r_out + 5.0:
				# 外圈淡晕（2 档）
				var t3 := (r - r_out) / 5.0
				var a2 := (1.0 - t3) * 0.22
				a2 = floorf(a2 * 2.0 + 0.5) / 2.0 * 0.22
				col = Color(c_out.r, c_out.g, c_out.b, a2)
			# 贝利珠：钻石环高光（覆盖在最上）
			var bd := (Vector2(x, y) - bead).length()
			if bd <= 2.6:
				col = Color(c_bead.r, c_bead.g, c_bead.b, 1.0)
			elif bd <= 5.0:
				var ba := (1.0 - (bd - 2.6) / 2.4) * 0.7
				ba = floorf(ba * 3.0 + 0.5) / 3.0
				if ba > col.a:
					col = Color(c_bead.r, c_bead.g, c_bead.b, ba)
			img.set_pixel(x, y, col)
	var path := "res://assets/scenes/scene1/scene1_moon_eclipse_%s.png" % suffix
	img.save_png(path)
	print("saved: ", path)


func step_f(edge: float, v: float) -> float:
	return 1.0 if v >= edge else 0.0
