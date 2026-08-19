extends SceneTree

## 鼠标指针生成器（G 件·2026-07-15 Eddy 选 B「族语化经典箭头」·程序自产零外部资产）：
## 沿革：v2 暖色 → v3 尾腿顺斜方切 → v4 去尾箭镞（外形 Eddy ✅）→ v5 悬停手型⛔（读作竖中指）→
## **v8 柔和小号版（2026-08-17）**：两态箭镞完全同形同色；悬停不再套一整圈粗金壳，
## 只在箭镞右下受光侧保留 1 设计格金色偏移边。金色负责提示“可点”，近黑轮廓仍负责勾形，
## 因而不会把小光标读成双层徽章。内芯改为中性暖灰米白，避开旧版脏黄与纯白刺眼两端；
## 箭镞实显尺寸约缩小 25%。⛔变暗⛔换形⛔柔化边缘。
## 常态双色=柔和米白内填充 #E8E4DA + 近黑描边 #130C08；悬停态额外增加右下金边 #DCA12E。
## 18×18 设计网格 ×2 = 36×36 成品（描边/偏移金边各 1 设计格=2 成品px）。
## 跑法：godot --headless --path . -s res://tools/gen_ui_cursor.gd
## 输出：assets/ui/cursor_arrow.png / cursor_hand.png（文件名沿用 POINTING_HAND 槽位名·实际=箭镞+金晕）
## + stdout 打 hotspot（两态同=近黑描边尖端·偏移金边不动内容=悬停切换零跳动）。
## ⚠ 覆盖同路径贴图后必须跑 --import（老规矩）。悬停想退回"什么都不变"：transition_manager
## 把 POINTING_HAND 注册指向 CURSOR_ARROW 即可。

const GRID := 18
const SCALE := 2
const BODY := Color("E8E4DA")   # 中性暖灰米白：不脏黄、不刺眼
const RIM := Color("130C08")    # 近黑描边（悬停框族近黑·亮纸上勾形）
const HALO := Color("DCA12E")   # 悬停右下偏移金边（沿用图鉴选中金色）

# 箭镞形状表（v4 轮廓语言的小号重绘·设计格行段表 y -> [x_start, x_end]）：
# 头三角（尖 (3,2)·45° 斜边·左缘垂直）+跟部收锋 (3,12)·⛔尾腿。
const ARROW_SPANS := {
	2:  [[3, 3]],
	3:  [[3, 4]],
	4:  [[3, 5]],
	5:  [[3, 6]],
	6:  [[3, 7]],
	7:  [[3, 8]],
	8:  [[3, 9]],
	9:  [[3, 10]],
	10: [[3, 5]],
	11: [[3, 4]],
	12: [[3, 3]],
}


func _init() -> void:
	var body_px := {}
	for y: int in ARROW_SPANS:
		for span: Array in ARROW_SPANS[y]:
			for x in range(int(span[0]), int(span[1]) + 1):
				body_px[Vector2i(x, y)] = true
	var rim_px := _shell(body_px, body_px)
	var solid := body_px.duplicate()
	solid.merge(rim_px)
	var halo_px := _directional_hover_edge(solid)

	for variant: Array in [["cursor_arrow", false], ["cursor_hand", true]]:
		var img := Image.create(GRID * SCALE, GRID * SCALE, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		if variant[1]:
			for p: Vector2i in halo_px:
				_put(img, p, HALO)
		for p: Vector2i in rim_px:
			_put(img, p, RIM)
		for p: Vector2i in body_px:
			_put(img, p, BODY)
		var path := "res://assets/ui/%s.png" % variant[0]
		img.save_png(ProjectSettings.globalize_path(path))
		print("saved: %s  hotspot: %s" % [path, _rim_tip(img)])
	quit()


## 悬停金边只取实体向右下偏移的一格：长斜边和尾部转折会自然亮起，左缘与顶部保持干净。
## 这是硬像素偏移边，不使用模糊、透明渐变或完整第二圈轮廓。
func _directional_hover_edge(solid: Dictionary) -> Dictionary:
	var out := {}
	for p: Vector2i in solid:
		var n := p + Vector2i(1, 1)
		if not solid.has(n):
			out[n] = true
	return out


## 外壳：base 的 8 邻域中不属于 exclude 的格（用于近黑描边）。
func _shell(base: Dictionary, exclude: Dictionary) -> Dictionary:
	var out := {}
	for p: Vector2i in base:
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				var n := p + Vector2i(dx, dy)
				if not exclude.has(n):
					out[n] = true
	return out


## hotspot（成品像素坐标）＝近黑描边最靠左上像素（x+y 最小·并列取 y 小）＝箭镞尖端。
## 两态同值：金晕只占透明区、描边/身像素坐标不动 → 悬停切换箭头零跳动、点击点不漂。
func _rim_tip(img: Image) -> Vector2i:
	var best := Vector2i(9999, 9999)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.5 and c.to_html(false) == RIM.to_html(false):
				if x + y < best.x + best.y or (x + y == best.x + best.y and y < best.y):
					best = Vector2i(x, y)
	return best


func _put(img: Image, p: Vector2i, col: Color) -> void:
	for dy in SCALE:
		for dx in SCALE:
			var px := p.x * SCALE + dx
			var py := p.y * SCALE + dy
			if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
				img.set_pixel(px, py, col)
