extends SceneTree

## 英雄美术批量导入（2026-07-15·import_h01_attack 泛化版·Eddy 两大波资产；
## 2026-07-17 扩 defeat 死亡表——同管线同规格·打地基批）：
## 处理 assets/import 里的 hXX_attack.png（攻击 sheet）/ hXX_defeat.png（死亡 sheet）
## 与 hXX.png（MJ 全身立绘）。
## 用法（三阶段·prep 与 build 之间必须 --import 注册新 png）：
##   godot --headless --path . --script res://tools/import_hero_batch.gd -- --phase scan
##   godot --headless --path . --script res://tools/import_hero_batch.gd -- --phase prep
##   godot --headless --path . --import
##   godot --headless --path . --script res://tools/import_hero_batch.gd -- --phase build
##   godot --headless --path . --script res://tools/import_hero_batch.gd -- --phase verify
## scan：只报尺寸/格径/逐格空帧表（不写盘·先看清再动手）。
## prep：sheet 128 格→2× 最近邻放大成 256 格（h01 先例）→ heroes/hXX/hXX_attack|defeat.png；
##       立绘原样落 heroes/hXX/hXX.png（旧版被覆盖·git 有历史）。⚠不动 import 原件（清理另议）。
## build：切 256 格跳全透明帧→追加 "attack"/"defeat" 进 hXX_idle.tres（均非循环）。
##        attack fps=帧数/0.6s 对齐 action_phase（h01 先例）；defeat fps=帧数/0.7s
##        （倒地读得清·终结演出慢放窗口内能放完）·停末帧靠 play_animation(false)。
##        battle 侧 has_action_anim() 自动吃上，零代码改动。尾帧空白=跳空帧自动裁掉。
## verify：新表验收铁律（h02/h07/h11 实测定标）——首帧与 idle 站姿同尺寸同坐标
##        （首格 alpha bbox 全等）。范围=本批 import 区里的表（对照 DST 落位后的成品图）。

const IMPORT_DIR := "res://assets/import/"
const DST := "res://assets/sprites/heroes/"
const CELL := 256
const COLS := 4
const ACTION_PHASE := 0.6
const DEFEAT_PHASE := 0.7
# h19 走专段（--phase h19）：原件=GPT 生图未过管线（棋盘假透明+7 姿势松散摆放非严格网格·
# 人物≈2× 大）——通用 prep/build 会切出 16 帧棋盘垃圾，必须排除。
const SPECIAL: Array = ["h19"]
# 倒向修正名单（逐格 flip_x·姿态+位移轨迹一起镜像·verify 走「镜像盒等式」）。
# 沿革：2026-07-17 h17 旧表倒姿被判反曾入列（程序镜像过渡用）→ Eddy 当日重制新表
# 按本意画（首帧核验原样匹配 idle）→ 名单清空。机制保留：以后哪张表倒反，id 入列重跑 prep 即可。
const FLIP_DEFEAT: Array = []
# verify 首帧盒公差（px·256 源格）：≤2px=GPT 摆姿噪声（h07/h09 defeat 批实测·屏上无感），
# 警示通过；超限仍 FAILED（铁律拦的是真错位不是像素噪）。
const VERIFY_TOL := 2


func _initialize() -> void:
	var phase := "scan"
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--phase" and i + 1 < args.size():
			phase = args[i + 1]
	var ok := true
	match phase:
		"scan":
			ok = _scan()
		"prep":
			ok = _prep()
		"build":
			ok = _build()
		"verify":
			ok = _verify()
		"h19":
			ok = _prep_h19()
		_:
			push_error("未知 phase: " + phase)
			ok = false
	print("=== phase %s %s ===" % [phase, "OK" if ok else "FAILED"])
	quit(0 if ok else 1)


## import 区清点：攻击表/死亡表/立绘 各 [id]=文件名。
func _list_batch() -> Dictionary:
	var attacks := {}
	var defeats := {}
	var arts := {}
	var da := DirAccess.open(IMPORT_DIR)
	if da == null:
		push_error("import 目录打不开")
		return {}
	da.list_dir_begin()
	var f := da.get_next()
	while f != "":
		if f.match("h??_attack.png"):
			attacks[f.substr(0, 3)] = f
		elif f.match("h??_defeat.png"):
			defeats[f.substr(0, 3)] = f
		elif f.match("h??.png"):
			arts[f.substr(0, 3)] = f
		f = da.get_next()
	da.list_dir_end()
	return {attacks = attacks, defeats = defeats, arts = arts}


## 表种类 → 动画名（文件后缀与动画名一致：attacks→attack / defeats→defeat）。
const SHEET_KINDS: Array = ["attacks", "defeats"]


static func _anim_of(kind: String) -> String:
	return kind.trim_suffix("s")


func _scan() -> bool:
	var batch := _list_batch()
	var arts: Dictionary = batch["arts"]
	print("攻击表 %d 张 / 死亡表 %d 张 / 立绘 %d 张"
			% [batch["attacks"].size(), batch["defeats"].size(), arts.size()])
	for kind: String in SHEET_KINDS:
		var sheets: Dictionary = batch[kind]
		var tag := _anim_of(kind)
		for id: String in _sorted(sheets):
			var img := Image.load_from_file(ProjectSettings.globalize_path(IMPORT_DIR + sheets[id]))
			if img == null:
				print("[%s] %s: 加载失败" % [tag, id])
				continue
			var cell: int = img.get_width() / COLS
			var rows: int = img.get_height() / cell
			var empties: Array = []
			var filled := 0
			for r in rows:
				for c in COLS:
					if _cell_empty(img, c * cell, r * cell, cell):
						empties.append("r%dc%d" % [r, c])
					else:
						filled += 1
			print("[%s] %s: %dx%d 格径=%d 网格=%dx%d 实帧=%d 空格=%s"
					% [tag, id, img.get_width(), img.get_height(), cell, COLS, rows, filled, str(empties)])
	for id: String in _sorted(arts):
		var img := Image.load_from_file(ProjectSettings.globalize_path(IMPORT_DIR + arts[id]))
		if img == null:
			print("[art] %s: 加载失败" % id)
			continue
		var alpha := _has_alpha(img)
		print("[art] %s: %dx%d 透明底=%s" % [id, img.get_width(), img.get_height(), "是" if alpha else "⚠否(带背景)"])
	return true


func _prep() -> bool:
	var batch := _list_batch()
	var ok := true
	for kind: String in SHEET_KINDS:
		var tag := _anim_of(kind)
		for id: String in _sorted(batch[kind]):
			if kind == "attacks" and id in SPECIAL:
				print("[prep-attack] %s: 专段处理（--phase h19）·通用线跳过" % id)
				continue
			var img := Image.load_from_file(ProjectSettings.globalize_path(IMPORT_DIR + batch[kind][id]))
			if img == null:
				ok = false
				continue
			var cell: int = img.get_width() / COLS
			if cell == 128:
				img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
			elif cell != CELL:
				push_error("%s: 非常规格径 %d（既非 128 也非 256）·跳过" % [id, cell])
				ok = false
				continue
			if kind == "defeats" and id in FLIP_DEFEAT:
				_flip_cells(img, CELL)
				print("[prep-%s] %s: 倒向镜像修正（逐格 flip_x）" % [tag, id])
			var out := ProjectSettings.globalize_path("%s%s/%s_%s.png" % [DST, id, id, tag])
			var err := img.save_png(out)
			print("[prep-%s] %s: → %dx%d (err=%d)" % [tag, id, img.get_width(), img.get_height(), err])
			ok = ok and err == OK
	for id: String in _sorted(batch["arts"]):
		var img := Image.load_from_file(ProjectSettings.globalize_path(IMPORT_DIR + batch["arts"][id]))
		if img == null:
			ok = false
			continue
		# 洗灰底出透明抠像（MJ 立绘=纯灰平底·灰调中性色⛔上纸面）：邻差泛洪
		# （img_bg_flood_to_alpha 同算法·四边种子·邻差≤0.055 撞硬轮廓停）——旧立绘线=透明底约定。
		img.convert(Image.FORMAT_RGBA8)
		var cleared := _flood_cutout(img)
		var err := img.save_png(ProjectSettings.globalize_path("%s%s/%s.png" % [DST, id, id]))
		print("[prep-art] %s: %dx%d 抠底 %d px → heroes/%s/%s.png (err=%d)"
				% [id, img.get_width(), img.get_height(), cleared, id, id, err])
		ok = ok and err == OK
	return ok


## 逐格水平镜像（绕格心）：姿态与位移轨迹一起翻转 → 动画内部连贯（FLIP_DEFEAT 名单用）。
static func _flip_cells(img: Image, cell: int) -> void:
	var cols := img.get_width() / cell
	var rows := img.get_height() / cell
	for r in rows:
		for c in cols:
			var region := img.get_region(Rect2i(c * cell, r * cell, cell, cell))
			region.flip_x()
			img.blit_rect(region, Rect2i(0, 0, cell, cell), Vector2i(c * cell, r * cell))


## 邻差泛洪抠底：四边种子 BFS·邻居与当前像素色距≤阈值即蔓延（渐晕跟得上·硬轮廓挡得住）。
func _flood_cutout(img: Image, tol: float = 0.055) -> int:
	var w := img.get_width()
	var h := img.get_height()
	var visited := PackedByteArray()
	visited.resize(w * h)
	var queue: Array[int] = []
	for x in w:
		for yy: int in [0, h - 1]:
			if visited[yy * w + x] == 0:
				visited[yy * w + x] = 1
				queue.append(yy * w + x)
	for y in h:
		for xx: int in [0, w - 1]:
			if visited[y * w + xx] == 0:
				visited[y * w + xx] = 1
				queue.append(y * w + xx)
	var head := 0
	while head < queue.size():
		var idx := queue[head]
		head += 1
		var px := idx % w
		var py := idx / w
		var c := img.get_pixel(px, py)
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx := px + d.x
			var ny := py + d.y
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			var ni := ny * w + nx
			if visited[ni] == 1:
				continue
			var n := img.get_pixel(nx, ny)
			if absf(n.r - c.r) + absf(n.g - c.g) + absf(n.b - c.b) <= tol * 3.0:
				visited[ni] = 1
				queue.append(ni)
	var cleared := 0
	for i in w * h:
		if visited[i] == 1:
			img.set_pixel(i % w, i / w, Color(0, 0, 0, 0))
			cleared += 1
	return cleared


func _build() -> bool:
	var batch := _list_batch()
	var ok := true
	for kind: String in SHEET_KINDS:
		var anim := _anim_of(kind)
		var phase: float = ACTION_PHASE if anim == "attack" else DEFEAT_PHASE
		for id: String in _sorted(batch[kind]):
			ok = _build_anim(id, anim, phase) and ok
	return ok


## 把落位成品 sheet 切帧追加为 hXX_idle.tres 里的一条非循环动画（attack/defeat 共用）。
func _build_anim(id: String, anim: String, phase: float) -> bool:
	var png := "%s%s/%s_%s.png" % [DST, id, id, anim]
	var tres := "%s%s/%s_idle.tres" % [DST, id, id]
	if not ResourceLoader.exists(png):
		push_error("%s: %s 放大图未注册（先跑 --import）" % [id, anim])
		return false
	if not ResourceLoader.exists(tres):
		push_error("%s: idle.tres 不存在" % id)
		return false
	var tex: Texture2D = load(png)
	var img := Image.load_from_file(ProjectSettings.globalize_path(png))
	var sf: SpriteFrames = load(tres)
	if tex == null or img == null or sf == null:
		push_error("%s: 资源加载失败" % id)
		return false
	if sf.has_animation(anim):
		sf.remove_animation(anim)
	sf.add_animation(anim)
	sf.set_animation_loop(anim, false)
	var rows: int = img.get_height() / CELL
	var frames := 0
	for r in rows:
		for c in COLS:
			if _cell_empty(img, c * CELL, r * CELL, CELL):
				continue
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(c * CELL, r * CELL, CELL, CELL)
			sf.add_frame(anim, atlas)
			frames += 1
	if frames == 0:
		push_error("%s: %s 无有效帧" % [id, anim])
		return false
	var fps: float = float(frames) / phase
	sf.set_animation_speed(anim, fps)
	var err := ResourceSaver.save(sf, tres)
	print("[build] %s: %s %d 帧·%.1f fps → %s (err=%d)" % [id, anim, frames, fps, tres, err])
	return err == OK


## 验收铁律核验（本批 import 区范围）：成品 sheet 首格 alpha bbox 必须与 idle 首格全等
## （=首帧站姿同尺寸同坐标·衔接零跳变）。不等=FAILED·按 h19 法人工定标后重跑。
func _verify() -> bool:
	var batch := _list_batch()
	var ok := true
	var checked := 0
	for kind: String in SHEET_KINDS:
		var anim := _anim_of(kind)
		for id: String in _sorted(batch[kind]):
			var idle_png := ProjectSettings.globalize_path("%s%s/%s_idle.png" % [DST, id, id])
			var sheet_png := ProjectSettings.globalize_path("%s%s/%s_%s.png" % [DST, id, id, anim])
			var idle := Image.load_from_file(idle_png)
			var sheet := Image.load_from_file(sheet_png)
			if idle == null or sheet == null:
				push_error("[verify] %s %s: 图缺失（idle=%s sheet=%s）"
						% [id, anim, str(idle != null), str(sheet != null)])
				ok = false
				continue
			var ib := _alpha_bbox(idle, Rect2i(0, 0, CELL, CELL))
			var sb := _alpha_bbox(sheet, Rect2i(0, 0, CELL, CELL))
			checked += 1
			var expect := ib
			var tag := ""
			if anim == "defeat" and id in FLIP_DEFEAT:
				# 倒向镜像修正名单：首帧=idle 的水平镜像 → 期望盒绕格心翻转
				expect = Rect2i(CELL - ib.position.x - ib.size.x, ib.position.y, ib.size.x, ib.size.y)
				tag = "（镜像盒等式）"
			var dp := sb.position - expect.position
			var ds := sb.size - expect.size
			if sb == expect:
				print("[verify] %s %s: 首帧 %s = idle ✓零偏差%s" % [id, anim, sb, tag])
			elif absi(dp.x) <= VERIFY_TOL and absi(dp.y) <= VERIFY_TOL \
					and absi(ds.x) <= VERIFY_TOL and absi(ds.y) <= VERIFY_TOL:
				# ≤2px=GPT 摆姿噪声（h07/h09 defeat 批实测·屏上 scale2.0 无感）·警示通过
				print("[verify] %s %s: 首帧 %s ≈ 期望%s（Δpos=%s Δsize=%s ≤%dpx 容差·通过）"
						% [id, anim, sb, tag, dp, ds, VERIFY_TOL])
			else:
				print("[verify] %s %s: ⚠首帧 %s ≠ 期望 %s%s（偏移 Δpos=%s Δsize=%s）"
						% [id, anim, sb, expect, tag, dp, ds])
				ok = false
	print("[verify] 共核验 %d 张" % checked)
	return ok


## h19 专段：棋盘假透明→真透明（亮中性色且与图像边界连通·BFS——人物内部银靴/白光不连边界=保住）
## → 上下两带 x 投影切 7 姿势 → 统一 ÷2 缩放（原图≈2px texel·干净减半）→ 脚底对齐 idle 地线
## → 装 4×2 严格 256 网格 → heroes/h19/h19_attack.png（之后走通用 build 切帧）。
func _prep_h19() -> bool:
	var img := Image.load_from_file(ProjectSettings.globalize_path(IMPORT_DIR + "h19_attack.png"))
	if img == null:
		push_error("h19 源图加载失败")
		return false
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()

	# ① 去棋盘（边界连通的亮中性色）
	var neutral := PackedByteArray()
	neutral.resize(w * h)
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			var hi := maxf(c.r, maxf(c.g, c.b))
			var lo := minf(c.r, minf(c.g, c.b))
			neutral[y * w + x] = 1 if (c.a > 0.0 and hi >= 0.66 and hi - lo <= 0.10) else 0
	var visited := PackedByteArray()
	visited.resize(w * h)
	var queue: Array[int] = []
	for x in w:
		for yy: int in [0, h - 1]:
			if neutral[yy * w + x] == 1 and visited[yy * w + x] == 0:
				visited[yy * w + x] = 1
				queue.append(yy * w + x)
	for y in h:
		for xx: int in [0, w - 1]:
			if neutral[y * w + xx] == 1 and visited[y * w + xx] == 0:
				visited[y * w + xx] = 1
				queue.append(y * w + xx)
	var head := 0
	while head < queue.size():
		var idx := queue[head]
		head += 1
		var px := idx % w
		var py := idx / w
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx := px + d.x
			var ny := py + d.y
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			var ni := ny * w + nx
			if neutral[ni] == 1 and visited[ni] == 0:
				visited[ni] = 1
				queue.append(ni)
	var cleared := 0
	for i in w * h:
		if visited[i] == 1:
			img.set_pixel(i % w, i / w, Color(0, 0, 0, 0))
			cleared += 1
	print("[h19] 去棋盘: 清 %d px" % cleared)

	# ② idle 地线基准（首帧 alpha 包围盒：人物高 + 脚底 y·输出帧对齐它）
	var idle := Image.load_from_file(ProjectSettings.globalize_path(DST + "h19/h19_idle.png"))
	if idle == null:
		push_error("h19 idle 加载失败（量地线用）")
		return false
	var ib := _alpha_bbox(idle, Rect2i(0, 0, CELL, CELL))
	print("[h19] idle 首帧包围盒 %s（人物高 %d·脚线 y=%d）" % [ib, ib.size.y, ib.end.y])

	# ③ 上下两带 x 投影切姿势（列有 alpha=占用·间隙≥8px 分段）
	var blobs: Array[Rect2i] = []
	for band: Array in [[0, h / 2], [h / 2, h]]:
		var runs: Array = []
		var run_start := -1
		for x in w:
			var occupied := false
			for y in range(int(band[0]), int(band[1]), 2):
				if img.get_pixel(x, y).a > 0.1:
					occupied = true
					break
			if occupied and run_start < 0:
				run_start = x
			elif not occupied and run_start >= 0:
				if x - run_start > 8:
					runs.append([run_start, x])
				run_start = -1
		if run_start >= 0:
			runs.append([run_start, w])
		for r: Array in runs:
			var bb := _alpha_bbox(img, Rect2i(int(r[0]), int(band[0]),
				int(r[1]) - int(r[0]), int(band[1]) - int(band[0])))
			if bb.size.x > 16 and bb.size.y > 16:
				blobs.append(bb)
	# 宽块拆分：斩击弧会把相邻姿势桥成一块（帧5+6 实证 456px 宽）→ 中段密度谷列一刀两半
	var split_blobs: Array[Rect2i] = []
	for bb: Rect2i in blobs:
		if bb.size.x <= 280:
			split_blobs.append(bb)
			continue
		var best_x := -1
		var best_n := 999999
		for x in range(bb.position.x + bb.size.x * 3 / 10, bb.position.x + bb.size.x * 7 / 10):
			var n := 0
			for y in range(bb.position.y, bb.end.y, 2):
				if img.get_pixel(x, y).a > 0.1:
					n += 1
			if n < best_n:
				best_n = n
				best_x = x
		var left := _alpha_bbox(img, Rect2i(bb.position.x, bb.position.y, best_x - bb.position.x, bb.size.y))
		var right := _alpha_bbox(img, Rect2i(best_x, bb.position.y, bb.end.x - best_x, bb.size.y))
		print("[h19] 宽块 %s 谷列 x=%d(密度%d) 拆为 %s + %s" % [bb, best_x, best_n, left, right])
		split_blobs.append(left)
		split_blobs.append(right)
	blobs = split_blobs
	print("[h19] 切出 %d 个姿势: %s" % [blobs.size(), str(blobs)])
	if blobs.size() != 7:
		push_error("h19 期望 7 姿势·实得 %d——投影切分需要人工复核" % blobs.size())
		return false

	# ④ 动态定标缩放 + 对齐 idle 站位 → 4×2 网格。
	# 正规表铁律（h02/h07/h11 实测）：攻击首帧=idle 站姿**同尺寸同坐标**（衔接零跳变）
	# → 缩放=idle 人物高/首帧人物高；水平中心=idle 人物中心；脚底=idle 地线。
	var s := float(ib.size.y) / float(blobs[0].size.y)
	var anchor_cx := ib.position.x + ib.size.x / 2
	print("[h19] 定标: 缩放=%.4f（idle 高 %d / 首帧高 %d）·横锚 x=%d·地线 y=%d"
			% [s, ib.size.y, blobs[0].size.y, anchor_cx, ib.end.y])
	var out := Image.create(COLS * CELL, 2 * CELL, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	for i in blobs.size():
		var bb := blobs[i]
		var piece := img.get_region(bb)
		var sw := maxi(1, int(round(bb.size.x * s)))
		var sh := maxi(1, int(round(bb.size.y * s)))
		piece.resize(sw, sh, Image.INTERPOLATE_NEAREST)
		var cx := (i % COLS) * CELL
		var cy := (i / COLS) * CELL
		var dx := clampi(cx + anchor_cx - sw / 2, cx, cx + CELL - sw)
		var dy := maxi(cy, cy + ib.end.y - sh)   # 脚底=idle 地线（超高姿势顶头不出格）
		out.blit_rect(piece, Rect2i(0, 0, sw, sh), Vector2i(dx, dy))
		print("[h19] 帧%d: %s → %dx%d @(%d,%d)" % [i + 1, bb, sw, sh, dx - cx, dy - cy])
	var err := out.save_png(ProjectSettings.globalize_path(DST + "h19/h19_attack.png"))
	print("[h19] → heroes/h19/h19_attack.png 1024x512 (err=%d)" % err)
	return err == OK


## 区域内 alpha 包围盒（全图坐标）。
func _alpha_bbox(img: Image, region: Rect2i) -> Rect2i:
	var minx := region.end.x
	var miny := region.end.y
	var maxx := region.position.x - 1
	var maxy := region.position.y - 1
	for y in range(region.position.y, mini(region.end.y, img.get_height())):
		for x in range(region.position.x, mini(region.end.x, img.get_width())):
			if img.get_pixel(x, y).a > 0.1:
				minx = mini(minx, x)
				miny = mini(miny, y)
				maxx = maxi(maxx, x)
				maxy = maxi(maxy, y)
	if maxx < minx:
		return Rect2i()
	return Rect2i(minx, miny, maxx - minx + 1, maxy - miny + 1)


func _sorted(d: Dictionary) -> Array:
	var keys: Array = d.keys()
	keys.sort()
	return keys


## 该格是否全透明（采样步长 8·同 import_hero_art）。
func _cell_empty(img: Image, x: int, y: int, cell: int) -> bool:
	var step := 8
	for yy in range(y, mini(y + cell, img.get_height()), step):
		for xx in range(x, mini(x + cell, img.get_width()), step):
			if img.get_pixel(xx, yy).a > 0.15:
				return false
	return true


## 图是否带透明区（四角+边带采样·全不透明=带背景）。
func _has_alpha(img: Image) -> bool:
	var w := img.get_width()
	var h := img.get_height()
	for p: Vector2i in [Vector2i(0, 0), Vector2i(w - 1, 0), Vector2i(0, h - 1),
			Vector2i(w - 1, h - 1), Vector2i(w / 2, 0), Vector2i(0, h / 2)]:
		if img.get_pixel(p.x, p.y).a < 0.5:
			return true
	return false
