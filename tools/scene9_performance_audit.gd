extends SceneTree

## Image-free Scene9 performance audit. It separates the retained deterministic
## CPU test renderer from the live GPU-uniform update path, then inventories the
## current subdivided environment geometry.

const SCENE9_PATH := "res://src/ui/scenes/scene9.tscn"
const CLOUD_NAMES: Array[String] = [
	"DistantPixelCloudBank",
	"DistantPixelCloudBank2",
]
const MESH_NAMES: Array[String] = [
	"DistantRightMountain",
	"DistantLeftMountain",
	"DistantRight2",
	"DistantRight",
	"DistantLeft2",
	"DistantLeft",
	"ForegroundMid",
	"ForegroundLeft",
	"ForegroundRight",
]
const CLOUD_SAMPLE_COUNT := 24


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var setup_started_usec := Time.get_ticks_usec()
	var packed := load(SCENE9_PATH) as PackedScene
	if packed == null:
		push_error("Unable to load Scene9")
		quit(1)
		return
	var stage := packed.instantiate() as Control
	root.add_child(stage)
	await process_frame
	var setup_msec := float(Time.get_ticks_usec() - setup_started_usec) / 1000.0

	var cloud_results: Array[Dictionary] = []
	var cloud_update_total_msec := 0.0
	var cloud_upload_bytes_per_second := 0
	for cloud_name: String in CLOUD_NAMES:
		var cloud := stage.get_node_or_null(cloud_name) as TextureRect
		if cloud == null:
			continue
		cloud.set_process(false)
		var render_started_usec := Time.get_ticks_usec()
		for sample_index: int in CLOUD_SAMPLE_COUNT:
			cloud.call("render_frame_for_testing", sample_index * 7)
		var render_msec := float(
				Time.get_ticks_usec() - render_started_usec) / 1000.0
		var update_started_usec := Time.get_ticks_usec()
		for _sample_index: int in CLOUD_SAMPLE_COUNT:
			cloud.call("_process", 1.0 / 12.0)
		var update_msec := float(
				Time.get_ticks_usec() - update_started_usec) / 1000.0
		cloud_update_total_msec += update_msec
		var runtime_contract: Dictionary = cloud.call("runtime_contract_snapshot")
		cloud_upload_bytes_per_second += int(
				runtime_contract.get("recurring_texture_upload_bytes", 0)) * 12
		cloud_results.append({
			"node": cloud_name,
			"sample_count": CLOUD_SAMPLE_COUNT,
			"test_only_cpu_frame_build_total_msec": render_msec,
			"test_only_cpu_frame_build_average_msec": render_msec / CLOUD_SAMPLE_COUNT,
			"live_runtime_update_total_msec": update_msec,
			"live_runtime_update_average_msec": update_msec / CLOUD_SAMPLE_COUNT,
			"runtime_contract": runtime_contract,
		})

	var mesh_results: Array[Dictionary] = []
	var total_quads := 0
	var total_vertices := 0
	for mesh_name: String in MESH_NAMES:
		var mesh_node := stage.get_node_or_null(mesh_name) as Control
		if mesh_node == null:
			continue
		var columns := int(mesh_node.get("mesh_columns"))
		var rows := int(mesh_node.get("mesh_rows"))
		var quads := columns * rows
		var vertices := (columns + 1) * (rows + 1)
		total_quads += quads
		total_vertices += vertices
		mesh_results.append({
			"node": mesh_name,
			"columns": columns,
			"rows": rows,
			"quads": quads,
			"vertices": vertices,
		})

	var report := {
		"scene_setup_msec": setup_msec,
		"clouds": cloud_results,
		"cloud_live_updates_msec_for_24_frames_each": cloud_update_total_msec,
		"cloud_runtime_upload_bytes_per_second": cloud_upload_bytes_per_second,
		"animated_meshes": mesh_results,
		"animated_mesh_total_quads": total_quads,
		"animated_mesh_total_triangles": total_quads * 2,
		"animated_mesh_total_vertices": total_vertices,
	}
	print("SCENE9_PERFORMANCE_AUDIT ", JSON.stringify(report, "  "))
	stage.queue_free()
	await process_frame
	quit(0)
