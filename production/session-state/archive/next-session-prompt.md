# 下个 Session 开场提示词 —— 波波攒「黑暗面英雄」设计

> 把下面整段当作本 session 的工作底座。**先读完再动手，别凭记忆设计。**

## 0. 开场必读（按顺序，别跳过）
1. 本提示词全文。
2. `production/session-state/active.md` 顶部最新 `SESSION CLOSE 2026-06-22` —— 当前进度与翻车点。
3. `MEMORY.md` 索引，并重点读：`hero-must-be-combo-engine` / `dark-zodiac-heroes` / `option-labels-abc` / `eddy-hero-design-workflow-prefs` / `hero-design-philosophy` / `synergy-master-theorem` / `defense-armor-absorption-model`（二元铁则）/ `numeric-framework-v1` / `item-vs-hero-design-space` / `clarify-before-acting` / `eddy-stay-objective-no-pandering`。
4. **设计文档（吃透，别凭记忆）**：
   - `design/build-design-framework.md` —— 纲领，尤其 §4 标准值 / §4.6 防御铁则 / §5 连携 / **§6 主定理(系内加算·系间乘算)** / §7 元件类型 / §8 反固化 / §14 道具判据 / §15 系统操作层。
   - `design/heroes-redesign.md` —— **v2 光英雄 h01-h12 = 设计标杆**，以及**顶部两条硬透镜**（共享原语格栅 + 博弈点）。
   - `design/heroes-schools.md` —— §5 机制原语字典（找 🈳 空槽优先填）。

## 1. 当前任务
- **重设计 h13 黑暗子鼠**：现行【封窟】（出战让敌方 0.5 能不可用）被 Eddy 判为"低 agency 的被动白值"，要按规则重做。**前两版已被否**（对攻+伤 / 连击递增 = 自闭加伤、见过、不好玩，别再走）。
- 之后继续：h16 黑暗卯兔（已暂停）等黑暗面英雄。
- h15 黑暗寅虎已落地、**未 push**（等 Eddy 决定何时提交）。

## 2. 设计铁律（违反 = 直接重做）

### 2.1 列选项格式 —— 高复发坑
- **给 Eddy 列方案，选项前缀只用 A. B. C.**。**绝不用甲/乙/丙，也不用 1/2/3。** 列之前先自检前缀。

### 2.2 英雄三铁律：干净 · 可拓展 · combo 多
- **干净** = 单维度（进攻/防御/能量/节奏/状态/干扰 取 1 主标签）、一句话机制、≤2 原语、≤3 行；minor/细枝归道具。
- **可拓展** = **必须产出或消费一个"可复用共享原语"**（格栅钩子），让未来英雄/道具插得上去。**禁自闭机制。**
- **combo 多** = 自身低保（§4.4 低标）、高连通度、**乘算放大一整类**别的东西（泛连携引擎 / 系间乘算）。
- **标杆**：光虎（把所有 on-hit 翻倍）/ 蛇（毒=全队任意攻击皆引爆器）/ 龙（破甲=给全队开穿透窗）/ 马（免费切换=串起所有登场 combo）。共性 = **自身平庸、强度全在搭配**。
- **⛔ 反例（当场被否）**：「满足条件→自己 +伤」「对攻 +X」「连击递增」——自 buff、不产共享原语、见过、不好玩。
- **出方案前必过三问**：①它产出/消费什么共享原语？②未来谁能插上来？③它乘算放大哪一整类东西？答不上 = 重做。

### 2.3 二元防御铁则（`defense-armor-absorption-model`）
- **力量 = 能不能(WHETHER)，不是多少(HOW MUCH)。** 禁临时护甲 / 护甲点数吸收模型。
- 分级整体挡：防=挡「波」；大防=挡「波+大波/穿防」=天花板。挡=归零、不挡=全额。
- 穿透三档：穿防（大防能挡）/ 穿大防（**只授公开慢蓄 payoff**，如鸡满 4 层；禁便宜瞬发）/ 真伤（无视一切·**英雄仅戌狗**；道具走 §4.6 真伤 4-gate）。
- 多段攻击的 proc 被"必须命中"gate（禁分段绕防）。护甲=额外血量层（只吸落地伤、真伤无视）。

### 2.4 数值框架（`numeric-framework-v1` + 纲领 §4，已实装·半能制）
- HP 3-7（脆 3-4 / 标准 5-6 / 坦克 7）。能量允许 0.5。
- 波=1 能/1.0 HP；大波=3 能/2.0 HP 穿防；防=0 能挡波；大防=2 能挡全部；攒=+1（另有被动 +1 能/回合）；切换=0 能占动作。
- 汇率：占动作 1 能=1.0 HP；道具(不占动作) 1 能=0.5 HP。超标必带负面/条件（§4.4）。

### 2.5 状态(状态维度)要克制
- 持续 DoT / 常驻 debuff 会：换对战味道 + 杂乱 + **招"只针对状态"的寄生道具**（其系内×系数>系间 = 违 §6 主定理的催化剂排异）。
- roster 已有 蛇(毒)/鸡(剑意)/龙(破甲) 占状态位，**别再过加状态英雄**。瞬时 setup（破甲/易伤·当场消耗）与 combo 黏合剂（蛇毒）健康；持续 grind 是危险那种。

### 2.6 黑暗英雄方法论（2026-06-22 转向）
- **不必暗镜原版**（不必和光版英雄机制对应）。**一切以设计规则为主**，暗镜只是可选风味。生肖主题(鼠/牛/虎…)仍是风味（维度⊥主题）。
- 暗批维度现状：干扰(暗鼠·重设计中) / 进攻(暗牛/暗虎)，**空缺 = 防御/能量/节奏/状态**——优先补空缺 + 填 §5 空原语槽 + 高 agency。
- 同时回合制：**禁假动作/试探/看对手再反应**（§1.4）；合法 yomi = 双方盲选共享公开信息。

## 3. 沟通 / 协作
- **说人话、举例子，别堆术语**（`ask-eddy-in-plain-language`）。
- Eddy 偏好：单字母快速决策；方案用**紧凑块含 HP**；重 combo 联想 + 主动技 cap（`eddy-hero-design-workflow-prefs`）。
- **不确定先问、对齐再做**（大工作必须·`clarify-before-acting`）。
- **客观不迎合**——诚实标弱点/重叠/风险，他的批评通常对（`eddy-stay-objective-no-pandering`）。
- 别把"试玩调平衡"列为下一步（他一直在做·`dont-pitch-playtest-as-next-step`）。
- 视觉/像素验证走 Eddy 自己 F6（Claude 盲做像素=雷区·`claude-blind-on-pixel-visuals`）；别堆截图给他（`dont-dump-screenshots`）。
- **无 Eddy 指示不 git commit / push。**

## 4. 落地清单（设计定稿 + Eddy 批准后才实现，照 h15 套路）
1. 技能：`src/battle/skills/hXX_<拼音>.gd`（继承 `HeroSkill`、override 所需 hook、**写详尽设计头注当设计记录**）。
2. 注册：`src/battle/battle_core.gd` 的 `_HERO_SKILL_SCRIPTS` 加 `"hXX": preload(...)`。
3. 数据：`assets/data/heroes/hXX.tres`（hero_id/name/max_hp/skill_description/skill_detail/portrait+sprite_frames 路径）。
4. 英雄池：`src/battle/hero_data.gd` 的 `create_launch_pool` slice 数 +1。
5. **BP 网格**：`src/ui/bp_screen.gd` 的 `ROWS` 是**硬编码**——加英雄必须同步（如 6+6+3→6+6+4），否则新卡不显示；图鉴 gallery 是 `i%COLS` 动态、不用改。
6. 测试：`tests/unit/battle/v4/test_heroes_dark_v4.gd` 加锁定行为的用例。
7. 美术：源图放 `assets/sprites/NewAssets/`→拷进 `assets/sprites/heroes/hXX/`→`godot --headless --import`→跑 `tools/import_hero_art.gd`（**临时把 FIRST/LAST 改成 XX 只跑这一个、跑完还原**，避免重写别的英雄 .tres 误伤 Eddy 手改）→生成 `hXX_idle.tres`、手绘头像受 `REGEN_PORTRAIT=false` 保护。导入后删 NewAssets 源图（需 Eddy 点头）。
8. 验证：GUT 全量 = `"/d/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe" --headless -s res://addons/gut/gut_cmdln.gd -gconfig=res://tests/.gutconfig.json -gexit`（当前基线 204 绿）。引擎脚本 `--check-only` 干净；UI 脚本 check 会因 autoload(FontManager) 误报、可忽略。

## 5. 出方案前自检（逐条打勾）
- [ ] 选项用 A/B/C 了吗？
- [ ] 单维度、≤2 原语、≤3 行？minor 归道具了？
- [ ] 产出/消费了什么**共享原语**？未来谁插得上？乘算放大哪一类？（三问答得上）
- [ ] 不是自闭加伤 / 不是见过的老 kit？
- [ ] 过二元铁则（WHETHER 非 HOW MUCH·穿透档·无临时护甲）？
- [ ] 数值在框架内（HP 3-7·半能·超标带负面）？
- [ ] 有玩家 agency + 对手 yomi（不是被动白值）？
- [ ] 状态用得克制（没硬塞持续 DoT）？
- [ ] 说人话、举了例子？
