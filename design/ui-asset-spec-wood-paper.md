# 「木骨纸芯」首批 UI 资产规格书

> **状态**：v1.0（2026-07-09·依据 ui-design-system §1 材质定案「木骨纸芯」·Eddy 批准立项）
> **用途**：MJ 出图 + pixellab 后处理的生产规格。每件资产走 **概念稿 F6 → 切片 → 挂点** 三步，⛔禁止跳过概念稿直接实装（回合牌程序化底板被否的教训）。
> **真相源关系**：材质规则/配色令牌以 `design/ui-design-system.md` 为准；本文件只管"生产什么、多大、怎么验收"。

---

## 0. 总则（每件资产都适用）

### 0.1 风格基调
- **木骨纸芯**：深漆木承重（框/脊/座）+ 暖黄白宣纸内容面 + 鎏金/朱印点睛（克制）。
- **手绘绘本 × 复古像素融合**（既定美术方针）：资产走**手绘厚涂质感**，落位后与 Ark Pixel 像素字共处——字永远是引擎渲染的像素字，**资产上禁止画任何文字**。
- 🔴 **反花哨铁律**：无宝石、无铆钉阵列、无复杂浮雕堆砌；装饰密度低、留白足。
- **光照约定**：统一顶光、中性偏暖；投影**不画进资产**（引擎加柔投影，画死会双重影）。

### 0.2 配色（钉 hex·出图后 pixellab 校色对齐）
| 令牌 | 值 | 用途 |
|------|-----|------|
| 宣纸面 | `#E0D1AD`（中心可亮至 `#EADFC2`） | 内容面主色 |
| 纸边阴影 | `#C4B28A` | 毛边/叠页暗缘 |
| 墨 | `#332314` | （引擎字色·资产上仅允许极少量墨线装饰） |
| 深漆木主体 | `#2E1D12` | 框/脊/座主色 |
| 漆木高光 | `#5C3F26` | 木框受光棱线 |
| 暖骨 | `#B3A386` | 与现有像素框衔接的过渡描边 |
| 鎏金 | `#D4A94E` | 点睛线/角饰（用量 ≤5% 面积） |
| 朱印 | `#A03323` | 印章形点睛（每件至多一处·可省略） |

### 0.3 "厚"的配方（Eddy 硬要求：纸不能薄）
毛边/撕边（边缘不规则 2-4px）＋ 微叠页（下缘/右缘露出第二层纸 3-6px）＋ 细纸纹（低对比纤维纹·不是噪点）＋ 木质衬托（纸永远压在木件或深色上，不裸浮）。

### 0.4 交付与验收
- **格式**：PNG 透明底；尺寸=下表目标 px（MJ 高清出图 → pixellab 缩到目标尺寸并清边）。
- **九宫格件**：四角完整、四边可平铺（角尺寸随件标注）；中心区域近纯色（引擎上字）。
- **验收流程**：①我把资产贴进战斗截图做静态 mockup → ②Eddy F6 → ③过了才切片挂点。
- **验收标准**：落位后与暖骨像素框同框不吵架；1920×1080 全屏截图缩到 50% 后构件仍可辨；中心区上 16px 像素字清晰可读。

### 0.5 MJ prompt 公共前缀（草稿·可按件微调）
```
hand-painted storybook game UI asset, oriental fantasy, warm cream xuan
paper with deckled torn edges and subtle layered sheets, dark lacquered
wood frame, tiny gold leaf accent, muted elegant palette (cream #E0D1AD,
dark wood #2E1D12, gold #D4A94E), flat front view, clean silhouette,
plain background, no text, no gems, minimal ornament --raw --v 8.1 --hd
```
（MJ 无法直接出透明底：出图选 plain background 后抠底；raw 模式防过度装饰——V8 写法 `--raw`、V7 旧写 `--style raw`，实操以生效者为准。**版本纪律与参数速查见 `design/midjourney-reference.md`**：当前默认=V8.1（2026-06-10 起），`--hd` 直出 ≈2K 免 upscale，概念稿海选可先 `--draft` 24 连抽省额度。）

---

## 1. 资产清单（首批 7 件·按优先级排序）

### A1 通用厚宣纸板（弹窗/面板底·九宫格）
- **挂点**：设置面板（现 580×700 程序色块）、远征弹窗、后续一切"文书层"弹窗。
- **尺寸**：出图 1160×1400 → 交付 580×700；九宫格角 64px。
- **构图**：深漆木窄框（≈14px）包一整张厚宣纸；纸四边毛边、右下露叠页；顶部正中可留一个小木质"轴头/书签"造型（可选）；中心大面积留白。
- **变体**：无。稀有度/语义色靠引擎着色，不出多色版。

### A2 纸签（小标签·九宫格）
- **挂点**：回合数（顶部中央 `TimerLabel`·现裸文字）、道具槽状态签、各类短标签。
- **尺寸**：出图 320×112 → 交付 160×56；九宫格角 20px。
- **构图**：一小条横向宣纸签，左右毛边，像从册页撕下的一截；**无木框**（小件要轻）；可选左端一枚极小朱印角。
- **⚠回合数挂点纪律**：面积必须小（比上次被否的暖骨牌底更收敛）、先概念稿 F6。

### A3 横幅（中央事件条·九宫格）
- **挂点**：`BigTurnLabel`「回合开始」横幅（460-1460 x 418-502 区）、结算提示、加时赛宣告。
- **尺寸**：出图 1280×192 → 交付 640×96；九宫格角 32px。
- **构图**：横卷展开形：两端深漆木轴头（各≈40px）+ 中段宣纸卷面；卷面微弧/微皱示"展开中"；两端可各一缕极短垂穗（金·克制）。
- **动效预留**：轴头独立切片（引擎做展开动画=中段九宫格横向生长）。

### A4 skillcard 卡面（左下技能卡·整图）
- **挂点**：`SkillCard`（30,896 → 400,1024 = 370×128；给呼吸余量出 380×136）。
- **尺寸**：出图 1520×544 → 交付 380×136。
- **构图**：横向"木匣托纸"：左端木质匣框内嵌头像窗（≈96×96 圆角方窗·引擎放头像）、右侧大片宣纸区（引擎上技能文字）；纸右缘毛边+叠页；匣底木沿贯穿全宽（厚度感来源）。
- **替换关系**：现暖金羊皮纸样式退役；结构（头像+名+描述）不变=零改版式代码，只换底图。
- **⛔ MJ prompt v1 作废（2026-07-12 实测·教训）**：整卡单图生成＋实物木工词（cabinet/sill/thickness）→ 出来是"3D 实物"不是 2D UI，且木/纸接缝格格不入。
- **v2 拆件实测结论（2026-07-12）**：**件1 纯纸 ✅ 成立**（flat scan 措辞管用·纸配方保留=A1/A2/A7 原料）；**⛔ 件2 纯木板条失败**——MJ 无法理解孤立木条（不构成"成立的画面"）。件3 未跑。
- **MJ v3 = 件1纸＋件2木沿合并生成（2026-07-12·Eddy 定向·⛔不含头像窗框）**：木依托纸的语境出图（孤木条 MJ 不理解），保留件1 的 flat 2D 措辞纪律；**⛔ 件3 头像窗框元素不进 MJ**——后期由合成图木区切条拼，或引擎画。**合成图当"原料采集田"**——纸区/木区各自切出重拼，坐标与接缝不依赖 MJ。prompt 见下【v3.1 合并版】；件1 纯纸 prompt 保留备用：

  **件1·宣纸底（✅已验证·全系列纸配方=A1/A2/A7 原料）**
  ```
  flat 2D game UI texture, hand-painted storybook style: a single sheet of
  thick warm cream xuan rice paper seen perfectly straight-on, flat scan look,
  deckled torn edges all around, a second paper layer peeking out under the
  right edge, subtle low-contrast fiber texture, cream #E0D1AD shading to
  #C4B28A along the edges, soft even lighting, completely flat, no perspective,
  no depth, centered on a plain flat mid-gray background
  --no 3d render, photograph, photorealistic, perspective, bevel, drop shadow, table, desk, wood, objects, hands, text, writing
  --ar 14:5 --raw --v 8.1
  ```

  **【v3.1 合并版】纸＋木沿·同图（现役·原料采集田·无头像窗）**
  > v3→v3.1 调整（2026-07-12·未实测）：①去掉 `card design`（"卡"易被 MJ 画成带厚度的实体卡牌）改 `panel`；②去掉 `wood plank`（板材=实物木工词·v1 病根）改"painted trim（画出来的木沿）"；③木沿占比锚定"约底部 1/6"（既是构图指令也给切片留够木料）；④`--no` 扩充 trading card / product shot / mockup。
  ```
  flat 2D game UI texture for an oriental fantasy game, hand-painted
  storybook style, seen perfectly straight-on with a flat scan look: a wide
  horizontal panel, a large sheet of thick warm cream xuan rice paper laid
  over a dark lacquered wood backing; the wood is visible only as a slim
  painted trim running along the entire bottom edge, about one sixth of the
  panel's height, peeking out slightly at both left and right ends; faint
  painted wood grain, deep brown-black lacquer #2E1D12 with a single warm
  highlight ridge line #5C3F26 along the trim's upper edge; the paper's
  right edge is deckled and torn with a second paper layer peeking beneath,
  subtle low-contrast paper fiber texture, cream #E0D1AD shading to #C4B28A
  along the edges; soft even lighting, completely flat, no perspective, no
  depth, centered on a plain flat mid-gray background
  --no 3d render, photograph, photorealistic, perspective, bevel, drop shadow, table, desk, product shot, trading card, mockup, box, gems, metal, nails, text, writing
  --ar 14:5 --raw --v 8.1
  ```
  **出图流程（省额度）**：①同 prompt 先加 `--draft` 24 连抽海选构图 → ②选中 Vary 出全清 → ③定稿那张换 `--hd` 重出 ≈2K（切片余量）。
  可选增稳：把已中意的件1 纸图挂 `--sref`，锁住纸面画风再合并生成；仍跑偏 3D → 平铺纸纹扫描图挂 `--sref` 锚死平面感。

  **压 3D 的措辞纪律（全系列适用）**：正文必带 `flat 2D game UI texture / flat scan look / completely flat, no perspective`；`--no 3d render, photograph, perspective, bevel, drop shadow` 常驻；⛔ 禁用实物木工词（cabinet/box/sill/thickness——"厚"改用毛边+叠页表达）。仍跑偏 → 挂一张平铺纸纹扫描图做 `--sref`。

### A5 木框条（底部按钮收纳托·九宫格）
- **挂点**：底部六颗动作按钮身后的横托（按钮区 y870-1045·托约 560-1360 x 870-1050·先做 840×190）。
- **尺寸**：出图 1680×380 → 交付 840×190；九宫格角 48px。
- **构图**：一根深漆木长案/横梁，上沿微高光棱线，案面近纯深色（按钮坐上面）；两端木纹收头；⛔不画格窗（按钮间距引擎控制）。
- **配套调参**（引擎侧·非资产）：六颗 jelly 按钮饱和度/亮度降一档（design-system §1 定案）。

### A6 中央结算横幅·大（可选=A3 加大版）
- **挂点**：结算阶段中央（伤害结算/胜负宣告）。
- **尺寸**：出图 1760×256 → 交付 880×128；九宫格角 40px。
- **先决**：A3 验收通过后再出（同构图放大·省一次试错）。

### A7 纸质 tooltip 底（悬浮说明·九宫格）
- **挂点**：道具悬浮说明、图鉴详情浮层。
- **尺寸**：出图 640×400 → 交付 320×200；九宫格角 28px。
- **构图**：单层宣纸片+毛边+一角微卷翘（tooltip 的"临时感"）；无木框。
- **优先级**：末位·前六件落位后再说。

---

## 2. 生产批次与依赖

| 批 | 内容 | 依赖 |
|----|------|------|
| 第一批 | A1 纸板 + A2 纸签 | 无——A1 定"纸的味道"，A2 验证最小件；两件过 F6 = 配方成立 |
| 第二批 | A3 横幅 + A4 skillcard | 吃第一批的配方结论 |
| 第三批 | A5 木框条（+按钮降饱和联调） | 吃 A4 的木色结论 |
| 第四批 | A6 / A7 | 前三批全过 |

> 判断点：若第一批 F6 两连否 → 停产回到材质讨论，不硬耗 MJ 额度。

---

## 3. 挂点工程预备（资产到位前我先做的）

- A2/A3/A4 挂点节点化：TimerLabel/BigTurnLabel 补 NinePatchRect 底座节点（texture 空置=现状不变·资产到位 Inspector 拖入即生效，同远征怪物 art 字段模式）。
- skillcard 底图引用改 export 变量（换图零改码）。
- 九宫格切片参数在挂点节点上预设好（margin=本规格书角尺寸）。
