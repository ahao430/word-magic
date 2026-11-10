# 素材授权与来源记录（Asset Licenses）

> 依据 AGENTS.md §12.2 与 PLAN.md §8.4：每个进入仓库的素材都必须登记来源与授权状态。
> 状态含義：`verified` = 已确认可商用；`pending` = 待核查，**不得用于对外发布构建**；
> `internal-prototype` = 仅限内部原型验证使用。

## 1. AI 生成素材（当前全部素材）

| 素材组 | 路径 | 来源 | 授权状态 | 商用 | 署名要求 | 修改说明 |
|---|---|---|---|---|---|---|
| 地面地块原型 v0（8 张 + 图集 + 预览） | `assets/source/generated/ground_tiles_v0/` | AI 图像生成服务（经项目所有者生成） | pending：需核查生成服务条款 | 未确认 | 无 | 未修改 |
| 地面地块生产副本 | `assets/tilesets/forest/ground/*.png` | 同上（源自 ground_tiles_v0） | 同上 | 未确认 | 无 | Alpha 平化 + 42 像素边缘修补（见 docs/ART_ASSET_IMPLEMENTATION.md §4） |
| 过渡 Tile 图集（16 格程序化合成） | `assets/tilesets/forest/ground/forest_ground_atlas.png`（行 2-5） | 程序化合成自生产地块（`tools/dev/transition_tiles.gd`） | 同上 | 未确认 | 无 | 以 grass_dense / dirt_plain 像素为源的程序化派生 |
| 森林物件精灵（树/岩/灌木 ×6） | `assets/sprites/props/*.png` | 程序化合成（`tools/dev/build_prop_sprites.gd`，色板采样自生产地块） | 同上 | 未确认 | 无 | 程序化派生，真 Alpha 裁切 |
| 水面/河岸 Tile（20 格程序化合成） | `assets/tilesets/forest/ground/forest_ground_atlas.png`（行 6-10） | 程序化合成（`tools/dev/water_tiles.gd`；蓝色色板采样自 forest_water_reference.png） | 同上 | 未确认 | 无 | 仅采样参考图颜色，不复制像素 |
| 玩家角色精灵（12 帧 + SpriteFrames） | `assets/sprites/player/*.png`、`player_frames.tres` | 程序化合成（`tools/dev/build_player_sprites.gd`） | 同上 | 未确认 | 无 | 程序化生成，真 Alpha 裁切 |
| 元素法球（投射物基底） | `assets/sprites/effects/orb_16.png` | 程序化合成（`tools/dev/build_orb_sprite.gd`） | 同上 | 未确认 | 无 | 白色径向法球，运行时按元素调制颜色 |
| 史莱姆精灵（2 帧弹跳 + SpriteFrames） | `assets/sprites/enemies/*.png`、`slime_frames.tres` | 程序化合成（`tools/dev/build_slime_sprites.gd`） | 同上 | 未确认 | 无 | 程序化生成，真 Alpha 裁切 |
| 史莱姆王 Boss 精灵（2 帧重弹跳 + 王冠 + SpriteFrames） | `assets/sprites/enemies/boss_slime_idle_*.png`、`boss_frames.tres` | 程序化合成（`tools/dev/build_boss_sprites.gd`，配色为史莱姆深色变体） | 同上 | 未确认 | 无 | 程序化生成，金色王冠 + 红宝石，真 Alpha 裁切 |
| Boss 大型阴影 | `assets/sprites/effects/boss_shadow_28x12.png` | 程序化合成（`tools/dev/build_boss_sprites.gd`） | 同上 | 无需 | 无 | 28×12 径向 Alpha 椭圆（同 shadow_16x8 配方放大） |
| Boss 重砸落点预警圈 | `assets/sprites/effects/slam_warning_164.png` | 程序化合成（`tools/dev/build_boss_sprites.gd`） | 同上 | 无需 | 无 | 164×164 红色危险圈（边界 0.85 + 填充 0.30 半透明），运行时 0.55→1.0 闪烁脉冲 |
| 符文石精灵（休眠/苏醒 两态） | `assets/sprites/puzzles/rune_*.png` | 程序化合成（`tools/dev/build_rune_sprites.gd`） | 同上 | 未确认 | 无 | 程序化生成，刻痕符文双色 |
| 音效 ×13（施法/命中/爆炸/受伤/机关/Boss 落地与死亡/元素受击 冰·雷·风） | `assets/audio/sfx/*.tres` | 程序化合成（`tools/dev/build_sfx.gd`，AudioStreamWAV 正弦/噪声合成） | 程序化生成（无外部来源） | 无需 | 无 | 确定性合成，可复现 |
| 柔和阴影精灵 | `assets/sprites/effects/shadow_16x8.png` | 程序化合成（`tools/dev/build_shadow_sprite.gd`） | 同上 | 无需 | 无 | 径向 Alpha 渐变椭圆 |
| 瀑布纹理（滚动动画用） | `assets/sprites/effects/waterfall_32x64.png` | 程序化合成（`tools/dev/build_waterfall_sprite.gd`，垂直可平铺） | 同上 | 无需 | 无 | 纵向条纹 + 64px 周期无缝衔接 |
| 法术特效贴图 ×2（冲击环/领域盘，白色运行时调色） | `assets/sprites/effects/blast_ring_64.png`、`field_zone_128.png` | 程序化合成（`tools/dev/build_effect_sprites.gd`） | 同上 | 无需 | 无 | 白色基底 + 真 Alpha，ELEMENT_TINT 调制 |
| 探索 BGM（24s 循环） | `assets/audio/music/explore_loop.tres` | 程序化合成（`tools/dev/build_bgm.gd`，和弦铺底+五声琶音） | 同上 | 无需 | 无 | 确定性合成，LOOP_FORWARD |
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
