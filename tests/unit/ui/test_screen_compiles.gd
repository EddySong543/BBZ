extends GutTest

## 回归守卫：关键 screen 脚本在含 autoload 的 GUT 环境能编译。
## （裸 --check-only 无 autoload（FontManager 等）会误报，故用 GUT 环境 load 触发编译。）
## bp_screen：2026-07-03 任务#5 接入 DraftAI 后的引用解析守卫。

func test_bp_screen_compiles() -> void:
	assert_not_null(load("res://src/ui/bp_screen.gd"), "bp_screen.gd 编译通过（DraftAI 接线）")


func test_hero_gallery_screen_compiles() -> void:
	assert_not_null(load("res://src/ui/hero_gallery_screen.gd"), "hero_gallery_screen.gd 编译通过")
