extends GutTest

const ExpeditionLoot := preload("res://src/expedition/expedition_loot.gd")


func test_frozen_prototype_pool_has_exactly_twenty_complete_items() -> void:
	var items: Array[ItemData] = ItemCatalog.all_active()
	assert_eq(items.size(), 20)
	assert_eq(ItemCatalog.all_active_for_tier(1).size(), 12)
	assert_eq(ItemCatalog.all_active_for_tier(2).size(), 5)
	assert_eq(ItemCatalog.all_active_for_tier(3).size(), 3)
	var costs: Dictionary = {}
	var durabilities: Dictionary = {}
	var total_cells: int = 0
	var total_price: int = 0
	for item: ItemData in items:
		assert_true(item.is_prototype_v2(), item.item_id)
		assert_false(item.item_name.is_empty(), item.item_id)
		assert_false(item.description.is_empty(), item.item_id)
		assert_false(String(item.effect_key).is_empty(), item.item_id)
		assert_gt(item.cell_count(), 0, item.item_id)
		assert_gt(item.full_price, 0, item.item_id)
		costs[item.use_cost] = int(costs.get(item.use_cost, 0)) + 1
		durabilities[item.max_durability] = int(
			durabilities.get(item.max_durability, 0)) + 1
		total_cells += item.cell_count()
		total_price += item.full_price
	assert_eq(costs, {0: 4, 1: 11, 2: 3, 3: 2})
	assert_eq(durabilities, {1: 12, 2: 6, 3: 2})
	assert_eq(total_cells, 39)
	assert_eq(total_price, 526_000)


func test_thorn_bracer_uses_approved_single_use_value() -> void:
	var item: ItemData = ItemCatalog.make("v2_t1_thorn_bracer")
	assert_eq(item.max_durability, 1)
	assert_eq(item.full_price, 24_000)
	assert_true(item.damaged_prices.is_empty())


func test_legacy_items_remain_directly_loadable_but_are_not_active() -> void:
	assert_not_null(ItemCatalog.make("t1_feibiao"))
	assert_false(ItemCatalog.is_prototype_id("t1_feibiao"))
	assert_eq(ItemCatalog.icon_path("t1_feibiao"),
			"res://assets/sprites/items/legacy/生锈的暗器.png")
	assert_false(ItemCatalog.all_active().any(
		func(item: ItemData) -> bool:
			return item.item_id == "t1_feibiao"))
	for item: ItemData in ItemCatalog.all_active():
		assert_eq(ItemCatalog.icon_path(item.item_id),
				"res://assets/sprites/items/v2/%s.png" % item.item_name,
				"新版每件道具都拥有可独立调方向的同名正式资产")


func test_first_art_batch_uses_approved_names_copy_and_initial_shapes() -> void:
	var expected: Dictionary = {
		"v2_t1_whetstone": {
			"name": "生锈的飞镖",
			"description": "我方下一次「波」增加1点伤害。",
			"shape": [Vector2i(0, 0), Vector2i(1, 0)],
			"icon": "res://assets/sprites/items/v2/生锈的飞镖.png",
		},
		"v2_t1_cracked_shield": {
			"name": "银质护臂",
			"shape": [Vector2i(0, 0), Vector2i(0, 1)],
			"icon": "res://assets/sprites/items/v2/银质护臂.png",
		},
		"v2_t1_blood_medicine": {
			"name": "普通治疗药水",
			"shape": [Vector2i(0, 0)],
			"icon": "res://assets/sprites/items/v2/普通治疗药水.png",
		},
		"v2_t1_silver_coin": {
			"name": "瓶装能量",
			"shape": [Vector2i(0, 0)],
			"icon": "res://assets/sprites/items/v2/瓶装能量.png",
		},
		"v2_t2_teleport_scroll": {
			"name": "传送卷轴",
			"shape": [Vector2i(0, 0), Vector2i(0, 1)],
			"icon": "res://assets/sprites/items/v2/传送卷轴.png",
		},
		"v2_t1_salamander_oil": {
			"name": "锋利的飞镖",
			"description": "我方下一次「大波」额外增加1点伤害。",
			"shape": [Vector2i(0, 0), Vector2i(1, 0)],
			"icon": "res://assets/sprites/items/v2/锋利的飞镖.png",
		},
		"v2_t1_heart_guard": {
			"name": "银鳞甲",
			"shape": [Vector2i(0, 0), Vector2i(1, 0)],
			"icon": "res://assets/sprites/items/v2/银鳞甲.png",
		},
		"v2_t1_mana_potion": {
			"name": "普通魔力药水",
			"shape": [Vector2i(0, 0)],
			"icon": "res://assets/sprites/items/v2/普通魔力药水.png",
		},
		"v2_t1_armor_hammer": {
			"name": "短柄铁钩",
			"shape": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
			"icon": "res://assets/sprites/items/v2/短柄铁钩.png",
		},
		"v2_t1_healing_salve": {
			"name": "简易治愈法杖",
			"shape": [Vector2i(0, 0), Vector2i(1, 0)],
			"icon": "res://assets/sprites/items/v2/简易治愈法杖.png",
		},
		"v2_t1_smoke_bottle": {
			"name": "袋装石灰粉",
			"shape": [Vector2i(0, 0), Vector2i(0, 1)],
			"icon": "res://assets/sprites/items/v2/袋装石灰粉.png",
		},
	}
	for item_id: String in expected:
		var item: ItemData = ItemCatalog.make(item_id)
		var item_expected: Dictionary = expected[item_id]
		assert_eq(item.item_name, item_expected["name"], item_id)
		assert_eq(item.shape_cells, item_expected["shape"], item_id)
		assert_eq(ItemCatalog.icon_path(item_id), item_expected["icon"], item_id)
		if item_expected.has("description"):
			assert_eq(item.description, item_expected["description"], item_id)


func test_first_art_batch_assets_preserve_authored_grid_sizes() -> void:
	var expected_sizes: Dictionary = {
		"res://assets/sprites/items/v2/生锈的飞镖.png": Vector2i(64, 32),
		"res://assets/sprites/items/v2/银质护臂.png": Vector2i(32, 64),
		"res://assets/sprites/items/v2/瓶装能量.png": Vector2i(32, 32),
		"res://assets/sprites/items/v2/传送卷轴.png": Vector2i(32, 64),
		"res://assets/sprites/items/v2/锋利的飞镖.png": Vector2i(64, 32),
		"res://assets/sprites/items/v2/银鳞甲.png": Vector2i(64, 32),
		"res://assets/sprites/items/v2/短柄铁钩.png": Vector2i(96, 32),
		"res://assets/sprites/items/v2/简易治愈法杖.png": Vector2i(64, 32),
		"res://assets/sprites/items/v2/袋装石灰粉.png": Vector2i(32, 64),
		"res://assets/ui/icons/item_durability.png": Vector2i(32, 32),
	}
	for path: String in expected_sizes:
		var texture := load(path) as Texture2D
		assert_not_null(texture, "正式资产可加载：%s" % path)
		if texture == null:
			continue
		assert_eq(Vector2i(texture.get_size()), expected_sizes[path], path)
		assert_ne(texture.get_image().detect_alpha(), Image.ALPHA_NONE,
				"道具与角标保留透明背景：%s" % path)
	var consumed_sources: Array[String] = [
		"生锈的飞镖.png", "银质护臂.png", "瓶装能量.png", "传送卷轴.png",
		"锋利的飞镖.png", "银鳞甲.png", "短柄铁钩.png", "简易治愈法杖.png",
		"袋装石灰粉.png", "耐久.png",
	]
	for filename: String in consumed_sources:
		assert_false(FileAccess.file_exists("res://assets/import/" + filename),
				"已接入资产不继续滞留收件箱：%s" % filename)


func test_expedition_combat_loot_uses_each_items_fixed_shape_price_and_durability() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9_020_026
	for tier: int in [1, 2, 3]:
		for _sample: int in range(20):
			var loot: Dictionary = ExpeditionLoot.make_combat(rng, tier)
			var item: ItemData = ItemCatalog.make(String(loot["combat_id"]))
			assert_not_null(item)
			assert_eq(loot["shape"], item.shape_cells, item.item_id)
			assert_eq(int(loot["gold"]), item.full_price, item.item_id)
			assert_eq(int(loot["current_durability"]), item.max_durability, item.item_id)
			assert_eq(int(loot["max_durability"]), item.max_durability, item.item_id)
			assert_eq(loot["damaged_prices"], item.damaged_prices, item.item_id)
