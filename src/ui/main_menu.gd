extends Control

## 主菜单 = 晴风驿站功能大厅。远征地表与英雄只承担世界呈现；所有入口仍可直接点击。
## 左键点格可让角色在纯展示地图中逐格行走；入口按钮仍是主操作，不创建远征背包或结算状态。

const EXPEDITION_SCENE := "res://src/expedition/expedition_screen.tscn"
const BACKPACK_OVERLAY_SCENE := preload("res://src/ui/backpack_screen.tscn")
const WAREHOUSE_OVERLAY_SCENE := preload("res://src/ui/warehouse_screen.tscn")
const CODEX_OVERLAY_SCRIPT := preload("res://src/ui/components/battle_codex_overlay.gd")
const PauseMenuOverlayScript := preload(
	"res://src/ui/components/pause_menu_overlay.gd")

var _transitioning: bool = false

## 小件像素底板（底坞导航用）。
## 2026-06-13 Eddy 选 B「典籍朱印」全局铺；2026-07-13 换 GPT 导航钮贴图
## （米金纸面+角上回纹折·9-slice 中段平铺·jelly 程序板/STEEL 色组退役）。
const NAV_PLATE_TEX := preload("res://assets/ui/ui_nav_button.png")   # 235×55·v14 净面版（2026-07-16 Eddy 定内饰多余·img_inner_clear 去回纹钩+内线·只留深咖外框+净纸面）
const CODEX_ICON_TEX := preload("res://assets/ui/icons/codex_book.png")
const BACKPACK_ICON_TEX := preload("res://assets/ui/icons/backpack.png")
const EXPEDITION_BANNER_TEX := preload("res://assets/ui/main_menu/expedition_banner.png")
const CODEX_JELLY_SHADER := preload("res://assets/shaders/canvas_button_jelly.gdshader")
const MODE_BANNER_FRAME_SHADER := preload(
		"res://assets/shaders/canvas_mode_banner_frame.gdshader")
const UI_BOTTOM_SHADOW_OFFSET := Vector2(3.0, 6.0)
const UI_BOTTOM_SHADOW_COLOR := Color(0.02, 0.012, 0.008, 0.52)
const BATTLE_UI_FILL_TOP := Color(0.92, 0.87, 0.70)
const BATTLE_UI_FILL_BOTTOM := Color(0.76, 0.68, 0.50)
const BATTLE_UI_EDGE_INNER := Color(1.0, 0.95, 0.80)
const BATTLE_UI_EDGE_OUTER := Color(0.1, 0.09, 0.11)
const DOCK_BUTTON_SIZE := Vector2(108.0, 108.0)
const NAV_PLATE_MARGIN_X := 22.0   # 9-slice 边距（v14 净面后内里全纸·任意≥框厚均可·沿用实钩期数值）
const NAV_PLATE_MARGIN_Y := 20.0
const INK := Color(0.20, 0.14, 0.08)        # 墨（羊皮上的字/图标）
const CREAM := Color(0.95, 0.91, 0.80)      # 暖米白（直接压在暗波上的字·非羊皮上）


@onready var _expedition_entry: Button = $UI/ModeBanner
@onready var _menu_world: MainMenuWorld = $MenuWorld

var _backpack_overlay: BackpackScreen
var _warehouse_overlay: WarehouseScreen
var _codex_overlay: Control
func _ready() -> void:
	_build_vignette()
	_setup_version_label()
	_setup_modes()
	_setup_dock()
	_setup_backpack_overlay()
	_setup_warehouse_overlay()
	_setup_codex_overlay()
	_play_intro()


## 重绘主界面世界层的状态相关颜色。
func refresh_colors() -> void:
	_menu_world.refresh_colors()


# ============================================================
# 各区初始化
# ============================================================

## 世界边缘暗角：只压边界，让入口牌与角色保持可读。
func _build_vignette() -> void:
	var vig := TextureRect.new()
	vig.name = "Vignette"
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	grad.colors = PackedColorArray([
		Color(0.02, 0.03, 0.06, 0.0),   # 中央透明（不压主战卡）
		Color(0.02, 0.03, 0.06, 0.0),
		Color(0.02, 0.03, 0.06, 0.5),   # 四周暗navy（聚光衬底·调 alpha 改浓度）
	])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 1.0)
	tex.width = 256
	tex.height = 256
	vig.texture = tex
	vig.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # 平滑暗角（非像素硬边）
	vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vig)
	move_child(vig, 1)   # MenuWorld(0) < Vignette(1) < UI(2)


func _setup_version_label() -> void:
	# 版本号（角落惯例·报 bug 定位用）·压暗波上→暖灰
	var ver: Label = $UI/VersionLabel
	FontManager.apply(ver, 14)
	ver.add_theme_color_override("font_color", Color(0.74, 0.66, 0.52, 0.6))


## 当前产品只保留远征主入口；图鉴、背包和仓库仍是底部独立入口。
func _setup_modes() -> void:
	_setup_mode_banner_button()
	_expedition_entry.pressed.connect(_on_expedition_pressed)
	_expedition_entry.tooltip_text = tr("远征")
	_expedition_entry.grab_focus()


func _setup_mode_banner_button() -> void:
	_expedition_entry.text = ""
	_expedition_entry.clip_contents = false
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		_expedition_entry.add_theme_stylebox_override(state, StyleBoxEmpty.new())

	var bg := ColorRect.new()
	bg.name = "Bg"
	bg.color = Color.WHITE
	var material := ShaderMaterial.new()
	material.shader = CODEX_JELLY_SHADER
	material.set_shader_parameter("fill_top", BATTLE_UI_FILL_TOP)
	material.set_shader_parameter("fill_bottom", BATTLE_UI_FILL_BOTTOM)
	material.set_shader_parameter("edge_inner", BATTLE_UI_EDGE_INNER)
	material.set_shader_parameter("edge_outer", BATTLE_UI_EDGE_OUTER)
	material.set_shader_parameter("fill_alpha", 1.0)
	material.set_shader_parameter("pixel_grid", 38.0)
	material.set_shader_parameter("corner", 0.08)
	material.set_shader_parameter("edge_px", 2.0)
	material.set_shader_parameter("aspect", _expedition_entry.size.x / _expedition_entry.size.y)
	material.set_shader_parameter("noise_amt", 0.08)
	material.set_shader_parameter("wear", 0.24)
	material.set_shader_parameter("solid_rim", true)
	material.set_shader_parameter("rim_px", 1.5)
	bg.material = material
	bg.show_behind_parent = true
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_expedition_entry.add_child(bg)
	_attach_bottom_shadow(_expedition_entry)
	bg.visible = false

	var banner := TextureRect.new()
	banner.name = "Banner"
	banner.texture = EXPEDITION_BANNER_TEX
	banner.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var image_material := ShaderMaterial.new()
	image_material.shader = MODE_BANNER_FRAME_SHADER
	image_material.set_shader_parameter("pixel_grid", 38.0)
	image_material.set_shader_parameter("corner", 0.08)
	image_material.set_shader_parameter("aspect", _expedition_entry.size.x / _expedition_entry.size.y)
	banner.material = image_material
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_expedition_entry.add_child(banner)
	_attach_juice(_expedition_entry)

	var frame_overlay := ColorRect.new()
	frame_overlay.name = "FrameOverlay"
	frame_overlay.color = Color.WHITE
	var overlay_material := ShaderMaterial.new()
	overlay_material.shader = CODEX_JELLY_SHADER
	overlay_material.set_shader_parameter("fill_top", BATTLE_UI_FILL_TOP)
	overlay_material.set_shader_parameter("fill_bottom", BATTLE_UI_FILL_BOTTOM)
	overlay_material.set_shader_parameter("edge_inner", BATTLE_UI_EDGE_INNER)
	overlay_material.set_shader_parameter("edge_outer", BATTLE_UI_EDGE_OUTER)
	overlay_material.set_shader_parameter("fill_alpha", 0.0)
	overlay_material.set_shader_parameter("pixel_grid", 38.0)
	overlay_material.set_shader_parameter("corner", 0.08)
	overlay_material.set_shader_parameter("edge_px", 2.0)
	overlay_material.set_shader_parameter("aspect", _expedition_entry.size.x / _expedition_entry.size.y)
	overlay_material.set_shader_parameter("noise_amt", 0.0)
	overlay_material.set_shader_parameter("wear", 0.0)
	overlay_material.set_shader_parameter("solid_rim", true)
	overlay_material.set_shader_parameter("rim_px", 1.5)
	frame_overlay.material = overlay_material
	frame_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_expedition_entry.add_child(frame_overlay)


## 远征入口：四石依次发光并维持各自光柱，随后底部波幕上涌。
func _on_expedition_pressed() -> void:
	if _transitioning:
		return
	_transitioning = true
	_set_mode_entries_enabled(false)
	await _menu_world.play_portal_activation(
			MainMenuWorld.PORTAL_ENERGY_GOLD, MainMenuWorld.PORTAL_ACTIVATION_DURATION)
	if not is_instance_valid(self):
		return
	await _menu_world.wait_for_portal_beams()
	if is_instance_valid(self):
		await TransitionManager.portal_transition_to(
				EXPEDITION_SCENE, MainMenuWorld.PORTAL_ENERGY_GOLD)

## 图鉴、背包与仓库保持为屏幕底部的独立直接入口。
func _setup_dock() -> void:
	_setup_square_dock_button(
		$UI/NavHeroes as Button, CODEX_ICON_TEX, "图鉴", false)
	_setup_square_dock_button(
		$UI/NavBackpack as Button, BACKPACK_ICON_TEX, "背包", false)
	_setup_square_dock_button(
		$UI/NavWarehouse as Button, PixelGlyphs.icon_texture("potion"),
		"仓库", true)
	($UI/NavHeroes as Button).pressed.connect(_on_codex_pressed)
	($UI/NavBackpack as Button).pressed.connect(_on_backpack_pressed)
	($UI/NavWarehouse as Button).pressed.connect(_on_warehouse_pressed)


func get_bottom_ui_layout_contract() -> Dictionary:
	return {
		"implementation": "single_banner_bottom_dock",
		"uses_continuous_bottom_bar": false,
		"uses_separate_ui_islands": true,
		"secondary_tabs_partially_offscreen": false,
		"reuses_battle_ui_palette": true,
		"uses_grid_anchor_outline": false,
		"banner_rect": Rect2(_expedition_entry.position, _expedition_entry.size),
		"shortcut_size": DOCK_BUTTON_SIZE,
		"frame_fill_top": BATTLE_UI_FILL_TOP,
		"frame_fill_bottom": BATTLE_UI_FILL_BOTTOM,
		"frame_edge_inner": BATTLE_UI_EDGE_INNER,
		"secondary_tab_positions": PackedVector2Array([
			($UI/NavHeroes as Button).position,
			($UI/NavBackpack as Button).position,
			($UI/NavWarehouse as Button).position,
		]),
	}


func _setup_backpack_overlay() -> void:
	_backpack_overlay = BACKPACK_OVERLAY_SCENE.instantiate() as BackpackScreen
	_backpack_overlay.name = "BackpackOverlay"
	add_child(_backpack_overlay)
	_backpack_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _setup_warehouse_overlay() -> void:
	_warehouse_overlay = WAREHOUSE_OVERLAY_SCENE.instantiate() as WarehouseScreen
	_warehouse_overlay.name = "WarehouseOverlay"
	add_child(_warehouse_overlay)
	_warehouse_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _setup_codex_overlay() -> void:
	_codex_overlay = CODEX_OVERLAY_SCRIPT.new() as Control
	_codex_overlay.name = "CodexOverlay"
	add_child(_codex_overlay)
	_codex_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## 次要入口复用战斗UI材质，只显示居中图标。
func _setup_square_dock_button(
		btn: Button, icon_texture: Texture2D, tooltip: String, tint_icon: bool) -> void:
	btn.text = ""
	btn.clip_text = true
	btn.tooltip_text = tr(tooltip)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, StyleBoxEmpty.new())

	var bg := ColorRect.new()
	bg.name = "Bg"
	bg.color = Color.WHITE
	var material := ShaderMaterial.new()
	material.shader = CODEX_JELLY_SHADER
	material.set_shader_parameter("fill_top", BATTLE_UI_FILL_TOP)
	material.set_shader_parameter("fill_bottom", BATTLE_UI_FILL_BOTTOM)
	material.set_shader_parameter("edge_inner", BATTLE_UI_EDGE_INNER)
	material.set_shader_parameter("edge_outer", BATTLE_UI_EDGE_OUTER)
	material.set_shader_parameter("fill_alpha", 1.0)
	material.set_shader_parameter("pixel_grid", 38.0)
	material.set_shader_parameter("corner", 0.22)
	material.set_shader_parameter("edge_px", 2.0)
	material.set_shader_parameter("aspect", 1.0)
	material.set_shader_parameter("noise_amt", 0.08)
	material.set_shader_parameter("wear", 0.24)
	material.set_shader_parameter("solid_rim", true)
	material.set_shader_parameter("rim_px", 1.5)
	bg.material = material
	bg.show_behind_parent = true
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(bg)

	var icon := TextureRect.new()
	icon.name = "BookIcon" if btn == $UI/NavHeroes else "Icon"
	icon.texture = icon_texture
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 22.0
	icon.offset_top = 22.0
	icon.offset_right = -22.0
	icon.offset_bottom = -22.0
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = INK if tint_icon else Color.WHITE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(icon)
	_attach_juice(btn)
	_attach_bottom_shadow(btn)


func _attach_bottom_shadow(btn: Button) -> void:
	var source_bg := btn.get_node("Bg") as ColorRect
	var shadow := ColorRect.new()
	shadow.name = "BottomShadow"
	shadow.color = Color.WHITE
	var material := (source_bg.material as ShaderMaterial).duplicate() as ShaderMaterial
	var opaque_shadow := Color(
			UI_BOTTOM_SHADOW_COLOR.r,
			UI_BOTTOM_SHADOW_COLOR.g,
			UI_BOTTOM_SHADOW_COLOR.b,
			1.0)
	for parameter: String in ["fill_top", "fill_bottom", "edge_inner", "edge_outer"]:
		material.set_shader_parameter(parameter, opaque_shadow)
	material.set_shader_parameter("fill_alpha", 1.0)
	material.set_shader_parameter("noise_amt", 0.0)
	material.set_shader_parameter("wear", 0.0)
	shadow.material = material
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.show_behind_parent = true
	shadow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shadow.offset_left = UI_BOTTOM_SHADOW_OFFSET.x
	shadow.offset_top = UI_BOTTOM_SHADOW_OFFSET.y
	shadow.offset_right = UI_BOTTOM_SHADOW_OFFSET.x
	shadow.offset_bottom = UI_BOTTOM_SHADOW_OFFSET.y
	shadow.self_modulate = Color(1.0, 1.0, 1.0, UI_BOTTOM_SHADOW_COLOR.a)
	btn.add_child(shadow)
	btn.move_child(shadow, 0)


## 统一图鉴入口：与背包一致地覆盖在当前主界面上；转场中不打开。
func _on_codex_pressed() -> void:
	if _transitioning:
		return
	if _backpack_overlay.visible:
		_backpack_overlay.close()
	if _warehouse_overlay.visible:
		_warehouse_overlay.close()
	if _codex_overlay.visible:
		_codex_overlay.call("close")
	else:
		_codex_overlay.call("open")


func _on_backpack_pressed() -> void:
	if _transitioning:
		return
	if _codex_overlay.visible:
		_codex_overlay.call("close")
	if _warehouse_overlay.visible:
		_warehouse_overlay.close()
	_backpack_overlay.open()


func _on_warehouse_pressed() -> void:
	if _transitioning:
		return
	if _codex_overlay.visible:
		_codex_overlay.call("close")
	if _backpack_overlay.visible:
		_backpack_overlay.close()
	_warehouse_overlay.open()


# ============================================================
# 入场 / 转场
# ============================================================

## 入场：世界先落定，两个入口与边缘功能随后浮入。
func _play_intro() -> void:
	# Boot 转场余势只作用于世界，不改变地图构图。
	pivot_offset = size * 0.5
	scale = Vector2(1.045, 1.045)
	var tz := create_tween()
	tz.tween_property(self, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_animate_in()


## 入口入场：远征主入口先出现，其余入口与边缘件跟进。
func _animate_in() -> void:
	var order: Array = [
		$UI/ModeBanner,
		$UI/NavHeroes, $UI/NavBackpack, $UI/NavWarehouse,
	]
	var step := 0.0
	for n in order:
		var b := n as Control
		if b == null:
			continue
		var home := b.position
		b.position = home + Vector2(0.0, 30.0)
		b.modulate.a = 0.0
		var delay := 0.12 + step
		var ta := create_tween()
		ta.tween_interval(delay)
		ta.tween_property(b, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		var tp := create_tween()
		tp.tween_interval(delay)
		tp.tween_property(b, "position", home, 0.44).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		step += 0.07
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel") or has_node("PauseMenu"):
		return
	if _backpack_overlay.visible or _warehouse_overlay.visible or _codex_overlay.visible:
		return
	get_viewport().set_input_as_handled()
	var pause_menu := PauseMenuOverlayScript.new() as CanvasLayer
	pause_menu.name = "PauseMenu"
	add_child(pause_menu)


func _set_mode_entries_enabled(on: bool) -> void:
	_expedition_entry.disabled = not on


# ============================================================
# 小件样式辅助
# ============================================================

## 给按钮挂导航钮贴图底板（GPT 回纹折纸面·2026-07-13 换皮）：清空默认 stylebox + Bg NinePatch 衬底。
func _apply_plate(btn: Button) -> void:
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	btn.add_child(_make_plate_bg())


## 给任意 Control（如副标题 Label）衬导航钮贴图底板。
func _add_plate_bg(ctrl: Control) -> void:
	ctrl.add_child(_make_plate_bg())


## 导航钮底板（NinePatch）：四角回纹折整块保形·中段横竖平铺防颗粒拉伸·像素点采样。
func _make_plate_bg() -> NinePatchRect:
	var bg := NinePatchRect.new()
	bg.name = "Bg"
	bg.texture = NAV_PLATE_TEX
	bg.patch_margin_left = int(NAV_PLATE_MARGIN_X)
	bg.patch_margin_right = int(NAV_PLATE_MARGIN_X)
	bg.patch_margin_top = int(NAV_PLATE_MARGIN_Y)
	bg.patch_margin_bottom = int(NAV_PLATE_MARGIN_Y)
	bg.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
	bg.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.show_behind_parent = true
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bg


## 清空按钮默认皮肤，但保留左内边距（给 icon 锚位让位，文字在余下区域居中）。
func _set_btn_left_margin(btn: Button, left: float) -> void:
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxEmpty.new()
		sb.content_margin_left = left
		btn.add_theme_stylebox_override(s, sb)


## 导航 icon。图鉴复用项目既有书本图标，其余仍由 PixelGlyphs 程序绘制。
## 美术期换素材：替换 Icon 节点的 texture 即可，位置不动。
func _add_icon(host: Control, r: Rect2, icon_name: String) -> void:
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture = CODEX_ICON_TEX if icon_name == "codex" else PixelGlyphs.icon_texture(icon_name)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.position = r.position
	icon.size = r.size
	icon.modulate = INK   # 墨色图标（压在羊皮底板/坞页上）
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(icon)


## 给按钮挂 ButtonJuice（hover 缩放 / 按下反馈）→ 手感与战斗/选人界面统一。
## 世界入口拥有自己的焦点反馈，不再额外挂 ButtonJuice。
func _attach_juice(btn: Button) -> void:
	var bj := ButtonJuice.new()
	bj.name = "ButtonJuice"
	btn.add_child(bj)
