extends GutTest

const HeroGalleryScreen := preload("res://src/ui/hero_gallery_screen.gd")
const ItemGalleryScreen := preload("res://src/ui/item_gallery_screen.gd")
const ItemAvatarFrameScript := preload("res://src/ui/components/item_avatar_frame.gd")

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


func test_death_switch_uses_item_frame_and_slant_hp() -> void:
	var packed := load("res://src/ui/components/death_switch_overlay.tscn") as PackedScene
	var overlay := packed.instantiate()
	add_child_autofree(overlay)
	var hero := load("res://assets/data/heroes/h01.tres") as HeroData
	overlay.show_selection(0, [[1, hero, 4.5]])
	var avatar := overlay.find_child("ItemAvatarFrame", true, false)
	var hp_row := overlay.find_child("HpRow", true, false)
	assert_not_null(avatar, "被迫换人头像使用新版 item_frame 组件")
	assert_eq(avatar.get_script(), ItemAvatarFrameScript, "被迫换人不再实例化旧 HeroFrame")
	assert_not_null(hp_row, "被迫换人使用平行四边形+数字血量")
	assert_true(hp_row is ReserveHpRow, "血量展示复用现役 ReserveHpRow")
	watch_signals(overlay)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	avatar.gui_input.emit(click)
	assert_signal_emitted_with_parameters(overlay, "selection_made", [1])
	overlay._counting = false
	overlay.set_process(false)


func test_main_menu_profile_avatar_uses_item_frame() -> void:
	var packed := load("res://src/ui/main_menu.tscn") as PackedScene
	var menu := packed.instantiate()
	add_child_autofree(menu)
	var avatar := menu.get_node("UI/IdentityButton/AvatarFrame")
	assert_eq(avatar.get_script(), ItemAvatarFrameScript,
			"主菜单个人资料头像使用新版 item_frame 组件")
	assert_null(avatar.get_node_or_null("Bg"), "主菜单头像不存在旧 HeroFrame 边框层")
	assert_eq(avatar.mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"头像区域继续把点击交给个人资料入口按钮")


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
