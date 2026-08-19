extends GutTest

## T2 加权抽卡池（2026-07-04）行为锁定测试。
## 护栏：① 3 候选互不重复（修旧放回抽样 bug）② 道具维度命中我方阵容 → 2× 加权
## （只认阵容标签不认战况·每局静态）③ 小保底 = 3 候选至少跨 2 个维度。
## 种子固定 → 取样统计确定性，阈值断言不会随机翻红。

const SEED := 20260704
const SAMPLES := 400
const DIMS_6 := ["进攻", "防御", "能量", "节奏", "状态", "干扰"]


func _hero(id: String, dim: String = "") -> HeroData:
	var h := HeroData.new()
	h.hero_id = id
	h.hero_name = id
	h.max_hp = 10
	h.skill_type = HeroData.SkillType.PASSIVE
	h.dimension = dim
	return h


func _battle(dims: Array = ["", "", ""]) -> BattleCore:
	var b := BattleCore.new()
	b.setup([_hero("test_a", dims[0]), _hero("test_b", dims[1]), _hero("test_c", dims[2])],
		[_hero("test_x"), _hero("test_y"), _hero("test_z")], SEED)
	b.econ_init()
	return b


## 反复取样 begin_draft（每次清槽内缓存重新生成）。返回 Array[Array[ItemData]]。
func _sample_drafts(b: BattleCore, n: int) -> Array:
	var out: Array = []
	for _i in range(n):
		b.slots[0][1]["draft"] = []
		out.append((b.begin_draft(0, 1) as Array).duplicate())
	return out


## 全部取样里维度 = dim 的候选占比。
func _dim_share(drafts: Array, dim: String) -> float:
	var hit: int = 0
	var total: int = 0
	for draft in drafts:
		for it in draft:
			total += 1
			if (it as ItemData).dimension == dim:
				hit += 1
	return float(hit) / float(total)


# === 数据：24 首发英雄兼容维度标签（六维仅服务 T2 加权，不再承担人数配额）===

func test_hero_pool_launch_dimensions_are_valid_and_all_represented() -> void:
	# Arrange
	var counts: Dictionary = {}
	for d in DIMS_6:
		counts[d] = 0
	# Act
	var pool: Array[HeroData] = HeroData.create_launch_pool()
	# Assert
	assert_eq(pool.size(), 24, "首发池 = h01-h24")
	for h in pool:
		assert_true(counts.has(h.dimension), "%s dimension=「%s」须为 6 维之一" % [h.hero_id, h.dimension])
		if counts.has(h.dimension):
			counts[h.dimension] = int(counts[h.dimension]) + 1
	for d in DIMS_6:
		assert_gt(int(counts[d]), 0, "兼容维度「%s」至少应有一名英雄，保证 T2 加权仍可覆盖" % d)


# === 护栏 ①：3 候选互不重复 ===

func test_draft_candidates_no_duplicate_items() -> void:
	# Arrange
	var b := _battle()
	# Act
	var bad: int = 0
	for draft in _sample_drafts(b, SAMPLES):
		var ids: Dictionary = {}
		for it in draft:
			ids[(it as ItemData).item_id] = true
		if ids.size() != 3:
			bad += 1
	# Assert
	assert_eq(bad, 0, "同一次 3 选 1 内不得出现重复道具（旧放回抽样 bug）")


# === 护栏 ②：命中阵容维度 → 加权更常出现（对照无标签阵容）===

func test_draft_lineup_dimension_items_appear_more_often() -> void:
	# Arrange：全进攻阵容 vs 无标签阵容（同池·同种子对照）
	var b_atk := _battle(["进攻", "进攻", "进攻"])
	var b_plain := _battle()
	# Act
	var share_atk: float = _dim_share(_sample_drafts(b_atk, SAMPLES), "进攻")
	var share_plain: float = _dim_share(_sample_drafts(b_plain, SAMPLES), "进攻")
	# Assert：T1 池进攻 5/19 → 无权重基准 ≈26%、2× 加权首抽 ≈42%（不放回+小保底略拉低）
	assert_gt(share_atk, share_plain + 0.05, "命中阵容维度的道具应显著更常出现（2× 加权）")
	assert_gt(share_atk, 0.30, "加权后进攻件占比应明显高于 26% 无权重基准")


# === 护栏 ③：小保底 = 3 候选至少跨 2 个维度 ===

func test_draft_candidates_span_at_least_two_dimensions() -> void:
	# Arrange：全进攻阵容 = 最容易凑出 3 同维的极端情况
	var b := _battle(["进攻", "进攻", "进攻"])
	# Act
	var mono: int = 0
	for draft in _sample_drafts(b, SAMPLES):
		var dims: Dictionary = {}
		for it in draft:
			dims[(it as ItemData).dimension] = true
		if dims.size() < 2:
			mono += 1
	# Assert
	assert_eq(mono, 0, "小保底：任一次 3 选 1 的候选至少覆盖 2 个维度")
