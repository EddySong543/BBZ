extends SceneTree

## h01 攻击动画实验资产导入（一次性·2026-07-09 Eddy 点单）。
## 源=assets/import/h01_attack.png（512×512·128px 格 4×4——⚠比常规 256 小一档，
## 额外步骤=先无损 2× 最近邻放大到 1024×1024/256 格，再走常规切帧管线）。
## 用法（两阶段·中间需 --import 注册新 png）：
##   godot --headless --path . --script res://tools/import_h01_attack.gd -- --phase 1
##   godot --headless --path . --import
##   godot --headless --path . --script res://tools/import_h01_attack.gd -- --phase 2
## phase 1: 放大 → assets/sprites/heroes/h01/h01_attack.png
## phase 2: 切 256 格（跳全透明帧）追加为 h01_idle.tres 的 "attack" 动画（非循环·
##          速度=帧数/0.6s 对齐 action_phase 节拍），效果好批量生产时再泛化进 import_hero_art。

const SRC := "res://assets/import/h01_attack.png"
const DST_PNG := "res://assets/sprites/heroes/h01/h01_attack.png"
const DST_TRES := "res://assets/sprites/heroes/h01/h01_idle.tres"
const CELL := 256
const COLS := 4
const ACTION_PHASE := 0.6   # battle_screen.action_phase_duration·攻击动画时长对齐这一拍


func _initialize() -> void:
	var phase := "1"
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--phase" and i + 1 < args.size():
			phase = args[i + 1]
	var ok := _phase1() if phase == "1" else _phase2()
	print("=== phase %s %s ===" % [phase, "OK" if ok else "FAILED"])
	quit(0 if ok else 1)


## 128 格雪碧图 → 2× 最近邻放大（像素完美·1024×1024/256 格）落正式文件夹。
func _phase1() -> bool:
	var img := Image.load_from_file(ProjectSettings.globalize_path(SRC))
	if img == null:
		push_error("源图加载失败: " + SRC)
		return false
	print("[phase1] 源图 %dx%d → 2× 放大" % [img.get_width(), img.get_height()])
	img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	var err := img.save_png(ProjectSettings.globalize_path(DST_PNG))
	print("[phase1] 保存 %s (%dx%d·err=%d)" % [DST_PNG, img.get_width(), img.get_height(), err])
	return err == OK


## 切帧追加 "attack" 动画到 h01_idle.tres（跳全透明帧·非循环）。
func _phase2() -> bool:
	if not ResourceLoader.exists(DST_PNG):
		push_error("放大图未注册（先跑 --import）: " + DST_PNG)
		return false
	var tex: Texture2D = load(DST_PNG)
	var img := Image.load_from_file(ProjectSettings.globalize_path(DST_PNG))
	var sf: SpriteFrames = load(DST_TRES)
	if tex == null or img == null or sf == null:
		push_error("资源加载失败（tex/img/tres）")
		return false

	if sf.has_animation("attack"):
		sf.remove_animation("attack")
	sf.add_animation("attack")
	sf.set_animation_loop("attack", false)

	var rows: int = img.get_height() / CELL
	var frames := 0
	for r in range(rows):
		for c in range(COLS):
			if _cell_empty(img, c * CELL, r * CELL):
				continue
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(c * CELL, r * CELL, CELL, CELL)
			sf.add_frame("attack", atlas)
			frames += 1
	if frames == 0:
		push_error("attack 无有效帧")
		return false
	var fps: float = float(frames) / ACTION_PHASE
	sf.set_animation_speed("attack", fps)
	var err := ResourceSaver.save(sf, DST_TRES)
	print("[phase2] attack: %d 帧·%.1f fps（时长≈%.2fs 对齐 action_phase）→ %s (err=%d)"
			% [frames, fps, frames / fps, DST_TRES, err])
	return err == OK


## 该 256 格是否全透明（采样步长 8·同 import_hero_art）。
func _cell_empty(img: Image, x: int, y: int) -> bool:
	var step := 8
	for yy in range(y, mini(y + CELL, img.get_height()), step):
		for xx in range(x, mini(x + CELL, img.get_width()), step):
			if img.get_pixel(xx, yy).a > 0.15:
				return false
	return true
