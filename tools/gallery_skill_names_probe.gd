extends SceneTree

## 英雄技能名图鉴回归探针：
## 真实实例化英雄图鉴，逐个选中目标英雄，校验资源与右页显示文字。


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	var gallery := (
		load("res://src/ui/hero_gallery_screen.tscn") as PackedScene
	).instantiate()
	root.add_child(gallery)
	await create_timer(1.6).timeout

	var failures: Array[String] = []
	await _verify_name(gallery, 6, "h07", "千里快哉风", failures)
	await _verify_name(gallery, 13, "h14", "血铸荼蘼", failures)
	await _verify_name(gallery, 14, "h15", "魇镇八极", failures)
	await _verify_name(gallery, 15, "h16", "白虹", failures)
	await _verify_name(gallery, 16, "h17", "无我亦无穷", failures)
	await _verify_name(gallery, 17, "h18", "游丝引", failures)

	if failures.is_empty():
		print("GALLERY_SKILL_NAMES_PROBE_PASS")
		quit(0)
	else:
		for failure in failures:
			push_error("GALLERY_SKILL_NAMES_PROBE: " + failure)
		quit(1)


func _verify_name(
	gallery: Control,
	index: int,
	hero_id: String,
	expected: String,
	failures: Array[String],
) -> void:
	gallery._select(index)
	await create_timer(0.35).timeout
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
