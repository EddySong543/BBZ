extends Node

## h15 / h16 / h17 / h18 技能名图鉴回归探针：
## 真实实例化英雄图鉴，逐个选中 h15、h16、h17、h18，校验资源与右页显示文字并截图。

const ProbeOutput := preload("res://tools/probe_output.gd")


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	get_window().position = Vector2i(0, 0)
	await get_tree().process_frame

	var gallery := (
		load("res://src/ui/hero_gallery_screen.tscn") as PackedScene
	).instantiate()
	add_child(gallery)
	await get_tree().create_timer(1.6).timeout

	var failures: Array[String] = []
	await _verify_name(gallery, 14, "h15", "七杀战鬼", failures)
	await _verify_name(gallery, 15, "h16", "白虹", failures)
	await _verify_name(gallery, 16, "h17", "同源万化妄真身", failures)
	await _verify_name(gallery, 17, "h18", "游丝引", failures)

	if failures.is_empty():
		print("GALLERY_SKILL_NAMES_PROBE_PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("GALLERY_SKILL_NAMES_PROBE: " + failure)
		get_tree().quit(1)


func _verify_name(
	gallery: Control,
	index: int,
	hero_id: String,
	expected: String,
	failures: Array[String],
) -> void:
	gallery._select(index)
	await get_tree().create_timer(0.35).timeout
	var hero := gallery.all_heroes[index] as HeroData
	if hero.hero_id != hero_id:
		failures.append("%s 索引错位：实际为 %s" % [hero_id, hero.hero_id])
	if hero.skill_description != expected:
		failures.append(
			"%s 资源技能名错误：期望「%s」，实际「%s」"
			% [hero_id, expected, hero.skill_description])
	if gallery._d_skill_name.text != expected:
		failures.append(
			"%s 图鉴技能名错误：期望「%s」，实际「%s」"
			% [hero_id, expected, gallery._d_skill_name.text])

	await RenderingServer.frame_post_draw
	var path := ProbeOutput.path("gallery_%s_skill_name.png" % hero_id)
	var error := get_viewport().get_texture().get_image().save_png(path)
	if error != OK:
		failures.append("%s 图鉴截图保存失败：%s" % [hero_id, error_string(error)])
	else:
		print("saved: ", path)
