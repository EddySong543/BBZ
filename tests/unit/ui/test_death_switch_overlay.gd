extends GutTest

const OverlayScene := preload("res://src/ui/components/death_switch_overlay.tscn")


func test_overlay_uses_battle_diamond_frame_without_second_countdown() -> void:
	var overlay := OverlayScene.instantiate() as DeathSwitchOverlay
	add_child_autofree(overlay)
	var hero := load("res://assets/data/heroes/h01.tres") as HeroData
	overlay.show_selection(0, [[1, hero, 4.5]])
	assert_not_null(overlay.find_child("TitleOrnaments", true, false),
		"标题继续复用战斗 HUD 的菱形渐隐线")
	assert_null(overlay.get_node_or_null("CountdownLabel"),
		"浮层不再增设第二套倒计时")
	var avatar := overlay.find_child("HeroFrame", true, false) as HeroFrame
	assert_not_null(avatar, "候选头像复用正式 HeroFrame")
	assert_true(avatar.diamond_mode, "候选头像启用战斗 UI 菱形模式")
	assert_not_null(avatar.get_node_or_null("DiamondFrame"), "菱形框节点已建立")
	assert_true(avatar.bottom_shadow_enabled, "沿用战斗菱形头像的定向下投影")
	assert_null(overlay.find_child("ConfirmButton", true, false),
		"换人仍为点击头像直接选择，不新增确认层")


func test_direct_click_and_default_selection_keep_existing_contract() -> void:
	var overlay := OverlayScene.instantiate() as DeathSwitchOverlay
	add_child_autofree(overlay)
	var hero := load("res://assets/data/heroes/h01.tres") as HeroData
	overlay.show_selection(0, [[1, hero, 4.5]])
	var avatar := overlay.find_child("HeroFrame", true, false) as HeroFrame
	watch_signals(overlay)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	avatar.gui_input.emit(click)
	assert_signal_emitted_with_parameters(overlay, "selection_made", [1])
	await get_tree().create_timer(0.08).timeout
	assert_false(overlay.visible, "点击选择后关闭浮层并进入既有换人流程")

	var default_overlay := OverlayScene.instantiate() as DeathSwitchOverlay
	add_child_autofree(default_overlay)
	default_overlay.show_selection(0, [[2, hero, 4.5]])
	watch_signals(default_overlay)
	default_overlay.select_default()
	assert_signal_emitted_with_parameters(default_overlay, "selection_made", [2])


func test_hover_feedback_stays_restrained() -> void:
	var overlay := OverlayScene.instantiate() as DeathSwitchOverlay
	add_child_autofree(overlay)
	var hero := load("res://assets/data/heroes/h01.tres") as HeroData
	overlay.show_selection(0, [[1, hero, 4.5]])
	var avatar := overlay.find_child("HeroFrame", true, false) as HeroFrame
	avatar.mouse_entered.emit()
	await get_tree().create_timer(0.14).timeout
	assert_almost_eq(avatar.position.y, -2.0, 0.1,
		"悬停菱形头像只轻微上移，不引入卡片式动效")


func test_battle_screen_top_timer_drives_death_switch_timeout() -> void:
	BattleSetup.reset()
	var screen := (load("res://src/ui/battle_screen1.tscn") as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	screen.game_timer.stop()
	screen.state = 3 # BattleScreen.State.HERO_SELECT
	var hero := load("res://assets/data/heroes/h01.tres") as HeroData
	screen._death_switch_overlay.show_selection(0, [[2, hero, 4.5]])
	screen._start_death_switch_timer()
	assert_eq(screen.timer_label.text, str(screen._turn_time_limit()),
		"死亡换人直接使用顶部回合倒计时")
	watch_signals(screen._death_switch_overlay)
	screen.timer_seconds = 1
	screen._on_timer_tick()
	assert_signal_emitted_with_parameters(screen._death_switch_overlay, "selection_made", [2])
	assert_eq(screen.timer_label.text, "0", "统一倒计时归零时顶部保留红色 0")
	BattleSetup.reset()
