extends SceneTree

## 无截图 Boot 验收：中英文标题均不再创建加号或加号投影节点。


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://src/ui/boot_screen.tscn") as PackedScene
	if packed == null:
		push_error("BOOT_TITLE_PLUS_REMOVAL_PROBE: scene failed to load")
		quit(1)
		return
	var boot := packed.instantiate() as Control
	root.add_child(boot)
	await process_frame
	var title := boot.get_node("TitleColumn") as Control
	var failures: Array[String] = []
	for node_name: String in [
		"ChinesePlus",
		"ChinesePlusShadow",
		"EnglishPlus",
		"EnglishPlusShadow",
	]:
		if title.get_node_or_null(node_name) != null:
			failures.append("obsolete plus node remains: %s" % node_name)
	if not failures.is_empty():
		push_error("BOOT_TITLE_PLUS_REMOVAL_PROBE: %s" % "; ".join(failures))
		quit(1)
		return
	print("BOOT_TITLE_PLUS_REMOVAL_PROBE_OK: chinese=none english=none shadows=none")
	quit(0)
