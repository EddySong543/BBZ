extends SceneTree

## 攻击表 VFX 修补（一次性·2026-07-15 Eddy 反馈）：
## ① h06 帧7-13：冲击波青蓝→绿主导（只动 VFX 不动角色——色相门 150-215° + 饱和/明度门·
##    角色橄榄绿/翠绿 ≤130° 天然带缺口不误伤）·色相 -55°（青 175→绿 120）。
## ② h06 帧11-13 / h17 帧7-12：冲击波怼格右缘被切平——「锯齿消散」修补：
##    逐行（3 行一组连贯）随机深度啃掉切口 + 残端 2px 半透明毛边 → 切平读成散掉（差不多就行·Eddy 原话）。
## 跑法：godot --headless --path . -s res://tools/fix_attack_vfx.gd（跑完 --import·tres 不用重建=区域没变）

const CELL := 256
const COLS := 4
const HUE_LO := 150.0 / 360.0
const HUE_HI := 215.0 / 360.0
const HUE_SHIFT := -55.0 / 360.0
const JAG_MAX := 14      # 锯齿最大啃深（px）
const JAG_BLOCK := 3     # 锯齿行组（连贯像素感）


func _init() -> void:
	# h06：帧7-13 换色（idx6-12）·帧11-13 修截断（idx10-12）
	_process_sheet("res://assets/sprites/heroes/h06/h06_attack.png",
		[6, 7, 8, 9, 10, 11, 12], [10, 11, 12])
	# h17：帧7-12 修截断（idx6-11）·不换色
	_process_sheet("res://assets/sprites/heroes/h17/h17_attack.png",
		[], [6, 7, 8, 9, 10, 11])
	quit()


func _process_sheet(path: String, recolor_idx: Array, repair_idx: Array) -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null:
		print("FAIL 加载失败: ", path)
		return
	img.convert(Image.FORMAT_RGBA8)
	for idx: int in recolor_idx:
		var n := _recolor_cell(img, idx)
		print("[%s] 帧%d 换色 %d px" % [path.get_file(), idx + 1, n])
	for idx: int in repair_idx:
		var n := _repair_cell(img, idx)
		print("[%s] 帧%d 右缘消散修补 %d px" % [path.get_file(), idx + 1, n])
	var err := img.save_png(ProjectSettings.globalize_path(path))
	print("[%s] 保存 (err=%d)" % [path.get_file(), err])


## 换色：格内青蓝带（150-215°·s>0.20·v>0.25）色相 -55° → 绿主导。角色绿 ≤130° 不进门。
func _recolor_cell(img: Image, idx: int) -> int:
	var x0 := (idx % COLS) * CELL
	var y0 := (idx / COLS) * CELL
	var n := 0
	for y in range(y0, mini(y0 + CELL, img.get_height())):
		for x in range(x0, mini(x0 + CELL, img.get_width())):
			var c := img.get_pixel(x, y)
			if c.a <= 0.0 or c.s <= 0.20 or c.v <= 0.25:
				continue
			if c.h >= HUE_LO and c.h <= HUE_HI:
				img.set_pixel(x, y, Color.from_hsv(fposmod(c.h + HUE_SHIFT, 1.0), c.s, c.v, c.a))
				n += 1
	return n


## 右缘锯齿消散：切口列有实像素才动。逐行组随机啃深（确定性 hash·可重跑）+残端 2px 半透明。
func _repair_cell(img: Image, idx: int) -> int:
	var x0 := (idx % COLS) * CELL
	var y0 := (idx / COLS) * CELL
	var x_edge := mini(x0 + CELL, img.get_width()) - 1
	var touched := false
	for y in range(y0, mini(y0 + CELL, img.get_height())):
		if img.get_pixel(x_edge, y).a > 0.1:
			touched = true
			break
	if not touched:
		return 0
	var n := 0
	for y in range(y0, mini(y0 + CELL, img.get_height())):
		var t := fposmod(sin(float((y - y0) / JAG_BLOCK) * 12.9898 + float(idx) * 78.233) * 43758.5453, 1.0)
		var depth := 2 + int(t * float(JAG_MAX - 2))   # 每行组啃 2..14px
		for d in depth:
			var x := x_edge - d
			if x < x0:
				break
			if img.get_pixel(x, y).a > 0.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				n += 1
		for d in range(depth, depth + 2):   # 残端 2px 半透明毛边
			var x := x_edge - d
			if x < x0:
				break
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				img.set_pixel(x, y, Color(c.r, c.g, c.b, c.a * 0.45))
				n += 1
	return n
