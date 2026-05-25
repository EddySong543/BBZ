extends HeroSkillV4

## h07 午马【当先】· 单英雄（方案 C 唯一例外）
## 0 能免费切换、【不占动作槽】，每局 cap 2：当先出战时可先免费换人上来，再正常做一个动作。
## 引擎通过 has_free_switch() + free_switch() 支持；不走动作槽主动技接口。cap 由引擎计 dangxian_uses。

func has_free_switch() -> bool:
	return true
