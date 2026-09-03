# Scene9：银辉草原

Scene9 定位为银色的一望无际草原与横贯天际的云海。浮空岛和瀑布方案已正式放弃，运行场景及契约不再保留相关节点或资源。`src/ui/scenes/scene9.tscn` 负责环境，`src/ui/battle_screen9.tscn` 复用成熟 Battle Screen 的 UI、人物、输入、战斗反馈和鼠标视差。

## 当前框架

- `SceneSky`：正式 `576×324` 天空源图，使用 `4×` nearest 整数缩放后居中覆盖视口，不做滤镜或非整数拉伸。
- `DistantPixelCloudBank`、`DistantPixelCloudBank2`：使用代码蓝图保存原 `scene9_cloud_layer` 的完整像素结构；两层共享一次构建的基础纹理与像素元数据，实时展开、底缘锁定和三圈点击涟漪均由各自的 Scene9 本地 GPU 材质驱动，不再逐帧重建并上传整张图片。左键只有命中当前真实云像素才会作用于最前方可见云层。
- `DistantLeftMountain`、`DistantRightMountain`：独立远山节点，分别保留完整源图与 nearest 整数缩放，提供可手调的远景构图。
- `DistantLeftMountain/EyeSocketBirdFlock`：有效草地或云层点击以 `12%` 概率触发 8 只微型远景鸟从左山眼窝分三批飞出。单鸟使用 5×3 源像素、三帧硬边条带，随左山缩放后的最大画面足迹为 20×12 像素；鸟群始终完整绘制在左山前方，不再使用山体 alpha 遮罩或裁切，沿右上方弧线飞行，并在保持移动的最后 1 秒平滑淡出。全程不使用粒子、发光或模糊。
- `DistantRoad`、`DistantLeft`、`DistantRight`：继续与 Platform 共用固定地面运动平面，不响应鼠标横移。道路保留原节点 Rect 与 `44%` 裁切，仅按验收红圈移除源图 `(26,77)-(101,90)` 的左侧多余支路；左右草原沿用 Scene5 的细分网格顶点风场（左 `48×12`、右 `56×12`），根部固定，上部有效水平摆幅约 `13.4 px`、阵风抬升约 `3 px`，并增强横向银色明暗波。
- `BattlePlatformAssembly`：将五块手调 Platform 按当前构图离线合成为单一透明地面，使用 `4×4` 源像素网格并固定在人物地面运动平面。保留完整合成平台原图，不再叠加任何由道路或草地生成的延伸部分。
- `BattlePlatformNew`：新接入的完整 `408×136` 平台源图，初始以 `5×` nearest 整数缩放覆盖战斗区域并固定在地面运动平面；旧 `BattlePlatformAssembly` 节点及其当前可见性保持不变。
- `ForegroundMid`：正式草地源图，使用 `4×4` 源像素网格并与 `ForegroundLeft/Right` 共用近景运动平面；绘制在合成 Platform 上方，以素材自身草缘完成遮挡。
- `ForegroundLeft`：完整左近景，使用 `3×` 整体等比缩放，视差系数 `1.18`。
- `ForegroundRight`：完整右近景，使用 `3×` 整体等比缩放，视差系数 `1.18`。
- `SilverMotesFar`：8 个远层银光点；每个是代码生成的 `7×7` 三色不规则圆形像素簇，有效屏幕尺寸约 `8–12 px`，缓慢横漂。
- `SilverMotesNear`：4 个近层银光点；沿用相同像素语言，有效屏幕尺寸约 `15–20 px`，位移略大但不形成粒子幕。旧细长草屑与阵风草屑已从运行树替换。
- `CompositionGuides/P1Baseline`：P1 脚底基线 `(480, 748)`。
- `CompositionGuides/P2Baseline`：P2 脚底基线 `(1440, 748)`。
- `CompositionGuides/PlatformBaseline`：战斗平台中心基线 `(960, 748)`。
- Scene9 入口显式关闭基础场景的月夜尘粒、旧接触阴影、角色月光和全屏调色；正式环境光照留给 Scene9 素材接入阶段。

被否决的程序化地表、草簇分布、浮空岛、瀑布、天空鲸和眼窝发光均不接回运行场景。代码云、眼窝飞鸟与银色光点直接接入 Scene9 现有纵深和风场；运行资源不引用 `assets/import/`，不移动成熟人物。

## 后续素材接入顺序

1. Eddy 将 Scene9 素材放入 `assets/import/`，并明确每个文件的层职责。
2. 只移动被点名的文件及其 `.import`；正式资源归入本目录，保留母版进入 `source/` 并由 `.gdignore` 隔离。
3. 推荐按天空、云层、远景、正式银色草地、完整战斗平台、近景遮挡层的顺序逐层接入。
4. 先处理尺寸、位置、遮挡和整数像素密度，再建立 Scene9 专属调色、角色银色天光和环境动效。
5. 平台与环境围绕三条成熟构图基线适配；人物、UI、输入、换人、倒计时和战斗动画保持不变。
