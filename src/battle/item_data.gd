class_name ItemData
extends Resource

## 道具数据（ADR-003 D1）。镜像 HeroData：纯数据，逻辑在 ItemEffect。
## 当前由 ItemCatalog 在代码里构造（避免几十个 .tres 文件·反过度工程）；后续若需 editor 编辑
## 或养成/图鉴引用，可平移为 assets/data/items/*.tres（Resource 形态已就绪）。
##
## 道具规则（§0.1）：不占动作槽 · 使用免费 · 一回合用量不限 · 揭示前盲选提交 · 对对手公开。

enum Seq { PRE, POST, ANY }   ## 序列标签：动作【前】/【后】/无关（§D4）。ANY 归入 PRE 桶。
enum Target { ENEMY, SELF }   ## 默认自动指向（§D6）：敌方出战 / 己方出战。

@export var item_id: String = ""
@export var item_name: String = ""
@export var tier: int = 1
@export var dimension: String = ""        ## 6 维之一（draft 加权用）
@export var role: String = ""             ## 元件角色（填隙/导出/随机…），可空
@export var sequence_tag: int = Seq.ANY
@export var target_mode: int = Target.ENEMY
@export var description: String = ""       ## 一句话描述（游戏内展示·Eddy 要求）
@export var ev_half: int = 1              ## 设计 EV（半点·≈0.5 当量 = 1）
@export var params: Dictionary = {}       ## 效果数值（半点等），由 effect 读取

var effect: ItemEffect = null            ## 逻辑组件实例（无状态，可共享；非序列化）


## 解析使用时机（ANY → PRE）。
func resolved_when() -> int:
	return Seq.PRE if sequence_tag == Seq.ANY else sequence_tag
