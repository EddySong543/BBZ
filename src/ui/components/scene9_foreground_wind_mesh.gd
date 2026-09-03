@tool
extends "res://src/ui/components/scene5_wheat_mesh.gd"

## Scene9-local contract wrapper around the proven Scene5 subdivided mesh.
## The shader owns rendering; these helpers expose the actual local material
## profile for image-free root-lock and readable-tip-motion verification.

const WIND_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene9_foreground_wind.gdshader")


func wind_contract_snapshot() -> Dictionary:
	var shader_material := material as ShaderMaterial
	if shader_material == null:
		return {}
	return {
		"shader_path": shader_material.shader.resource_path,
		"resource_local_to_scene": shader_material.resource_local_to_scene,
		"source_size": texture.get_size() if texture != null else Vector2.ZERO,
		"mesh_columns": mesh_columns,
		"mesh_rows": mesh_rows,
		"geometry_y_start": _parameter_float(shader_material, &"geometry_y_start"),
		"root_y": _parameter_float(shader_material, &"root_y"),
		"root_lock_depth": _parameter_float(shader_material, &"root_lock_depth"),
		"cycle_sec": _parameter_float(shader_material, &"cycle_sec"),
		"sway_px": _parameter_float(shader_material, &"sway_px"),
		"branch_detail_px": _parameter_float(
				shader_material, &"branch_detail_px"),
		"gust_px": _parameter_float(shader_material, &"gust_px"),
		"phase_seed": _parameter_float(shader_material, &"phase_seed"),
		"root_locked": displacement_for_testing(
				Vector2(0.5, _parameter_float(shader_material, &"root_y")),
				1.75).is_zero_approx(),
	}


func displacement_for_testing(uv: Vector2, time_seconds: float) -> Vector2:
	var shader_material := material as ShaderMaterial
	if shader_material == null:
		return Vector2.ZERO
	var geometry_start := _parameter_float(
			shader_material, &"geometry_y_start")
	var geometry_feather := _parameter_float(
			shader_material, &"geometry_y_feather")
	var root := _parameter_float(shader_material, &"root_y")
	var lock_depth := _parameter_float(shader_material, &"root_lock_depth")
	var active := smoothstep(
			geometry_start - geometry_feather,
			geometry_start + geometry_feather,
			uv.y)
	var height_ratio := clampf(
			(root - uv.y) / maxf(root - geometry_start, 0.001), 0.0, 1.0)
	var root_pin := 1.0 - smoothstep(root - lock_depth, root, uv.y)
	var bend_weight := pow(height_ratio,
			_parameter_float(shader_material, &"bend_power")) * active * root_pin
	var local_position := Vector2(size.x * uv.x, size.y * uv.y)
	var world_x: float = (get_global_transform() * local_position).x
	var cluster_count := maxf(
			_parameter_float(shader_material, &"branch_clusters"), 2.0)
	var cluster_phase := floorf(uv.x * cluster_count) / cluster_count * TAU
	var base_phase: float = time_seconds * TAU / maxf(
			_parameter_float(shader_material, &"cycle_sec"), 0.001) \
			+ world_x * 0.0055 \
			+ _parameter_float(shader_material, &"phase_seed")
	var shared_sway := sin(base_phase) * 0.72 \
			+ sin(base_phase * 0.57 - 0.95) * 0.28
	var branch_sway := sin(base_phase * 1.73 + cluster_phase * 0.82 \
			+ uv.y * TAU * 0.65)
	var gust_phase: float = time_seconds * TAU / maxf(
			_parameter_float(shader_material, &"gust_cycle_sec"), 0.001) \
			- world_x * 0.004 \
			+ _parameter_float(shader_material, &"phase_seed") * 0.47
	var gust_front := pow(maxf(sin(gust_phase), 0.0), 2.2)
	var horizontal_offset := (
			_parameter_float(shader_material, &"sway_px") * shared_sway \
			+ _parameter_float(shader_material, &"branch_detail_px") * branch_sway \
			+ _parameter_float(shader_material, &"gust_px") * gust_front)
	var lift := _parameter_float(shader_material, &"branch_lift_px") \
			* (shared_sway * 0.5 + 0.5) \
			+ gust_front * _parameter_float(
					shader_material, &"branch_lift_px") * 0.35
	var strength := _parameter_float(shader_material, &"motion_strength")
	return Vector2(horizontal_offset, -lift) * bend_weight * strength


func _parameter_float(shader_material: ShaderMaterial,
		parameter_name: StringName) -> float:
	return float(shader_material.get_shader_parameter(parameter_name))
