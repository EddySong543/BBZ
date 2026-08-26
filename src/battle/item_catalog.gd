class_name ItemCatalog
extends RefCounted

## 道具目录（ADR-003 D1）。集中数据源：id → 元数据 + 一句话描述 + 效果参数 + 逻辑脚本。
## 逻辑在 src/battle/items/<id>.gd（继承 ItemEffect）。make(id) 构造一件 ItemData（含独立 effect 实例）。
##
## 当前已实装 = 正式池 114 件（T1 34 / T2 52 / T3 28·含中立 / 趣味）= design/items-firstrelease.md（真相源）。
## 全集候选与历史废案见 design/items-list.md；未入选件按版本逐批复审。
##
## 道具均为字符串 id（tier 前缀拼音），无数字编号。⚠ id 拼音为历史化石、≠ 当前显示名
## （如 t1_xiangjiaopi=「臭鸡蛋」、t1_lingdang=「STEAL技能卡」）——id 是内部稳定主键、永不展示给玩家，
## 故不随显示名改名。显示名 item_name 已与 design/items-list.md 对齐。
## 美术：图标按约定路径 ICON_DIR/<中文显示名>.png 加载（见底部 icon_path / load_icon）；缺图时 UI 回退占位文字。
## 2026-08-13 新增 11 件 T1 的名称与图标均为占位，正式机制文案已锁；后续替换命名 / 美术时同步映射与 i18n。

const _S_PRE := ItemData.Seq.PRE
const _S_ANY := ItemData.Seq.ANY
const _T_ENEMY := ItemData.Target.ENEMY

# 道具稀有度方案 2「三角洲高识别色」的唯一基准色：蓝 / 紫 / 金。
# 图鉴侧签、道具框、背包占格、抽取/升级和远征语义色均应引用这里。
const RARITY_NORMAL := Color("3F7ED0")
const RARITY_RARE := Color("7249BC")
const RARITY_LEGENDARY := Color("CB8B24")
const _T_SELF := ItemData.Target.SELF

## id → {name, dim, role, seq, target, desc(一句话), params, script}
const _DEF := {
	# --- 1A 进攻 ---
	"t1_feibiao": {
		name = "生锈的暗器", dim = "进攻", role = "填隙", seq = _S_ANY, target = _T_ENEMY,
		desc = "对敌方出战英雄造成1点伤害。", params = {dmg = 2}, upgrade = "t2_feibiao",
		script = preload("res://src/battle/items/t1_feibiao.gd")},
	"t1_xianshou": {
		name = "先手", dim = "进攻", role = "填隙", seq = _S_PRE, target = _T_SELF,
		desc = "本回合内，我方下一次攻击造成的伤害增加1点。", params = {bonus = 2}, upgrade = "t2_shuangsheng",
		script = preload("res://src/battle/items/t1_xianshou.gd")},
	"t1_dutu_yingbi": {
		name = "赌徒的硬币", dim = "进攻", role = "随机", seq = _S_PRE, target = _T_SELF,
		desc = "本回合内，我方下一次攻击造成的伤害增加2点，或使敌方下一次攻击造成的伤害增加2点。", params = {bonus = 4},
		script = preload("res://src/battle/items/t1_dutu_yingbi.gd")},
	"t1_podun_zhou": {
		name = "银质穿甲箭", dim = "进攻", role = "破防", seq = _S_PRE, target = _T_SELF,
		desc = "本回合内，若敌方使用「防」，我方「波」的伤害增加1点并穿防。", params = {bonus = 2}, upgrade = "t2_pomoshi",
		script = preload("res://src/battle/items/t1_podun_zhou.gd")},
	# --- 1B 防御 ---
	"t1_jiudun": {
		name = "破旧的护甲", dim = "防御", role = "填隙", seq = _S_ANY, target = _T_SELF,
		desc = "我方出战英雄获得1点护甲。", params = {armor = 2}, upgrade = "t2_jiandun",
		script = preload("res://src/battle/items/t1_jiudun.gd")},
	"t1_houshou": {
		name = "后手", dim = "防御", role = "条件", seq = _S_ANY, target = _T_SELF,
		desc = "本回合内，若敌方攻击，我方出战英雄存活获得1.5点护甲。", params = {armor = 3}, upgrade = "t2_nuanyu",
		script = preload("res://src/battle/items/t1_houshou.gd")},
	"t1_lzhi_shengming": {
		name = "劣质生命药水", dim = "防御", role = "治疗", seq = _S_ANY, target = _T_SELF,
		desc = "我方出战英雄回复1点生命。", params = {heal = 2}, upgrade = "t2_shengming",
		script = preload("res://src/battle/items/t1_lzhi_shengming.gd")},
	"t1_qipao": {
		name = "残缺的佛像", dim = "防御", role = "条件", seq = _S_ANY, target = _T_SELF,
		desc = "本回合内，若敌方本回合使用「大波」且我方使用「防」，该「防」可以挡下这次「大波」。", params = {},
		script = preload("res://src/battle/items/t1_qipao.gd")},
	"t1_tongqian": {
		name = "算命铜钱", dim = "博弈", role = "对冲", seq = _S_ANY, target = _T_SELF,
		desc = "本回合内，若敌方攻击，我方出战英雄获得1点护甲；否则我方获得1点能量。", params = {armor = 2, energy = 2}, upgrade = "t2_mojing",
		script = preload("res://src/battle/items/t1_tongqian.gd")},
	# --- 1C 能量 ---
	"t1_lzhi_fali": {
		name = "劣质法力药水", dim = "能量", role = "条件", seq = _S_ANY, target = _T_SELF,
		desc = "本回合内，若我方使用「攒」，我方额外获得1点能量。", params = {energy = 2}, upgrade = "t2_fali",
		script = preload("res://src/battle/items/t1_lzhi_fali.gd")},
	# --- 1D 状态 ---
	"t1_yaohuo": {
		name = "妖火", dim = "状态", role = "", seq = _S_ANY, target = _T_ENEMY,
		desc = "点燃敌方出战英雄，下回合结束前，若该英雄仍在场上则失去1.5点生命。", params = {loss = 3}, upgrade = "t2_duyao",
		script = preload("res://src/battle/items/t1_yaohuo.gd")},
	# --- 1E 干扰 ---
	"t1_xiangjiaopi": {
		name = "臭鸡蛋", dim = "干扰", role = "填隙", seq = _S_ANY, target = _T_ENEMY,
		desc = "本回合内，若敌方攻击，该攻击的总伤害减少1点。", params = {penalty = 2}, upgrade = "t2_dingshen",
		script = preload("res://src/battle/items/t1_xiangjiaopi.gd")},
	# --- 1F 导出 ---
	"t1_xixie_yaya": {
		name = "血魔的獠牙", dim = "导出", role = "进攻→防御", seq = _S_PRE, target = _T_SELF,
		desc = "本回合的下次攻击命中时，我方出战英雄回复等同于伤害的生命。", params = {}, upgrade = "t2_jike",
		script = preload("res://src/battle/items/t1_xixie_yaya.gd")},
	"t1_moli_yuanquan": {
		name = "盗版太极图", dim = "导出", role = "防御→能量", seq = _S_ANY, target = _T_SELF,
		desc = "本回合内，若成功防御，我方获得1点能量。", params = {energy = 2}, upgrade = "t2_huoshou",
		script = preload("res://src/battle/items/t1_moli_yuanquan.gd")},
	# --- 1G 扩展（含变体 / 净化 / 节奏 / 随机）---
	# 注：「毒刺」（命中下毒）已删 —— 与翼火【蛇】 h06【神打】功能完全相同，禁撞英雄（Eddy 2026-06-18）。
	"t1_siyecao": {
		name = "最后一箭", dim = "进攻", role = "斩杀", seq = _S_PRE, target = _T_SELF,
		desc = "本回合内，我方下一次攻击的总伤害增加1.5点；若这次攻击没有击败目标，我方出战英雄失去1点生命。", params = {bonus = 3, backlash = 2},
		script = preload("res://src/battle/items/t1_siyecao.gd")},
	"t1_hushenfu": {
		name = "圣贤书", dim = "防御", role = "净化", seq = _S_ANY, target = _T_SELF,
		desc = "本回合内，敌方对我方施加的第一个非伤害道具效果无效。", params = {immune = 1}, upgrade = "t2_fengyin",
		script = preload("res://src/battle/items/t1_hushenfu.gd")},
	"t1_fengzhixue": {
		name = "回马枪", dim = "节奏", role = "", seq = _S_ANY, target = _T_SELF,
		desc = "本回合内，我方若「切换」，下回合第一次攻击的总伤害增加1.5点。", params = {bonus = 3}, upgrade = "t2_caoren",
		script = preload("res://src/battle/items/t1_fengzhixue.gd")},
	# --- 1H 普通池连接件扩充（2026-08-13·占位命名 / 美术）---
	"t1_deneng_hufu": {
		name = "得能护符", dim = "防御", role = "能量→防御", seq = _S_ANY, target = _T_SELF,
		desc = "本回合内，我方第一次获得非回合被动能量时，出战英雄获得1点护甲。", params = {armor = 2},
		script = preload("res://src/battle/items/t1_deneng_hufu.gd")},
	"t1_fentong_mupai": {
		name = "分痛木牌", dim = "中立", role = "分摊", seq = _S_ANY, target = _T_SELF,
		desc = "本回合内，我方出战英雄受到的下一次伤害中，1点改由生命最高的另一名存活队友承受。", params = {redirect = 2},
		script = preload("res://src/battle/items/t1_fentong_mupai.gd")},
	"t1_huanfang_kou": {
		name = "换防扣", dim = "节奏", role = "切换→防御", seq = _S_ANY, target = _T_SELF,
		desc = "本回合内，我方切换后，登场英雄获得1点护甲。", params = {armor = 2},
		script = preload("res://src/battle/items/t1_huanfang_kou.gd")},
	"t1_houzhen_qian": {
		name = "候阵签", dim = "节奏", role = "延后登场", seq = _S_ANY, target = _T_SELF,
		desc = "选择我方一名未出战英雄，本回合结束时令其登场。", params = {},
		script = preload("res://src/battle/items/t1_houzhen_qian.gd")},
	"t1_jijiu_ling": {
		name = "急救铃", dim = "导出", role = "进攻→治疗", seq = _S_PRE, target = _T_SELF,
		desc = "本回合内，我方下一次攻击命中时，生命最低的存活英雄回复1点生命。", params = {heal = 2},
		script = preload("res://src/battle/items/t1_jijiu_ling.gd")},
	"t1_yazhen_zhui": {
		name = "压阵坠", dim = "导出", role = "防御→干扰", seq = _S_ANY, target = _T_SELF,
		desc = "本回合内，我方用「大防」挡下「波」时，敌方失去1点能量。", params = {energy_loss = 2},
		script = preload("res://src/battle/items/t1_yazhen_zhui.gd")},
	"t1_huifeng_qiao": {
		name = "回锋鞘", dim = "防御", role = "受阻补偿", seq = _S_ANY, target = _T_SELF,
		desc = "本回合内，我方下一次「波」被成功防御时，出战英雄获得1.5点护甲。", params = {armor = 3},
		script = preload("res://src/battle/items/t1_huifeng_qiao.gd")},
	"t1_xuzhen_qi": {
		name = "续阵旗", dim = "节奏", role = "阵亡接替", seq = _S_ANY, target = _T_SELF,
		desc = "本回合内，我方出战英雄若死亡，下一名登场英雄获得2点护甲。", params = {armor = 4},
		script = preload("res://src/battle/items/t1_xuzhen_qi.gd")},
	"t1_xuedu_jie": {
		name = "血渡结", dim = "中立", role = "生命转移", seq = _S_ANY, target = _T_SELF,
		desc = "我方出战英雄失去1点生命，生命最低的另一名存活英雄回复2点生命。", params = {loss = 2, heal = 4},
		script = preload("res://src/battle/items/t1_xuedu_jie.gd")},
	"t1_tengman_xianjing": {
		name = "藤蔓陷阱", dim = "干扰", role = "切换惩罚", seq = _S_ANY, target = _T_ENEMY,
		desc = "本回合内，敌方切换后，换下的英雄受到1点伤害。", params = {damage = 2},
		script = preload("res://src/battle/items/t1_tengman_xianjing.gd")},
	"t1_jiedu_yaoshui": {
		name = "解毒药水", dim = "防御", role = "净化", seq = _S_ANY, target = _T_SELF,
		desc = "清除我方出战英雄的毒素；若没有毒素则清除脆弱。成功清除后，其回复1点生命。", params = {heal = 2},
		script = preload("res://src/battle/items/t1_jiedu_yaoshui.gd")},
	"t1_xunxing_zhui": {
		name = "寻星坠", dim = "进攻", role = "指定目标", seq = _S_PRE, target = _T_SELF,
		desc = "本回合内，我方下一次「波」可以指定任意一名敌方英雄，但总伤害减少0.5点。", params = {penalty = 1},
		script = preload("res://src/battle/items/t1_xunxing_zhui.gd")},

	# ========== Tier-2（连携件·稳定件约 2 点价值·规则件以条件/反制换取收益）==========
	# --- 2A 进攻 ---
	"t2_feibiao": {
		tier = 2, ev = 4, name = "锋利的飞镖", dim = "进攻", role = "填隙", seq = _S_ANY, target = _T_ENEMY,
		desc = "对敌方出战英雄造成2点伤害。", params = {dmg = 4},
		script = preload("res://src/battle/items/t2_feibiao.gd")},
	"t2_shuangsheng": {
		tier = 2, ev = 4, name = "双生咒符", dim = "进攻", role = "泛连携", seq = _S_PRE, target = _T_SELF,
		desc = "本回合内，我方下一次攻击的总伤害增加1点；由命中触发的英雄技能额外触发1次。", params = {bonus = 2, triggers = 1},
		script = preload("res://src/battle/items/t2_shuangsheng.gd")},
	"t2_shitiechong": {
		tier = 2, ev = 4, name = "噬铁虫", dim = "进攻", role = "破防", seq = _S_PRE, target = _T_ENEMY,
		desc = "本回合内，敌方的「防」「大防」降低一级。", params = {steps = 1},
		script = preload("res://src/battle/items/t2_shitiechong.gd")},
	"t2_pomoshi": {
		tier = 2, ev = 4, name = "破魔矢", dim = "进攻", role = "穿透", seq = _S_PRE, target = _T_SELF,
		desc = "本回合内，我方下一次「波」的总伤害增加1点并穿防。", params = {bonus = 2},
		script = preload("res://src/battle/items/t2_pomoshi.gd")},
	"t2_qiubite": {
		tier = 2, ev = 4, name = "心脏掌握魔法", dim = "进攻", role = "穿甲", seq = _S_PRE, target = _T_SELF,
		desc = "本回合内，我方下一次攻击改为造成真实伤害。", params = {},
		script = preload("res://src/battle/items/t2_qiubite.gd")},
	"t2_daijia": {
		tier = 2, ev = 4, name = "力量的代价", dim = "进攻", role = "牺牲", seq = _S_PRE, target = _T_SELF,
		desc = "本回合内，我方「波」和「大波」的伤害增加2点，本回合结束我方出战英雄死亡。", params = {bonus = 4},
		script = preload("res://src/battle/items/t2_daijia.gd")},
	"t2_difeng_kou": {
		tier = 2, ev = 4, name = "抵锋扣", dim = "导出", role = "防→攻", seq = _S_PRE, target = _T_SELF,
		desc = "移除我方出战英雄至多2点护甲；本回合内，我方下一次攻击的总伤害增加等量。", params = {max_armor = 4},
		script = preload("res://src/battle/items/t2_difeng_kou.gd")},
	"t2_fuying_suo": {
		tier = 2, ev = 4, name = "缚影索", dim = "干扰", role = "锁定目标", seq = _S_PRE, target = _T_ENEMY,
		desc = "锁定敌方出战英雄；本回合内，我方下一次攻击仍以该英雄为目标，即使其切换下场。", params = {},
		script = preload("res://src/battle/items/t2_fuying_suo.gd")},
	"t2_jieyin_pei": {
		tier = 2, ev = 4, name = "借印佩", dim = "进攻", role = "英雄连携", seq = _S_PRE, target = _T_SELF,
		desc = "选择我方一名未出战英雄；本回合我方下一次攻击命中时，也结算该英雄的「印记」。", params = {},
		script = preload("res://src/battle/items/t2_jieyin_pei.gd")},
	"t2_dianjiang_gu": {
		tier = 2, ev = 4, name = "点将鼓", dim = "进攻", role = "阵型干扰", seq = _S_PRE, target = _T_ENEMY,
		desc = "本回合我方下一次攻击命中后，使敌方生命最低的未出战英雄登场。", params = {},
		script = preload("res://src/battle/items/t2_dianjiang_gu.gd")},
	# --- 2B 防御 ---
	"t2_jiandun": {
		tier = 2, ev = 4, name = "坚固的护甲", dim = "防御", role = "填隙", seq = _S_ANY, target = _T_SELF,
		desc = "我方出战英雄获得2点护甲。", params = {armor = 4},
		script = preload("res://src/battle/items/t2_jiandun.gd")},
	"t2_huanhundan": {
		tier = 2, ev = 4, name = "还魂丹", dim = "防御", role = "救援", seq = _S_ANY, target = _T_SELF,
		desc = "直到本局结束，使用该道具的英雄免疫1次致命伤害。每名英雄限用1次。", params = {charges = 1},
		script = preload("res://src/battle/items/t2_huanhundan.gd")},
	"t2_huizhao_jing": {
		tier = 2, ev = 4, name = "回照镜", dim = "防御", role = "反制", seq = _S_ANY, target = _T_SELF,
		desc = "本回合内，反制敌方对我方使用的第一件道具。", params = {charges = 1},
		script = preload("res://src/battle/items/t2_huizhao_jing.gd")},
	"t2_lianxin_suo": {
		tier = 2, ev = 4, name = "连心锁", dim = "中立", role = "分摊", seq = _S_PRE, target = _T_SELF,
		desc = "本回合内，我方出战英雄受到的下一次攻击伤害由我方所有存活英雄平均承受。", params = {},
		script = preload("res://src/battle/items/t2_lianxin_suo.gd")},
	"t2_yijia_huan": {
		tier = 2, ev = 4, name = "移甲环", dim = "防御", role = "护甲调度", seq = _S_PRE, target = _T_SELF,
		desc = "选择我方一名存活英雄，将我方全队的护甲转移给该英雄。", params = {},
		script = preload("res://src/battle/items/t2_yijia_huan.gd")},
	"t2_huzhen_ding": {
		tier = 2, ev = 4, name = "护阵钉", dim = "防御", role = "替补保护", seq = _S_PRE, target = _T_SELF,
		desc = "选择我方一名未出战英雄，使其获得2点护甲。", params = {armor = 4},
		script = preload("res://src/battle/items/t2_huzhen_ding.gd")},
	"t2_daishang_san": {
		tier = 2, ev = 4, name = "代伤伞", dim = "防御", role = "目标调度", seq = _S_PRE, target = _T_SELF,
		desc = "选择我方一名未出战英雄；本回合敌方下一次攻击改以其为目标。", params = {},
		script = preload("res://src/battle/items/t2_daishang_san.gd")},
	# --- 2C 治疗 ---
	"t2_shengming": {
		tier = 2, ev = 4, name = "普通生命药水", dim = "防御", role = "治疗", seq = _S_ANY, target = _T_SELF,
		desc = "我方出战英雄回复2点生命。", params = {heal = 4}, upgrade = "t3_shengming",
		script = preload("res://src/battle/items/t2_shengming.gd")},
	"t2_nuanyu": {
		tier = 2, ev = 4, name = "暖玉", dim = "防御", role = "治疗", seq = _S_ANY, target = _T_SELF,
		desc = "本回合内，若成功防御，我方所有存活英雄各回复1点生命。", params = {heal = 2},
		script = preload("res://src/battle/items/t2_nuanyu.gd")},
	"t2_ningxue_gao": {
		tier = 2, ev = 4, name = "凝血膏", dim = "导出", role = "治疗→护甲", seq = _S_PRE, target = _T_SELF,
		desc = "本回合内，我方所有生命回复改为获得等量护甲。", params = {},
		script = preload("res://src/battle/items/t2_ningxue_gao.gd")},
	"t2_guiying_pai": {
		tier = 2, ev = 4, name = "归营牌", dim = "调度", role = "切换治疗", seq = _S_PRE, target = _T_SELF,
		desc = "我方下一次切换时，换下的英雄回复2点生命。", params = {heal = 4},
		script = preload("res://src/battle/items/t2_guiying_pai.gd")},
	"t2_xingjun_yaonang": {
		tier = 2, ev = 4, name = "行军药囊", dim = "防御", role = "替补治疗", seq = _S_PRE, target = _T_SELF,
		desc = "选择我方一名未出战英雄，使其回复2点生命。", params = {heal = 4},
		script = preload("res://src/battle/items/t2_xingjun_yaonang.gd")},
	# --- 2D 能量 ---
	"t2_fali": {
		tier = 2, ev = 4, name = "普通法力药水", dim = "能量", role = "条件", seq = _S_ANY, target = _T_SELF,
		desc = "本回合内，若我方使用「攒」，我方额外获得2点能量。", params = {energy = 4}, upgrade = "t3_fali",
		script = preload("res://src/battle/items/t2_fali.gd")},
	"t2_baolie": {
		tier = 2, ev = 4, name = "爆裂卷轴", dim = "能量", role = "条件", seq = _S_ANY, target = _T_SELF,
		desc = "本回合内，我方「大波」少消耗2点能量。", params = {save = 4},
		script = preload("res://src/battle/items/t2_baolie.gd")},
	# --- 2E 节奏 ---
	# --- 2F 状态 ---
	"t2_duyao": {
		tier = 2, ev = 4, name = "毒药瓶", dim = "状态", role = "连携", seq = _S_ANY, target = _T_ENEMY,
		desc = "使敌方出战英雄获得3层毒素。", params = {poison = 3},
		script = preload("res://src/battle/items/t2_duyao.gd")},
	"t2_lieyin": {
		tier = 2, ev = 4, name = "猎物印记", dim = "状态", role = "易伤", seq = _S_ANY, target = _T_ENEMY,
		desc = "敌方出战英雄获得3层脆弱。", params = {vuln = 3},
		script = preload("res://src/battle/items/t2_lieyin.gd")},
	# --- 2G 干扰 ---
	"t2_dingshen": {
		tier = 2, ev = 4, name = "定身符", dim = "干扰", role = "元件层", seq = _S_ANY, target = _T_ENEMY,
		desc = "直到下回合结束，敌方的切换无效。", params = {turns = 2},
		script = preload("res://src/battle/items/t2_dingshen.gd")},
	"t2_zhenwen_zhen": {
		tier = 2, ev = 4, name = "镇纹针", dim = "干扰", role = "命中封技", seq = _S_PRE, target = _T_ENEMY,
		desc = "本回合内，敌方由「波」或「大波」命中触发的英雄技能无效。", params = {},
		script = preload("res://src/battle/items/t2_zhenwen_zhen.gd")},
	"t2_fencun_chi": {
		tier = 2, ev = 4, name = "分寸尺", dim = "博弈", role = "对称限伤", seq = _S_PRE, target = _T_SELF,
		desc = "本回合内，双方每次攻击的总伤害最多为1点。", params = {cap = 2},
		script = preload("res://src/battle/items/t2_fencun_chi.gd")},
	"t2_fengmai_zhen": {
		tier = 2, ev = 4, name = "封脉针", dim = "干扰", role = "对称禁疗", seq = _S_PRE, target = _T_SELF,
		desc = "本回合内，双方无法回复生命。", params = {},
		script = preload("res://src/battle/items/t2_fengmai_zhen.gd")},
	"t2_suoquan_sai": {
		tier = 2, ev = 4, name = "锁泉塞", dim = "干扰", role = "禁能", seq = _S_ANY, target = _T_ENEMY,
		desc = "下回合，敌方无法获得能量。", params = {},
		script = preload("res://src/battle/items/t2_suoquan_sai.gd")},
	"t2_shizhi_jiasuo": {
		tier = 2, ev = 4, name = "时滞枷锁", dim = "干扰", role = "道具延迟", seq = _S_PRE, target = _T_ENEMY,
		desc = "选择敌方一件锁定中的道具，使其延迟1回合可用。", params = {turns = 1},
		script = preload("res://src/battle/items/t2_shizhi_jiasuo.gd")},
	"t2_miwu_doupeng": {
		tier = 2, ev = 4, name = "迷雾斗篷", dim = "博弈", role = "信息隐藏", seq = _S_PRE, target = _T_SELF,
		desc = "我方道具栏对敌方隐藏，直到我方使用一件道具。", params = {},
		script = preload("res://src/battle/items/t2_miwu_doupeng.gd")},
	# --- 2H 导出 ---
	"t2_jike": {
		tier = 2, ev = 4, name = "扭曲的饥渴", dim = "导出", role = "攻→防", seq = _S_PRE, target = _T_SELF,
		desc = "本回合内，我方下一次攻击命中时，我方所有存活英雄各回复1点生命。", params = {heal = 2},
		script = preload("res://src/battle/items/t2_jike.gd")},
	"t2_huoshou": {
		tier = 2, ev = 4, name = "秘银充能护手", dim = "导出", role = "攻→能", seq = _S_PRE, target = _T_SELF,
		desc = "本回合内，我方下一次攻击命中时，获得1.5点能量。", params = {energy = 3},
		script = preload("res://src/battle/items/t2_huoshou.gd")},
	# ========== Tier-3（传说 / build-around·2026-08-10 整体优化）==========
	"t3_longxi": {
		tier = 3, ev = 6, name = "龙息", dim = "进攻", role = "自成核", seq = _S_PRE, target = _T_SELF,
		desc = "本回合内，我方「大波」的基础伤害翻倍；若该「大波」被「大防」挡下，我方下回合无法行动。", params = {},
		script = preload("res://src/battle/items/t3_longxi.gd")},
	"t3_yujin": {
		tier = 3, ev = 6, name = "不死鸟的羽毛", dim = "进攻", role = "自成核", seq = _S_PRE, target = _T_SELF,
		desc = "本回合内，我方下一次攻击时，若出战英雄生命不超过1点，该攻击的总伤害增加3点并穿大防。", params = {threshold = 2, bonus = 6},
		script = preload("res://src/battle/items/t3_yujin.gd")},
	"t3_jianyi": {
		tier = 3, ev = 6, name = "至臻剑意", dim = "进攻", role = "蓄势", seq = _S_PRE, target = _T_SELF,
		desc = "本回合内，我方「波」若命中，下回合第一次「大波」不消耗能量。", params = {},
		script = preload("res://src/battle/items/t3_jianyi.gd")},
	"t3_shengming": {
		tier = 3, ev = 6, name = "上等生命药水", dim = "防御", role = "治疗", seq = _S_ANY, target = _T_SELF,
		desc = "我方出战英雄回复3点生命。", params = {heal = 6},
		script = preload("res://src/battle/items/t3_shengming.gd")},
	"t3_fali": {
		tier = 3, ev = 6, name = "上等法力药水", dim = "能量", role = "", seq = _S_ANY, target = _T_SELF,
		desc = "我方立即获得4点能量。", params = {energy = 8},
		script = preload("res://src/battle/items/t3_fali.gd")},
	"t3_tinglong": {
		tier = 3, ev = 6, name = "停龙剑", dim = "能量", role = "能→攻", seq = _S_PRE, target = _T_ENEMY,
		desc = "耗尽我方全部能量，每1点能量对敌方出战英雄造成0.5点伤害并穿大防。", params = {},
		script = preload("res://src/battle/items/t3_tinglong.gd")},

	# ========== Tier-3 遗物（跨回合·次数 / 回合 / 条件）==========
	"t3_judingsanhua": {
		tier = 3, ev = 6, name = "聚鼎三花", dim = "进攻", role = "遗物", seq = _S_ANY, target = _T_SELF,
		desc = "我方接下来3次攻击若命中，由命中触发的英雄技能各额外触发1次。", params = {relic = true, hits = 1, charges = 3, stack_mode = "extend_charges"},
		script = preload("res://src/battle/items/t3_judingsanhua.gd")},
	"t3_shixinding": {
		tier = 3, ev = 6, name = "噬心钉", dim = "进攻", role = "遗物", seq = _S_ANY, target = _T_SELF,
		desc = "从本回合起，我方攻击的总伤害增加1点，若我方有一回合没有攻击，回合结束时出战英雄失去3点生命并结束此效果。", params = {relic = true, bonus = 2, backlash = 6, stack_mode = "unique"},
		script = preload("res://src/battle/items/t3_shixinding.gd")},
	"t3_budongmingwang": {
		tier = 3, ev = 6, name = "不动明王甲", dim = "防御", role = "遗物", seq = _S_ANY, target = _T_SELF,
		desc = "我方接下来3次成功防御时，出战英雄获得等同于该攻击总伤害的护甲。", params = {relic = true, charges = 3, stack_mode = "extend_charges"},
		script = preload("res://src/battle/items/t3_budongmingwang.gd")},
	"t3_xumingxiang": {
		tier = 3, ev = 6, name = "续命香", dim = "防御", role = "遗物", seq = _S_ANY, target = _T_SELF,
		desc = "本回合起的3回合内，我方出战英雄每回合回复1.5点生命", params = {relic = true, heal = 3, turns = 3, stack_mode = "extend_turns"},
		script = preload("res://src/battle/items/t3_xumingxiang.gd")},
	"t3_qingyuanbaolian": {
		tier = 3, ev = 6, name = "青元宝莲", dim = "能量", role = "遗物", seq = _S_ANY, target = _T_SELF,
		desc = "本回合起的3回合内，我方每回合额外获得1.5点能量", params = {relic = true, energy = 3, turns = 3, stack_mode = "extend_turns"},
		script = preload("res://src/battle/items/t3_qingyuanbaolian.gd")},

	# ========== Phase 3A 纯逻辑件（切换替身 / 强制切换 / 信息博弈）==========
	"t2_caoren": {
		tier = 2, ev = 4, name = "替身草人", dim = "节奏", role = "切换", seq = _S_ANY, target = _T_SELF,
		desc = "本回合内，我方切换后，敌方本回合攻击落空。", params = {},
		script = preload("res://src/battle/items/t2_caoren.gd")},
	"t3_yiqi": {
		tier = 3, ev = 6, name = "周天罡气", dim = "博弈", role = "信息", seq = _S_ANY, target = _T_SELF,
		desc = "本回合无敌。", params = {},
		script = preload("res://src/battle/items/t3_yiqi.gd")},

	# ========== 首发补全：节奏/状态/干扰 capstone + 中立/趣味/meta 留种（2026-06-24·items-firstrelease）==========
	"t1_weihouzhen": {
		name = "尾后针", dim = "中立", role = "结构", seq = _S_ANY, target = _T_SELF,
		desc = "本回合内，我方出战英雄若死亡，对当时的敌方出战英雄造成2点伤害。", params = {damage = 4}, upgrade = "t2_lieyin",
		script = preload("res://src/battle/items/t1_weihouzhen.gd")},
	"t1_ronglu": {
		name = "随身熔炉", dim = "中立", role = "meta", seq = _S_ANY, target = _T_SELF,
		desc = "选择并烧掉另一件可使用的道具，立即获得2点能量。", params = {energy = 4}, upgrade = "t2_dianjinshi",
		script = preload("res://src/battle/items/t1_ronglu.gd")},
	"t2_fengyin": {
		tier = 2, ev = 4, name = "封印卷轴", dim = "干扰", role = "元件层", seq = _S_ANY, target = _T_ENEMY,
		desc = "敌方下回合使用的第一件道具无效。", params = {seals = 1},
		script = preload("res://src/battle/items/t2_fengyin.gd")},
	"t2_mojing": {
		tier = 2, ev = 4, name = "闪亮的魔晶", dim = "中立", role = "结构", seq = _S_ANY, target = _T_SELF,
		desc = "我方立即获得3点能量，下回合开始时失去1点能量。", params = {energy = 6, penalty = 2},
		script = preload("res://src/battle/items/t2_mojing.gd")},
	"t2_dianjinshi": {
		tier = 2, ev = 4, name = "点金石", dim = "中立", role = "meta", seq = _S_ANY, target = _T_SELF,
		desc = "选择另一件可使用的普通道具，将其立即升级为传说道具。", params = {},
		script = preload("res://src/battle/items/t2_dianjinshi.gd")},
	"t3_yemingzhu": {
		tier = 3, ev = 6, name = "夜明珠", dim = "节奏", role = "遗物", seq = _S_ANY, target = _T_SELF,
		desc = "我方接下来3次切换时，对敌方出战英雄造成1点伤害，切换登场的英雄获得1点护甲。", params = {relic = true, charges = 3, dmg = 2, armor = 2, stack_mode = "extend_charges"},
		script = preload("res://src/battle/items/t3_yemingzhu.gd")},
	"t3_hedinghong": {
		tier = 3, ev = 6, name = "鹤顶红", dim = "状态", role = "遗物", seq = _S_ANY, target = _T_SELF,
		desc = "我方接下来引爆毒素时，每层毒素伤害额外增加1点。", params = {relic = true, charges = 1, bonus_per_layer = 2, stack_mode = "extend_charges"},
		script = preload("res://src/battle/items/t3_hedinghong.gd")},
	"t3_tianluodiwang": {
		tier = 3, ev = 6, name = "天罗地网", dim = "干扰", role = "一次性", seq = _S_ANY, target = _T_ENEMY,
		desc = "本回合内，敌方的首件道具和「切换」无效", params = {},
		script = preload("res://src/battle/items/t3_tianluodiwang.gd")},
	"t3_mengdie": {
		tier = 3, ev = 6, name = "梦蝶", dim = "趣味", role = "一次性", seq = _S_ANY, target = _T_SELF,
		desc = "将我方与敌方的能量，道具栏整体对调。", params = {},
		script = preload("res://src/battle/items/t3_mengdie.gd")},
	"t3_morihuozhong": {
		tier = 3, ev = 6, name = "末日火种", dim = "中立", role = "结构", seq = _S_ANY, target = _T_SELF,
		desc = "若我方仅剩1名英雄存活，则其所有攻击额外造成1点伤害，所有防御额外获得1点护甲，直到对局结束。", params = {relic = true, atk = 2, armor = 2, stack_mode = "unique"},
		script = preload("res://src/battle/items/t3_morihuozhong.gd")},
	"t3_sanqi_zhong": {
		tier = 3, ev = 6, name = "散契钟", dim = "中立", role = "清场", seq = _S_PRE, target = _T_SELF,
		desc = "结束双方所有已生效的道具效果。", params = {},
		script = preload("res://src/battle/items/t3_sanqi_zhong.gd")},
	"t3_zhaohun_fan": {
		tier = 3, ev = 6, name = "招魂幡", dim = "防御", role = "复活", seq = _S_PRE, target = _T_SELF,
		desc = "选择我方一名已死亡英雄，使其以1点生命复活并成为未出战英雄。", params = {hp = 2},
		script = preload("res://src/battle/items/t3_zhaohun_fan.gd")},
	"t3_lianhuan_gu": {
		tier = 3, ev = 6, name = "连环鼓", dim = "节奏", role = "双行动", seq = _S_PRE, target = _T_SELF,
		desc = "本回合内，我方依次执行两个不同的行动（不含切换和英雄技能）。", params = {},
		script = preload("res://src/battle/items/t3_lianhuan_gu.gd")},
	"t3_jubao_pen": {
		tier = 3, ev = 6, name = "聚宝盆", dim = "能量", role = "遗物", seq = _S_ANY, target = _T_SELF,
		desc = "直到对局结束，每回合结束时，若我方道具栏有空位，随机补入1件普通道具。", params = {relic = true, stack_mode = "unique"},
		script = preload("res://src/battle/items/t3_jubao_pen.gd")},
	"t3_sheming_quan": {
		tier = 3, ev = 6, name = "赊命券", dim = "能量", role = "透支", seq = _S_ANY, target = _T_SELF,
		desc = "立即获得6点能量；下回合我方无法行动。", params = {energy = 12},
		script = preload("res://src/battle/items/t3_sheming_quan.gd")},
	"t3_huanming_qi": {
		tier = 3, ev = 6, name = "换命契", dim = "中立", role = "调度", seq = _S_PRE, target = _T_SELF,
		desc = "选择我方一名未出战英雄，交换其与出战英雄的当前生命和护甲。", params = {},
		script = preload("res://src/battle/items/t3_huanming_qi.gd")},
	"t3_jieming_deng": {
		tier = 3, ev = 6, name = "借命灯", dim = "能量", role = "生命换能", seq = _S_PRE, target = _T_SELF,
		desc = "我方能量补满，然后出战英雄的生命降至1点。", params = {hp = 2},
		script = preload("res://src/battle/items/t3_jieming_deng.gd")},
	"t3_qingnang_huopen": {
		tier = 3, ev = 6, name = "清囊火盆", dim = "中立", role = "道具清场", seq = _S_PRE, target = _T_SELF,
		desc = "本回合结束时，双方烧掉所有仍可使用的道具；每烧掉1件，所属玩家获得1点能量。", params = {energy = 2},
		script = preload("res://src/battle/items/t3_qingnang_huopen.gd")},
	"t3_junneng_dou": {
		tier = 3, ev = 6, name = "均能斗", dim = "博弈", role = "能量重分", seq = _S_PRE, target = _T_SELF,
		desc = "合并双方当前能量，再平均分配。", params = {},
		script = preload("res://src/battle/items/t3_junneng_dou.gd")},
	# ========== 背包构筑首批（The Bazaar / Backpack Battles 启发）==========
	"t1_jicun_pai": {
		name = "寄存牌", dim = "能量", role = "背包转换", seq = _S_ANY, target = _T_SELF,
		desc = "选择另一件可使用的道具，将其随机放回背包，立即获得1点能量。", params = {energy = 2, requires_backpack = true},
		script = preload("res://src/battle/items/t1_jicun_pai.gd")},
	"t1_tingxia_tong": {
		name = "听匣筒", dim = "博弈", role = "背包信息", seq = _S_ANY, target = _T_ENEMY,
		desc = "随机揭示敌方背包中至多3件道具，直到本场战斗结束。", params = {count = 3, requires_backpack = true},
		script = preload("res://src/battle/items/t1_tingxia_tong.gd")},
	"t2_yawu_piao": {
		tier = 2, ev = 4, name = "押物票", dim = "博弈", role = "道具读心", seq = _S_PRE, target = _T_ENEMY,
		desc = "押注敌方一件可使用的道具；本回合其若被使用，我方获得2点能量。", params = {energy = 4, requires_backpack = true},
		script = preload("res://src/battle/items/t2_yawu_piao.gd")},
	"t2_huigou_quan": {
		tier = 2, ev = 4, name = "回购券", dim = "中立", role = "临时复制", seq = _S_ANY, target = _T_SELF,
		desc = "选择本场已经使用的一件普通道具，将1件同名临时道具随机放入背包。", params = {requires_backpack = true},
		script = preload("res://src/battle/items/t2_huigou_quan.gd")},
	"t2_baojia_feng": {
		tier = 2, ev = 4, name = "保价封", dim = "防御", role = "反制保值", seq = _S_PRE, target = _T_SELF,
		desc = "选择另一件可使用的道具；本回合它若被反制，则不消耗并随机放回背包。", params = {requires_backpack = true},
		script = preload("res://src/battle/items/t2_baojia_feng.gd")},
	"t2_yingji_xiang": {
		tier = 2, ev = 4, name = "应急箱", dim = "中立", role = "即时补充", seq = _S_ANY, target = _T_SELF,
		desc = "从自己的背包随机抽取1件普通道具，填入本物腾出的道具框并立即可用。", params = {requires_backpack = true},
		script = preload("res://src/battle/items/t2_yingji_xiang.gd")},
	"t2_huanqian_tong": {
		tier = 2, ev = 4, name = "换签筒", dim = "中立", role = "背包换件", seq = _S_ANY, target = _T_SELF,
		desc = "选择另一件道具，将其随机放回背包，随后免费抽取一次道具。", params = {requires_backpack = true},
		script = preload("res://src/battle/items/t2_huanqian_tong.gd")},
	"t2_chenglu_zhan": {
		tier = 2, ev = 4, name = "承露盏", dim = "导出", role = "治疗→能量", seq = _S_PRE, target = _T_SELF,
		desc = "本回合内，我方溢出的生命回复转为等量能量。", params = {requires_backpack = true},
		script = preload("res://src/battle/items/t2_chenglu_zhan.gd")},
	"t2_naying_hulu": {
		tier = 2, ev = 4, name = "纳盈葫芦", dim = "导出", role = "能量→治疗", seq = _S_PRE, target = _T_SELF,
		desc = "本回合内，我方获得的溢出能量转为回复生命最低的存活英雄。", params = {requires_backpack = true},
		script = preload("res://src/battle/items/t2_naying_hulu.gd")},
	# ========== 参考游戏转译批（Marvel Snap / 宝可梦 / 洛克王国 / 游戏王）==========
	"t1_gufeng_zhui": {
		name = "孤锋锥", dim = "进攻", role = "孤注", seq = _S_PRE, target = _T_SELF,
		desc = "仅当我方没有其他可使用的道具时使用；本回合内，我方下一次攻击的总伤害增加2点。", params = {bonus = 4},
		script = preload("res://src/battle/items/t1_gufeng_zhui.gd")},
	"t2_cuiyong_pai": {
		tier = 2, ev = 4, name = "催用牌", dim = "博弈", role = "道具施压", seq = _S_PRE, target = _T_ENEMY,
		desc = "选择敌方一件可使用的道具；本回合结束时若仍未使用，将其锁定1回合。", params = {},
		script = preload("res://src/battle/items/t2_cuiyong_pai.gd")},
	"t2_dingming_wan": {
		tier = 2, ev = 4, name = "定命丸", dim = "防御", role = "保底治疗", seq = _S_PRE, target = _T_SELF,
		desc = "我方出战英雄的生命不足3点时，回复至3点。", params = {hp = 6},
		script = preload("res://src/battle/items/t2_dingming_wan.gd")},
	"t2_duyong_feng": {
		tier = 2, ev = 4, name = "独用封", dim = "干扰", role = "道具限流", seq = _S_PRE, target = _T_SELF,
		desc = "本回合内，双方只有首件道具生效。", params = {},
		script = preload("res://src/battle/items/t2_duyong_feng.gd")},
	"t2_pianfeng_jia": {
		tier = 2, ev = 4, name = "偏锋甲", dim = "博弈", role = "攻击分流", seq = _S_PRE, target = _T_SELF,
		desc = "本回合内，敌方「波」无法对我方造成伤害，但其「大波」的总伤害增加2点。", params = {big_bonus = 4},
		script = preload("res://src/battle/items/t2_pianfeng_jia.gd")},
	"t3_xiling_ling": {
		tier = 3, ev = 6, name = "息灵铃", dim = "干扰", role = "技能清场", seq = _S_PRE, target = _T_SELF,
		desc = "本回合内，双方所有英雄技能无效。", params = {},
		script = preload("res://src/battle/items/t3_xiling_ling.gd")},
	"t2_jingwen_zhou": {
		tier = 2, ev = 4, name = "净纹帚", dim = "状态", role = "命中成果清场", seq = _S_PRE, target = _T_SELF,
		desc = "清除双方所有由攻击命中产生、尚未结算的英雄技能效果。", params = {},
		script = preload("res://src/battle/items/t2_jingwen_zhou.gd")},
	"t3_yiyuan_deng": {
		tier = 3, ev = 6, name = "遗愿灯", dim = "节奏", role = "牺牲调度", seq = _S_PRE, target = _T_SELF,
		desc = "使我方出战英雄死亡；死亡结算成功后，选择我方一名未出战英雄，使其回复至生命上限并登场。本回合我方无法行动。", params = {},
		script = preload("res://src/battle/items/t3_yiyuan_deng.gd")},
	"t2_huiliu_zhu": {
		tier = 2, ev = 4, name = "回流珠", dim = "能量", role = "精确支付", seq = _S_PRE, target = _T_SELF,
		desc = "本回合内，我方行动若正好耗尽能量，行动结算后获得2点能量。", params = {energy = 4},
		script = preload("res://src/battle/items/t2_huiliu_zhu.gd")},
}


## 道具名 → 风味文字（flavor·氛围/调性·与机制 desc 分离）。空缺 = 不显示。
## ⚠ 按【显示名】索引（直接对应 design/items-firstrelease.md 每行末尾 *斜体* 的风味文字·Eddy 撰写）。
## 名唯一（name_to_id 防重），故可作键；若改道具显示名须同步此处键。
const _FLAVOR := {
	# 进攻
	"周天罡气": "无敌是多么寂寞",
	"生锈的暗器": "虚日【鼠】再三强调，这可不是M9刺刀（★） | 外表生锈",
	"先手": "先手！在波波攒里！",
	"最后一箭": "向这黑暗世界输送一丝光明！",
	"银质穿甲箭": "银质箭头，不错的选择",
	"锋利的飞镖": "虚日【鼠】推荐，性价比之选",
	"双生咒符": "鬼金【羊】做第一个咒符时手抖了，才有了第二个",
	"噬铁虫": "温馨提示：不要让噬铁虫靠近您自己的护甲",
	"破魔矢": "只失手过一次，那次对面是真的清白",
	"心脏掌握魔法": "把你的心给我~把你的爱给我~~",
	"龙息": "“请放心，我睡觉不打呼噜。”亢金【龙】如是说",
	"不死鸟的羽毛": "还没完呢",
	"至臻剑意": "万剑归一，唯快不破",
	"聚鼎三花": "警告：看见南天门和白玉京时请立即停止使用",
	"噬心钉": "在遥远的第 40 个千年...",
	# 防御
	"破旧的护甲": "肯定能在古董市场卖个好价钱",
	"后手": "抱歉，这里没有幸运币",
	"残缺的佛像": "临时抱佛脚",
	"圣贤书": "一心只读圣贤书",
	"坚固的护甲": "盾狗",
	"还魂丹": "死神说一粒能续一命，但没说续的只是一口气",
	"不动明王甲": "胜利的秘诀是守赢",
	# 治疗
	"劣质生命药水": "老板，这生命药水发绿是正常的吗？",
	"普通生命药水": "味道一般，疗效一般，贵的不一般",
	"暖玉": "谦谦君子，温润如玉",
	"上等生命药水": "82 年的生命药水",
	"续命香": "台前拜三拜，血量多几百",
	# 能量
	"劣质法力药水": "假一赔十...前提是你还活着",
	"普通法力药水": "效果稳定，没兑水",
	"爆裂卷轴": "Explosion！",
	"上等法力药水": "82 年的法力药水",
	"青元宝莲": "天下十大奇物之一",
	"停龙剑": "接着蓄力就好",
	# 节奏
	"回马枪": "三十六计跑为上，三十七技回马枪 —— 星日【马】",
	"夜明珠": "闪亮登场~",
	# 状态
	"妖火": "这就是为什么鬼金【羊】不喜欢火焰魔法",
	"毒药瓶": "这也是生命药水，相信我",
	"猎物印记": "👀...",
	"鹤顶红": "百分之百自动好评！",
	# 干扰
	"臭鸡蛋": "蛋神神了",
	"封印卷轴": "这可封不了九只尾巴的大狐狸",
	"力量的代价": "那么，古XX，代价是什么呢...",
	"定身符": "紫火【猴】从来没用定身符偷吃桃子，从来没有，这是原则问题",
	"天罗地网": "无处可逃",
	# 导出
	"血魔的獠牙": "据说原主人已经戒血了",
	"盗版太极图": "接，化，发！",
	"扭曲的饥渴": "灵感源自一位大海盗",
	"秘银充能护手": "尾火【虎】的上一副护手，每挥一拳都能回本",
	# 博弈
	"算命铜钱": "天机不可泄露，但护甲和能量可以",
	# 趣味
	"赌徒的硬币": "会赢的",
	"梦蝶": "是我变成了你，还是你变成了我",
	# 中立
	"尾后针": "你的路断了",
	"闪亮的魔晶": "亮闪闪",
	"末日火种": "我要打十个！",
	# 系统操作层
	"随身熔炉": "蜘蛛大师的得意之作，不得意的都进去了",
	"点金石": "点石成金，可惜点不了第二次",
}


## 玩家显示顺序：先按 tier，再按显示名的【完整无声调拼音】排序；同拼音以稳定 id 兜底。
## 不使用中文 Unicode 码点或历史 id 排序。多音字口径：还=huan、秘=mi、血=xue。
const DISPLAY_ORDER := [
	# T1（34）
	"t1_qipao", "t1_xiangjiaopi", "t1_moli_yuanquan", "t1_deneng_hufu",
	"t1_dutu_yingbi", "t1_fentong_mupai", "t1_gufeng_zhui", "t1_houshou", "t1_houzhen_qian", "t1_huanfang_kou",
	"t1_huifeng_qiao", "t1_fengzhixue", "t1_jicun_pai", "t1_jiedu_yaoshui", "t1_jijiu_ling",
	"t1_lzhi_fali", "t1_lzhi_shengming", "t1_jiudun", "t1_hushenfu",
	"t1_feibiao", "t1_tongqian", "t1_ronglu", "t1_tengman_xianjing", "t1_tingxia_tong",
	"t1_weihouzhen", "t1_xianshou", "t1_xuedu_jie", "t1_xixie_yaya",
	"t1_xunxing_zhui", "t1_xuzhen_qi", "t1_yaohuo", "t1_yazhen_zhui",
	"t1_podun_zhou", "t1_siyecao",
	# T2（52）
	"t2_baojia_feng", "t2_baolie", "t2_chenglu_zhan", "t2_cuiyong_pai", "t2_daishang_san", "t2_dianjiang_gu", "t2_dianjinshi", "t2_difeng_kou", "t2_dingming_wan", "t2_dingshen", "t2_duyao", "t2_duyong_feng",
	"t2_fencun_chi", "t2_feibiao", "t2_fengmai_zhen", "t2_fengyin", "t2_fuying_suo",
	"t2_guiying_pai", "t2_huanhundan", "t2_huanqian_tong", "t2_huigou_quan", "t2_huiliu_zhu", "t2_huizhao_jing", "t2_huzhen_ding", "t2_jiandun", "t2_jieyin_pei", "t2_jingwen_zhou",
	"t2_lianxin_suo", "t2_lieyin", "t2_daijia", "t2_miwu_doupeng", "t2_huoshou", "t2_naying_hulu", "t2_ningxue_gao", "t2_jike", "t2_nuanyu",
	"t2_pianfeng_jia", "t2_pomoshi", "t2_fali", "t2_shengming", "t2_mojing", "t2_shitiechong",
	"t2_shizhi_jiasuo", "t2_shuangsheng", "t2_suoquan_sai", "t2_caoren", "t2_xingjun_yaonang",
	"t2_qiubite", "t2_yawu_piao", "t2_yijia_huan", "t2_yingji_xiang", "t2_zhenwen_zhen",
	# T3（28）
	"t3_budongmingwang", "t3_yujin", "t3_hedinghong", "t3_huanming_qi",
	"t3_jieming_deng", "t3_jubao_pen", "t3_judingsanhua", "t3_junneng_dou",
	"t3_lianhuan_gu", "t3_longxi", "t3_mengdie", "t3_morihuozhong",
	"t3_qingnang_huopen", "t3_qingyuanbaolian", "t3_sanqi_zhong",
	"t3_fali", "t3_shengming", "t3_sheming_quan", "t3_shixinding",
	"t3_tianluodiwang", "t3_tinglong", "t3_xiling_ling", "t3_xumingxiang", "t3_yemingzhu", "t3_yiyuan_deng",
	"t3_zhaohun_fan", "t3_jianyi", "t3_yiqi",
]


## 构造一件道具（带独立 effect 实例 + 独立 params 副本）。未知 id 返回 null。
static func make(id: String) -> ItemData:
	if not _DEF.has(id):
		push_error("ItemCatalog: 未知道具 id %s" % id)
		return null
	var d: Dictionary = _DEF[id]
	var item := ItemData.new()
	item.item_id = id
	item.item_name = d["name"]
	item.tier = int(d.get("tier", 1))
	item.dimension = d["dim"]
	item.role = d.get("role", "")
	item.sequence_tag = d["seq"]
	item.target_mode = d["target"]
	item.description = _display_description(String(d["desc"]))
	item.flavor = _FLAVOR.get(item.item_name, "")
	# 新普通道具基准为约 1 点价值（2 半点）；高阶条目继续使用各自显式 ev。
	item.ev_half = int(d.get("ev", 2 if item.tier == 1 else 1))
	item.upgrade_to = d.get("upgrade", "")
	item.params = (d["params"] as Dictionary).duplicate(true)
	item.effect = d["script"].new()
	return item


## 玩家可见的道具说明统一不使用句号。多句说明以分号保留语义停顿，避免删点后粘成一句。
static func _display_description(raw: String) -> String:
	return raw.trim_suffix("。").replace("。", "；")


## 指定 tier 的全部件（玩家显示顺序）。
static func all_for_tier(t: int) -> Array[ItemData]:
	var out: Array[ItemData] = []
	for id in DISPLAY_ORDER:
		if int((_DEF[id] as Dictionary).get("tier", 1)) == t:
			out.append(make(id))
	return out


static func all_tier1() -> Array[ItemData]:
	return all_for_tier(1)


static func all_tier2() -> Array[ItemData]:
	return all_for_tier(2)


static func all_tier3() -> Array[ItemData]:
	return all_for_tier(3)


## 全部已实装件（tier → 完整无声调拼音）。
static func all() -> Array[ItemData]:
	var out: Array[ItemData] = []
	for id in DISPLAY_ORDER:
		out.append(make(id))
	return out


static func ids() -> Array:
	return DISPLAY_ORDER.duplicate()


# ========== 美术图标约定（B·2026-06-20）==========
## 图标按约定路径加载、无需逐件配字段：res://assets/sprites/items/<中文道具名>.png。
## 2026-06-27 Eddy：图标文件名 = 游戏内中文道具名（与 _DEF[id].name 同步），便于按名更新美术；
##   暂存区 assets/import/ 同样按中文名命名（tools/import_item_art.gd 直接同名拷入）；UI 缺图回退占位文字。
const ICON_DIR := "res://assets/sprites/items/"


## 某 id 的图标约定路径（文件不一定存在）。文件名 = 该 id 的中文道具名（_DEF[id].name）。
static func icon_path(id: String) -> String:
	var nm: String = _DEF[id]["name"] if _DEF.has(id) else id
	return ICON_DIR + nm + ".png"


## 加载某 id 的图标；未导入 / 不存在则返回 null（调用方据此回退占位文字）。
static func load_icon(id: String) -> Texture2D:
	if id == "":
		return null
	var p := icon_path(id)
	if not ResourceLoader.exists(p):
		return null
	return load(p) as Texture2D


## 稀有度底色（按 tier·2026-06-26 Eddy：道具框背景改按稀有度而非维度划分）。
## 通用约定色：普通=蓝 / 稀有=紫 / 传说=金。图鉴卡 / 战斗道具栏芯片 / 抽卡卡 统一引用。
static func rarity_color(tier: int) -> Color:
	match tier:
		2: return RARITY_RARE
		3: return RARITY_LEGENDARY
		_: return RARITY_NORMAL


## 显示名 → id 映射（从 _DEF 实时构建，永不过时）。重名会 push_error（当前全唯一）。
## 供 tools/import_item_art.gd 把「臭鸡蛋.png」分配为「t1_xiangjiaopi.png」。
static func name_to_id() -> Dictionary:
	var m := {}
	for id in _DEF:
		var nm: String = (_DEF[id] as Dictionary)["name"]
		if m.has(nm):
			push_error("ItemCatalog: 显示名重复『%s』(id %s / %s)，名→id 映射有歧义" % [nm, m[nm], id])
		m[nm] = id
	return m
