extends SceneTree

## 终端 ASCII 预览标题像素字形（开发调试用）：
##   godot --headless -s tools/dump_glyphs.gd

const PixelGlyphsRes := preload("res://src/ui/components/pixel_glyphs.gd")


func _init() -> void:
	for ch in ["波", "攒", "之", "王", "crown"]:
		print("==== %s ====" % ch)
		print(PixelGlyphsRes.dump(ch))
	quit()
