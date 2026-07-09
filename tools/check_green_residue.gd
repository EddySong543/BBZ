extends SceneTree

## 绿幕残留 QA 扫描（attack 雪碧图批量生产用·2026-07-09）：
## 逐 256 格统计"绿味像素"（g 显著高于 r/b 的不透明像素）数量与占比，
## 输出每帧数据 + 总判定。用法：
##   godot --headless --path . --script res://tools/check_green_residue.gd -- --png res://path/to/sheet.png
## 判定线：单帧绿味 >1% 不透明像素 = ⚠ 建议返修；≤1% = 夜景战斗尺度下可接受。

const CELL := 256
const GREEN_DOMINANCE := 1.25   # g 超过 max(r,b) 的倍数阈值
const GREEN_MIN := 0.25         # g 绝对下限（排除暗部噪声）
const WARN_PCT := 1.0           # 单帧警戒线（% 不透明像素）


func _initialize() -> void:
	var png := "res://assets/sprites/heroes/h01/h01_attack.png"
	var dominance := GREEN_DOMINANCE
	var gmin := GREEN_MIN
	var amin := 0.1
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--png" and i + 1 < args.size():
			png = args[i + 1]
		elif args[i] == "--dominance" and i + 1 < args.size():
			dominance = float(args[i + 1])
		elif args[i] == "--gmin" and i + 1 < args.size():
			gmin = float(args[i + 1])
		elif args[i] == "--amin" and i + 1 < args.size():
			amin = float(args[i + 1])
	var img := Image.load_from_file(ProjectSettings.globalize_path(png))
	if img == null:
		push_error("加载失败: " + png)
		quit(1)
		return
	print("扫描 %s (%dx%d·%d 格)" % [png, img.get_width(), img.get_height(),
			(img.get_width() / CELL) * (img.get_height() / CELL)])
	var worst := 0.0
	var frame_i := 0
	for r in range(img.get_height() / CELL):
		for c in range(img.get_width() / CELL):
			var opaque := 0
			var green := 0
			for y in range(r * CELL, (r + 1) * CELL):
				for x in range(c * CELL, (c + 1) * CELL):
					var px := img.get_pixel(x, y)
					if px.a < amin:
						continue
					opaque += 1
					if px.g > maxf(px.r, px.b) * dominance and px.g > gmin:
						green += 1
			if opaque == 0:
				continue
			var pct := 100.0 * float(green) / float(opaque)
			worst = maxf(worst, pct)
			print("  帧 %02d: 不透明 %6d ｜ 绿味 %5d ｜ %.2f%% %s"
					% [frame_i, opaque, green, pct, "⚠" if pct > WARN_PCT else ""])
			frame_i += 1
	print("=== 最差帧 %.2f%% ｜ 判定: %s（警戒线 %.1f%%） ===" % [worst,
			"⚠ 建议返修" if worst > WARN_PCT else "✅ 可接受", WARN_PCT])
	quit()
