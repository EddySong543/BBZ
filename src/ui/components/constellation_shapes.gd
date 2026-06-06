class_name ConstellationShapes

## 真实天文星座的简化连线模板(stick figure)，供 ConstellationOverlay 随机点亮。
##
## 选型 = 游戏已实现的 12 黄道星座(h35 白羊 → h46 双鱼) + 圣斗士青铜五小强的星座
## (天马 Pegasus / 仙女 Andromeda / 天龙 Draco / 白鸟·天鹅 Cygnus / 凤凰 Phoenix)，共 17 座。
##
## 坐标系：局部 bbox，大致 0..1，x→右 / y→下(屏幕坐标)。overlay 会做一次 bbox 归一化
## (fit 到单位正方形、保持纵横比)再缩放/平移到天区，所以这里的坐标只需形状对、绝对值随意。
## edges：连线，每条 = Vector2i(星索引A, 星索引B)，**按"连续生长"顺序排列**——
## 尽量让每条边从"已出现的星"伸向"新星"，overlay 据此逐条延伸、新星在线到达时淡入。

## 返回全部 17 个星座模板。每次 _ready 调一次(非热路径)，不缓存。
static func all() -> Array:
	return [
		# ---- 12 黄道星座 ----
		{
			"name": "白羊",
			"stars": [Vector2(0.15, 0.55), Vector2(0.42, 0.46), Vector2(0.68, 0.52), Vector2(0.88, 0.38)],
			"edges": [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3)],
		},
		{
			"name": "金牛",  # V 形牛脸 + 双角
			"stars": [Vector2(0.5, 0.6), Vector2(0.33, 0.42), Vector2(0.62, 0.4), Vector2(0.12, 0.12), Vector2(0.88, 0.18)],
			"edges": [Vector2i(0, 1), Vector2i(1, 3), Vector2i(0, 2), Vector2i(2, 4)],
		},
		{
			"name": "双子",  # 并立双人
			"stars": [Vector2(0.3, 0.1), Vector2(0.62, 0.13), Vector2(0.34, 0.45), Vector2(0.6, 0.47), Vector2(0.24, 0.82), Vector2(0.72, 0.84)],
			"edges": [Vector2i(0, 1), Vector2i(0, 2), Vector2i(2, 4), Vector2i(1, 3), Vector2i(3, 5), Vector2i(2, 3)],
		},
		{
			"name": "巨蟹",  # 倒 Y
			"stars": [Vector2(0.5, 0.15), Vector2(0.52, 0.5), Vector2(0.25, 0.72), Vector2(0.78, 0.7)],
			"edges": [Vector2i(0, 1), Vector2i(1, 2), Vector2i(1, 3)],
		},
		{
			"name": "狮子",  # 镰刀(反问号) + 后躯三角，一笔环
			"stars": [Vector2(0.22, 0.72), Vector2(0.18, 0.52), Vector2(0.27, 0.34), Vector2(0.41, 0.26), Vector2(0.5, 0.4), Vector2(0.82, 0.5), Vector2(0.6, 0.74)],
			"edges": [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 4), Vector2i(4, 5), Vector2i(5, 6), Vector2i(6, 0)],
		},
		{
			"name": "处女",
			"stars": [Vector2(0.28, 0.82), Vector2(0.44, 0.6), Vector2(0.55, 0.44), Vector2(0.39, 0.4), Vector2(0.68, 0.5), Vector2(0.72, 0.3), Vector2(0.86, 0.24)],
			"edges": [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(2, 4), Vector2i(4, 5), Vector2i(5, 6)],
		},
		{
			"name": "天秤",  # 天平
			"stars": [Vector2(0.5, 0.22), Vector2(0.25, 0.55), Vector2(0.75, 0.5), Vector2(0.2, 0.85), Vector2(0.8, 0.8)],
			"edges": [Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 3), Vector2i(2, 4)],
		},
		{
			"name": "天蝎",  # 头三星 + S 身 + 钩尾(Antares=3)
			"stars": [Vector2(0.16, 0.16), Vector2(0.27, 0.26), Vector2(0.37, 0.18), Vector2(0.3, 0.44), Vector2(0.35, 0.62), Vector2(0.47, 0.75), Vector2(0.61, 0.81), Vector2(0.73, 0.74), Vector2(0.81, 0.6), Vector2(0.74, 0.47)],
			"edges": [Vector2i(1, 0), Vector2i(1, 2), Vector2i(1, 3), Vector2i(3, 4), Vector2i(4, 5), Vector2i(5, 6), Vector2i(6, 7), Vector2i(7, 8), Vector2i(8, 9)],
		},
		{
			"name": "射手",  # 茶壶(Teapot)：壶身闭环 + 壶嘴
			"stars": [Vector2(0.16, 0.56), Vector2(0.32, 0.46), Vector2(0.46, 0.3), Vector2(0.6, 0.44), Vector2(0.8, 0.5), Vector2(0.62, 0.7), Vector2(0.36, 0.72), Vector2(0.26, 0.58)],
			"edges": [Vector2i(1, 0), Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 4), Vector2i(4, 5), Vector2i(5, 6), Vector2i(6, 7), Vector2i(7, 1)],
		},
		{
			"name": "摩羯",  # 大三角(六边闭环)
			"stars": [Vector2(0.16, 0.28), Vector2(0.42, 0.2), Vector2(0.84, 0.42), Vector2(0.7, 0.74), Vector2(0.44, 0.84), Vector2(0.24, 0.6)],
			"edges": [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 4), Vector2i(4, 5), Vector2i(5, 0)],
		},
		{
			"name": "水瓶",
			"stars": [Vector2(0.2, 0.3), Vector2(0.35, 0.42), Vector2(0.5, 0.3), Vector2(0.63, 0.43), Vector2(0.76, 0.34), Vector2(0.8, 0.6), Vector2(0.7, 0.82)],
			"edges": [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 4), Vector2i(4, 5), Vector2i(5, 6)],
		},
		{
			"name": "双鱼",  # 大 V(顶点 Alrescha=0)，两臂各连一鱼
			"stars": [Vector2(0.5, 0.85), Vector2(0.4, 0.64), Vector2(0.3, 0.44), Vector2(0.22, 0.26), Vector2(0.6, 0.7), Vector2(0.72, 0.55), Vector2(0.83, 0.4), Vector2(0.9, 0.24)],
			"edges": [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(0, 4), Vector2i(4, 5), Vector2i(5, 6), Vector2i(6, 7)],
		},
		# ---- 圣斗士青铜五小强 ----
		{
			"name": "天马",  # 飞马大四边形 + 颈/腿延伸
			"stars": [Vector2(0.4, 0.3), Vector2(0.72, 0.32), Vector2(0.74, 0.65), Vector2(0.42, 0.62), Vector2(0.2, 0.7), Vector2(0.1, 0.86)],
			"edges": [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 0), Vector2i(3, 4), Vector2i(4, 5)],
		},
		{
			"name": "仙女",  # 自飞马一角延伸的双链
			"stars": [Vector2(0.16, 0.28), Vector2(0.4, 0.42), Vector2(0.62, 0.52), Vector2(0.84, 0.6), Vector2(0.52, 0.66), Vector2(0.74, 0.76)],
			"edges": [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(1, 4), Vector2i(4, 5)],
		},
		{
			"name": "天龙",  # 龙头菱形 + 蜿蜒长尾
			"stars": [Vector2(0.7, 0.14), Vector2(0.83, 0.22), Vector2(0.74, 0.33), Vector2(0.61, 0.25), Vector2(0.58, 0.42), Vector2(0.45, 0.47), Vector2(0.4, 0.62), Vector2(0.25, 0.64), Vector2(0.2, 0.8), Vector2(0.36, 0.86)],
			"edges": [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 0), Vector2i(2, 4), Vector2i(4, 5), Vector2i(5, 6), Vector2i(6, 7), Vector2i(7, 8), Vector2i(8, 9)],
		},
		{
			"name": "白鸟",  # 天鹅·北十字(中心=1)
			"stars": [Vector2(0.5, 0.12), Vector2(0.5, 0.46), Vector2(0.5, 0.84), Vector2(0.18, 0.4), Vector2(0.82, 0.52)],
			"edges": [Vector2i(0, 1), Vector2i(1, 2), Vector2i(1, 3), Vector2i(1, 4)],
		},
		{
			"name": "凤凰",  # 张翅鸟形(胸 Ankaa=1 分出头/双翼/尾)
			"stars": [Vector2(0.5, 0.18), Vector2(0.46, 0.46), Vector2(0.18, 0.4), Vector2(0.78, 0.34), Vector2(0.5, 0.78)],
			"edges": [Vector2i(0, 1), Vector2i(1, 2), Vector2i(1, 3), Vector2i(1, 4)],
		},
	]
