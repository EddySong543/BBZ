# Boot Screen H01 · Midjourney V8.1 Prompt

## 这版解决什么

- 直接预览比动漫立绘更接近最终 HD-2D 的像素混合质感。
- 减弱 H01 原立绘三分之四站姿对新构图的干扰。
- 强化正面身体、轻仰视、胸口空位和正上正下双掌。

Midjourney V8.1 是 2026-06-10 起的默认版本。官方说明 V8.1 提高了提示词
遵循和细节保持能力；`Raw` 可以减少模型自动添加的风格。V8.1 的 Image Prompt
仍然是视觉引导而非精确复制，所以必须同时使用姿势参考与明确的文字描述。

## 网页端参考图设置

按下面方式放置三张图，不要把三张图都当成普通 Image Prompt：

1. **Image Prompt：H01 动漫形象**
   - `assets/import/hero/h01.png`
   - 用于角色身份、发型、围巾、交叉背带与服装。
2. **Image Prompt：Boot 姿势参考**
   - `design/references/boot_h01_pose_guide.png`
   - 只用于身体正面朝向、弧形手臂、上下掌与胸口空位。
3. **Style Reference：H01 像素形象**
   - `assets/sprites/heroes/h01/h01.png`
   - 只用于像素色块、边缘与游戏内简化程度。

不要上传 `assets/ui/icons/Zan_idle.png`。它会把手势重新带回左右抱球。

## 参数

- Model：V8.1
- Raw：开启
- Aspect Ratio：4:7
- Image Weight：0.75
- Style Weight：60
- Stylize：40
- HD：开启
- 一次生成 4 张

网页端可以直接设置以上选项；Discord 版参数已经写在 Prompt 末尾。

## V8.1 主 Prompt

```text
full-body H01 from the character reference, standing upright with the torso
and shoulders facing straight toward the camera, restrained 10-to-15-degree
low-angle view, mild heroic wide-lens perspective, head lowered slightly,
both feet visible, centered isolated character

exact H01 design: asymmetric messy black hair covering one eye, one subtle
violet eye visible, purple-black high collar scarf, crossed chest straps,
layered dark-purple martial robe, wide sleeves, gloves, wrapped trousers and
boots, simplified waist with no hanging weapons

exact pose: one clean empty circular space at the center of the chest; upper
hand perfectly horizontal directly above the empty space with palm facing
straight down; lower hand perfectly horizontal directly below the empty space
with palm facing straight up; both palms share the same vertical center line;
arms form two natural inward curves; hands do not touch or hold anything

HD-2D oriental fantasy game character key art, painterly volume simplified
into large readable pixel clusters, crisp pixel-stepped silhouette, selective
hard square-pixel accents on hair, scarf, gloves and robe edges, restrained
color count, deep purple-black character against a single flat neutral
mid-gray background, no cel-animation linework, no glossy anime rendering,
no smooth vector edges, no photorealism

face mostly hidden in shadow, one violet eye and a thin warm-gold rim along
the hair, cheek, gloves and robe edges; clean movable silhouettes for fringe,
short scarf tail, sleeve edges and broad robe flaps

single character only, no sphere, no magic, no energy stream, no particles,
no title, no letters, no scenery, no floor, no cast shadow, no weapon
--v 8.1 --raw --ar 4:7 --iw 0.75 --sw 60 --stylize 40 --hd
--no sphere, magic, particles, text, scenery, weapons
```

## 如果仍然是三分之四朝向

不要重新加大 H01 参考图权重。提高参考图权重往往会把旧立绘站姿一起带回来。
在选中的候选图上使用 Midjourney Editor，并采用下面的短 Prompt：

```text
same H01 character and costume, strict straight-on front-facing torso,
symmetrical shoulders, chest center aligned with the camera, restrained low
angle; upper palm horizontal directly above the chest gap, lower palm
horizontal directly below it, both hands on one vertical center line
```

## 如果角色身份漂移

V8.1 的 Image Prompt 不保证精确角色复制。此时可做一轮 V7 Omni Reference
对照：把 H01 动漫图放入 Omni Reference，姿势图仍作 Image Prompt，Omni
Strength 从 200 开始，不超过 400。V7 Omni Reference 能更强地锁角色，但它
不是当前最新版，因此只作为身份纠偏备选，不替代 V8.1 主方案。

## 验收

1. 肩线和胸口正对镜头，不是原立绘的三分之四朝向。
2. 上掌正上、下掌正下，完全垂直对齐。
3. 胸口保留圆形空位，没有球体和魔法。
4. H01 的发型、围巾、交叉背带和紫黑服装仍可辨认。
5. 画面具有大块像素色阶与硬边，但没有退化成 128×128 小像素人。
6. 全身和双脚完整，手指正确。

## 官方依据

- Version：https://docs.midjourney.com/hc/en-us/articles/32199405667853-Version
- Image Prompts：https://docs.midjourney.com/hc/en-us/articles/32040250122381-Image-Prompts
- Style Reference：https://docs.midjourney.com/hc/en-us/articles/32180011136653-Style-Reference
- Raw：https://docs.midjourney.com/hc/en-us/articles/32634113811853-Raw
- Omni Reference：https://docs.midjourney.com/hc/en-us/articles/36285124473997-Omni-Reference

