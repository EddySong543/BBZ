extends RefCounted

## 当前产品功能门。这里只控制入口与运行时可达性，不删除休眠实现。
## 单机 Demo 完成后若重启好友对战，应先另立验收任务，再显式开启。
const PVP_ENABLED: bool = false

## 2026-09-02：冻结20件道具的本地PvE原型入口。旧目录仍可按ID读取，但不再由生产入口产出。
const ITEM_V2_ENABLED: bool = true
const ITEM_V2_DEFAULT_BACKPACK_UIDS: int = 20
