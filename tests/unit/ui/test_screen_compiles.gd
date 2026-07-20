extends GutTest

const HeroGalleryScreen := preload("res://src/ui/hero_gallery_screen.gd")
const ItemGalleryScreen := preload("res://src/ui/item_gallery_screen.gd")

## 回归守卫：关键 screen 脚本在含 autoload 的 GUT 环境能编译。
## （裸 --check-only 无 autoload（FontManager 等）会误报，故用 GUT 环境 load 触发编译。）
## bp_screen：2026-07-03 任务#5 接入 DraftAI 后的引用解析守卫。

func test_bp_screen_compiles() -> void:
	assert_not_null(load("res://src/ui/bp_screen.gd"), "bp_screen.gd 编译通过（DraftAI 接线）")


func test_hero_gallery_screen_compiles() -> void:
	assert_not_null(load("res://src/ui/hero_gallery_screen.gd"), "hero_gallery_screen.gd 编译通过")


func test_item_gallery_screen_compiles() -> void:
	assert_not_null(load("res://src/ui/item_gallery_screen.gd"), "item_gallery_screen.gd 编译通过")


func test_item_gallery_fill_overdraws_new_frame_inner_edge() -> void:
	assert_eq(ItemGalleryScreen.CELL_INSET_RATIO, 5.5 / 68.0,
			"道具图鉴格底轻微压到新框下，不再露出顶部纸色细缝")


func test_battle_reserve_avatar_click_still_arms_active_switch() -> void:
	# 头像框换皮是纯视觉改动；己方替补框的成熟主动换人入口必须继续可点。
	BattleSetup.reset()
	var packed := load("res://src/ui/battle_screen.tscn") as PackedScene
	var screen := packed.instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	screen.state = 1   # BattleScreen.State.PLAYER_SELECT
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	screen.p1_frames[1].gui_input.emit(click)
	assert_eq(screen._armed_switch_frame, 1, "点击己方替补头像仍进入主动换人态")
	assert_true(screen.p1_frames[1].get_node("SwitchPrompt").visible,
			"主动换人态继续显示切换提示")
	BattleSetup.reset()


func test_hero_gallery_uses_new_item_frame_geometry() -> void:
	var packed := load("res://src/ui/hero_gallery_screen.tscn") as PackedScene
	var screen := packed.instantiate()
	add_child_autofree(screen)
	var small := screen.find_child("GalleryItemFrame", true, false) as TextureRect
	var detail := screen.find_child("HeroDetailItemFrame", true, false) as TextureRect
	var cell := screen.find_child("HeroDetailCell", true, false) as ColorRect
	assert_not_null(small, "英雄列表使用新版道具框")
	assert_not_null(detail, "英雄详情使用新版道具框")
	var portrait_root := small.get_parent()
	assert_eq(portrait_root.name, "HeroPortraitFrame", "英雄缩略图使用图鉴专用节点，不覆盖旧组件")
	assert_null(portrait_root.get_node_or_null("Bg"), "英雄缩略图节点中不存在旧 HeroFrame 边框层")
	assert_not_null(portrait_root.get_node_or_null("HeroThumbCell"), "英雄缩略图拥有独立填充层")
	assert_not_null(portrait_root.get_node_or_null("HeroPortrait"), "英雄缩略图拥有独立头像层")
	assert_eq(small.size, Vector2(HeroGalleryScreen.BOX, HeroGalleryScreen.BOX) * HeroGalleryScreen.FRAME_ART_SCALE,
			"英雄列表框补偿新素材透明边")
	assert_true(detail.size.is_equal_approx(
			Vector2.ONE * HeroGalleryScreen.CELL * HeroGalleryScreen.FRAME_ART_SCALE),
			"英雄详情框按同一比例补偿透明边")
	assert_eq((cell.material as ShaderMaterial).get_shader_parameter("corner_radius"), 0.0,
			"英雄详情格底由新框遮挡，不沿用旧圆角")
