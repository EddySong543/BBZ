extends SceneTree

## Rebuilds the approved item-codex rarity paper tabs as exact 3x pixel assets.
## The Chinese labels remain editable Godot Button text; these PNGs only carry paper art.

const OUTPUT_DIR := "res://assets/ui/item_codex/rarity_tabs"
const LOGICAL_SIZE := Vector2i(50, 18)
const DISPLAY_SCALE := 3

const IDLE_BORDER := Color("59452F")
const IDLE_BODY := Color("D7C39A")
const IDLE_BODY_ALT := Color("D2BC90")
const IDLE_HIGHLIGHT := Color("E6D4AC")
const IDLE_SHADE := Color("B59C70")
const SHADOW := Color(0.20, 0.14, 0.09, 0.64)

const TIER_PALETTES := {
	1: {
		"border": Color("233E52"),
		"accent": Color("477B9A"),
		"accent_hi": Color("A7C5D0"),
		"body": Color("D2E0E3"),
		"body_alt": Color("CAD9DC"),
		"highlight": Color("E7F0F1"),
		"shade": Color("9DAFB3"),
	},
	2: {
		"border": Color("402E4B"),
		"accent": Color("725486"),
		"accent_hi": Color("C1A8C9"),
		"body": Color("DDD3DF"),
		"body_alt": Color("D4C8D8"),
		"highlight": Color("EEE5EF"),
		"shade": Color("AA99AF"),
	},
	3: {
		"border": Color("533A10"),
		"accent": Color("9C6D21"),
		"accent_hi": Color("E0C072"),
		"body": Color("E4D3AD"),
		"body_alt": Color("DAC69D"),
		"highlight": Color("F2E4C4"),
		"shade": Color("B99C63"),
	},
}


func _init() -> void:
	var absolute_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	var mkdir_error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if mkdir_error != OK:
		push_error("Unable to create rarity-tab directory: %s" % error_string(mkdir_error))
		quit(1)
		return
	for tier: int in [1, 2, 3]:
		_build_tab(tier, false)
		_build_tab(tier, true)
	quit()


func _build_tab(tier: int, selected: bool) -> void:
	var palette: Dictionary = TIER_PALETTES[tier]
	var image := Image.create_empty(LOGICAL_SIZE.x, LOGICAL_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)

	# A hard one-pixel drop shadow keeps the paper slip readable without pseudo-3D beveling.
	_fill_rect(image, Rect2i(2, 16, 48, 2), SHADOW if selected else Color(SHADOW, 0.46))
	_fill_rect(image, Rect2i(49, 3, 1, 13), SHADOW if selected else Color(SHADOW, 0.46))

	var border: Color = palette["border"] if selected else IDLE_BORDER
	var body: Color = palette["body"] if selected else IDLE_BODY
	var body_alt: Color = palette["body_alt"] if selected else IDLE_BODY_ALT
	var highlight: Color = palette["highlight"] if selected else IDLE_HIGHLIGHT
	var shade: Color = palette["shade"] if selected else IDLE_SHADE
	var accent: Color = palette["accent"]
	var accent_hi: Color = palette["accent_hi"]

	# Complete rectangular silhouette: no inward corners, tails, seals, or metal ornaments.
	_fill_rect(image, Rect2i(1, 1, 48, 15), border)
	_fill_rect(image, Rect2i(2, 2, 46, 13), body)
	_fill_rect(image, Rect2i(2, 2, 46, 1), highlight)
	_fill_rect(image, Rect2i(2, 3, 1, 10), highlight)
	_fill_rect(image, Rect2i(47, 3, 1, 10), shade)

	# Sparse deterministic paper flecks are whole logical pixels, never antialiased noise.
	for y: int in range(4, 12):
		for x: int in range(4, 46):
			if (x * 5 + y * 7 + tier * 3) % 31 == 0:
				image.set_pixel(x, y, body_alt)

	if selected:
		_fill_rect(image, Rect2i(2, 12, 46, 1), accent_hi)
		_fill_rect(image, Rect2i(2, 13, 46, 2), accent)
	else:
		_fill_rect(image, Rect2i(2, 13, 46, 1), body_alt)
		_fill_rect(image, Rect2i(2, 14, 46, 1), accent)

	image.resize(
			LOGICAL_SIZE.x * DISPLAY_SCALE,
			LOGICAL_SIZE.y * DISPLAY_SCALE,
			Image.INTERPOLATE_NEAREST)
	var state := "selected" if selected else "idle"
	var output_path := "%s/tier_tab_t%d_%s.png" % [OUTPUT_DIR, tier, state]
	var save_error := image.save_png(ProjectSettings.globalize_path(output_path))
	if save_error != OK:
		push_error("Unable to save %s: %s" % [output_path, error_string(save_error)])
		quit(1)


func _fill_rect(image: Image, rect: Rect2i, color: Color) -> void:
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			image.set_pixel(x, y, color)
