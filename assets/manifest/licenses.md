# 素材授权与来源记录（Asset Licenses）

> 依据 AGENTS.md §12.2 与 PLAN.md §8.4：每个进入仓库的素材都必须登记来源与授权状态。
> 状态含義：`verified` = 已确认可商用；`pending` = 待核查，**不得用于对外发布构建**；
> `internal-prototype` = 仅限内部原型验证使用。

## 1. AI 生成素材（当前全部素材）

| 素材组 | 路径 | 来源 | 授权状态 | 商用 | 署名要求 | 修改说明 |
|---|---|---|---|---|---|---|
| 地面地块原型 v0（8 张 + 图集 + 预览） | `assets/source/generated/ground_tiles_v0/` | AI 图像生成服务（经项目所有者生成） | pending：需核查生成服务条款 | 未确认 | 无 | 未修改 |
| 地面地块生产副本 | `assets/tilesets/forest/ground/*.png` | 同上（源自 ground_tiles_v0） | 同上 | 未确认 | 无 | Alpha 平化 + 42 像素边缘修补（见 docs/ART_ASSET_IMPLEMENTATION.md §4） |
| 概念图集（13 张） | `assets/source/generated/concept_atlases/` | AI 图像生成服务 | pending | 未确认 | 无 | 未修改，仅作参考 |
| 地形过渡参考 | `assets/source/generated/forest_transitions_ref/` | AI 图像生成服务 | pending | 未确认 | 无 | 未修改，仅作参考 |
| 水域参考 ×2 | `assets/source/generated/forest_water_ref/` | AI 图像生成服务 | pending | 未确认 | 无 | 未修改，仅作参考 |
| 瀑布动画参考包 | `assets/source/generated/waterfall_anim_ref/` | AI 图像生成服务 | pending | 未确认 | 无 | 未修改，仅作参考 |

## 2. 外部素材（Kenney / itch.io / OpenGameArt / Freesound 等）

暂无。未来引入时按 AGENTS.md §12.2 逐条登记：名称、来源 URL、作者、授权类型、
商用许可、署名要求、修改说明。

## 3. 待办

- [ ] 项目所有者确认所用图像生成服务的名称与条款（训练/商用/署名），更新上表状态。
- [ ] 正式发布前，将所有 `pending` 素材替换为已验证来源或确认可商用的版本。
- [ ] 引入第一个外部素材包时建立对应登记行。
