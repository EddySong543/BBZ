extends SceneTree


func _initialize() -> void:
	var stage := (load("res://src/ui/scenes/scene8.tscn") as PackedScene).instantiate()
	root.add_child(stage)
	_run_probe.call_deferred(stage)


func _run_probe(stage: Node) -> void:
	var controller := stage.get_node("CrystalSparkController")
	var passed := int(controller.call("crystal_count")) == 6
	var cluster_metrics: Array[Dictionary] = []
	for crystal_id: int in 6:
		var hit_position := Vector2(controller.call(
				"find_interactive_position_for_testing", crystal_id))
		var mapped_id := int(controller.call(
				"crystal_id_at_viewport_position_for_testing", hit_position))
		var interactive_pixels := int(controller.call(
				"interactive_pixel_count_for_testing", crystal_id))
		var rejected_palette_pixels := int(controller.call(
				"rejected_palette_pixel_count_for_testing", crystal_id))
		var rejected_position := Vector2(controller.call(
				"find_rejected_palette_position_for_testing", crystal_id))
		var annotation_excluded_pixels := int(controller.call(
				"annotation_excluded_pixel_count_for_testing", crystal_id))
		var annotation_excluded_position := Vector2(controller.call(
				"find_annotation_excluded_position_for_testing", crystal_id))
		var right2_edge_excluded_pixels := int(controller.call(
				"right2_edge_excluded_pixel_count_for_testing", crystal_id))
		var rejected_position_passed := (
				rejected_position.x < 0.0
				or int(controller.call(
						"crystal_id_at_viewport_position_for_testing", rejected_position)) == -1)
		var annotation_exclusion_passed := bool(controller.call(
				"annotation_exclusions_are_noninteractive_for_testing", crystal_id)) and (
				annotation_excluded_position.x < 0.0
				or int(controller.call(
						"crystal_id_at_viewport_position_for_testing",
						annotation_excluded_position)) == -1)
		var right2_edge_exclusion_passed := (
				crystal_id != 4
				or bool(controller.call(
						"right2_edge_exclusions_are_noninteractive_for_testing")))
		var cluster_passed := (
				hit_position.x >= 0.0
				and mapped_id == crystal_id
				and interactive_pixels >= 20
				and interactive_pixels <= 4000
				and rejected_position_passed
				and annotation_exclusion_passed
				and right2_edge_exclusion_passed)
		passed = passed and cluster_passed
		cluster_metrics.append({
			"id": crystal_id,
			"passed": cluster_passed,
			"interactive_pixels": interactive_pixels,
			"rejected_palette_pixels": rejected_palette_pixels,
			"rejected_position_passed": rejected_position_passed,
			"annotation_excluded_pixels": annotation_excluded_pixels,
			"annotation_exclusion_passed": annotation_exclusion_passed,
			"right2_edge_excluded_pixels": right2_edge_excluded_pixels,
			"right2_edge_exclusion_passed": right2_edge_exclusion_passed,
			"hit_position": hit_position,
		})
	controller.call("_process", 30.0)
	var no_automatic_burst := stage.get_node_or_null("Scene8CrystalFacetResponse") == null
	passed = passed and no_automatic_burst
	var first_hit := Vector2(controller.call(
			"find_interactive_position_for_testing", 0))
	var first_trigger := bool(controller.call(
			"trigger_spark_at_viewport_position", first_hit))
	var repeated_trigger := bool(controller.call(
			"trigger_spark_at_viewport_position", first_hit))
	var response := stage.get_node_or_null("Scene8CrystalFacetResponse") as Node2D
	var refraction := (
			response.get_node_or_null("FacetRefraction") as Node2D
			if response != null else null)
	var contract := Dictionary(controller.call(
			"active_response_contract_for_testing", response))
	var burst_valid: bool = (
			first_trigger
			and not repeated_trigger
			and refraction != null
			and response.get_node_or_null("PixelSparks") == null
			and String(contract.get("primitive", "")) == "facet_refraction"
			and int(contract.get("shard_count", 0)) == 3
			and is_equal_approx(float(contract.get("lifetime_sec", 0.0)), 0.64)
			and float(contract.get("facet_length_px", 0.0)) >= 18.0
			and float(contract.get("facet_length_px", 0.0)) <= 48.0)
	passed = passed and burst_valid
	print("SCENE8_CRYSTAL_REFRACTION: metrics=%s no_automatic=%s response_valid=%s contract=%s" % [
		cluster_metrics, no_automatic_burst, burst_valid, contract,
	])
	print("SCENE8_CRYSTAL_REFRACTION_PROBE: %s" % ("PASS" if passed else "FAIL"))
	stage.free()
	quit(0 if passed else 1)
