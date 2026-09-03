class_name ItemData
extends Resource

## 道具数据（ADR-003 D1）。镜像 HeroData：纯数据，逻辑在 ItemEffect。
## 当前由 ItemCatalog 在代码里构造（避免几十个 .tres 文件·反过度工程）；后续若需 editor 编辑
## 或养成/图鉴引用，可平移为 assets/data/items/*.tres（Resource 形态已就绪）。
##
## legacy 字段继续供旧目录与旧测试读取。新版原型字段位于下方；新版使用费、耐久、
## 固定形状与真实实例状态不得从旧 PRE/POST 语义反推。

enum Seq { PRE, POST, ANY }   ## 序列标签：动作【前】/【后】/无关（§D4）。ANY 归入 PRE 桶。
enum Target { ENEMY, SELF }   ## 默认自动指向（§D6）：敌方出战 / 己方出战。

@export var item_id: String = ""
@export var item_name: String = ""
@export var tier: int = 1
@export var dimension: String = ""        ## 6 维之一（draft 加权用）
@export var role: String = ""             ## 元件角色（填隙/导出/随机…），可空
@export var sequence_tag: int = Seq.ANY
@export var target_mode: int = Target.ENEMY
@export var description: String = ""       ## 一句话机制描述（游戏内展示·Eddy 要求）
@export var flavor: String = ""            ## 风味文字（氛围/调性·区别于机制 description·Eddy 2026-06-27）
@export var ev_half: int = 1              ## 设计 EV（半点·≈0.5 当量 = 1）
@export var upgrade_to: String = ""       ## 升级线下一级道具 id（空=不可升级·ADR D5）
@export var params: Dictionary = {}       ## 效果数值（半点等），由 effect 读取

# === 新版20件单机原型字段 ===
@export var prototype_enabled: bool = false
@export_range(0, 4, 1) var use_cost: int = 0       ## 玩家显示能量单位；运行时乘 ActionDef.ENERGY_UNIT
@export_range(1, 99, 1) var max_durability: int = 1
@export var shape_cells: Array[Vector2i] = [Vector2i.ZERO]
@export var full_price: int = 0                    ## 金币整数值
@export var damaged_prices: Dictionary = {}        ## 剩余耐久(int) → 金币价(int)
@export var effect_key: StringName = &""
@export var target_key: StringName = &"none"
@export var icon_source_id: String = ""             ## 原型期临时复用旧图标；正式资产到位后清空

var effect: ItemEffect = null            ## 逻辑组件实例（无状态，可共享；非序列化）


## 解析使用时机（ANY → PRE）。
func resolved_when() -> int:
	return Seq.PRE if sequence_tag == Seq.ANY else sequence_tag


func is_prototype_v2() -> bool:
	return prototype_enabled


func grid_size() -> Vector2i:
	var max_cell := Vector2i.ZERO
	for cell: Vector2i in shape_cells:
		max_cell.x = maxi(max_cell.x, cell.x)
		max_cell.y = maxi(max_cell.y, cell.y)
	return max_cell + Vector2i.ONE


func cell_count() -> int:
	return shape_cells.size()


func price_for_durability(remaining: int) -> int:
	if remaining >= max_durability:
		return full_price
	return int(damaged_prices.get(remaining, 0))
