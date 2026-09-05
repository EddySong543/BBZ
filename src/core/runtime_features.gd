extends RefCounted

## 当前产品功能门。当前只保留单机 PvE 道具原型入口。
## 2026-09-02：冻结20件道具的本地 PvE 原型入口。旧目录仍可按 ID 读取，但不再由生产入口产出。
const ITEM_V2_ENABLED: bool = true
const ITEM_V2_DEFAULT_BACKPACK_UIDS: int = 20
