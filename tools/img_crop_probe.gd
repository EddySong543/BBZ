extends SceneTree

## 临时图像取证探针（headless 可跑）：打印道具框贴图原生尺寸 +
## 从 battle_screen_shot.png 裁剪 P1/P2 道具行并 3 倍放大存出，供逐像素比对图鉴。
##   godot --headless --path . -s tools/img_crop_probe.gd
## 输出：D:/Game/BoBoZan/crop_battle_items_p1/p2.png（仓库外）

const TEXES: Array[String] = [
	"res://assets/ui/item_frame.png",
	"res://assets/ui/hero_avatar_frame.png",
]


func _initialize() -> void:
	for f in TEXES:
		var img := Image.load_from_file(ProjectSettings.globalize_path(f))
		if img != null:
			print(f, " -> ", img.get_size())
	var shot := Image.load_from_file("D:/Game/BoBoZan/battle_screen_shot.png")
	if shot != null:
		_crop(shot, Rect2i(20, 160, 230, 90), "D:/Game/BoBoZan/crop_battle_items_p1.png")
		_crop(shot, Rect2i(1670, 160, 230, 90), "D:/Game/BoBoZan/crop_battle_items_p2.png")
	quit()


func _crop(src: Image, r: Rect2i, out: String) -> void:
	var c := src.get_region(r)
	c.resize(r.size.x * 3, r.size.y * 3, Image.INTERPOLATE_NEAREST)
	c.save_png(out)
	print("saved: ", out)
