# 开发路线进度表

> 对应 `plan.md` 的 Phase 0-8 路线图。最后更新：2026-11-11。

## Phase 状态

| Phase | 状态 | 内容摘要 |
|---|---|---|
| 0 项目初始化 | ✅ | Godot 4.7.2 工程、目录结构、输入映射、GameManager、引擎内地块验证 |
| 1 基础游戏原型 | ✅ | 玩家移动/相机/地图/过渡地块/物件层/水系/角色动画 |
| 2 语言施法核心 | ✅（离线部分） | 归一化/本地注册表/验证/平衡/唯一性/图鉴/工厂/执行器 |
| 3 森林战斗样板 | ✅ | 史莱姆 AI/伤害循环/玩家受击与重生/**史莱姆王 Boss 战**（预警圈/血条/技能循环） |
| 4 环境互动与机关 | ✅ | 符文石解谜（规则验证）→ 渡口重建 |
| 5 AI 缓存和语音 | ◐ 主体完成 | Exact/Normalized 缓存 + 版本管理 ✅；**AI 解析 ✅**（OpenAI 兼容 Provider，config/ai.json 填写即用）；语义缓存（Embedding）/语音 ❌ |
| 6 世界记忆和存档 | ◐ 雏形 | 三层模型（世界记忆/会话/缓存）✅；SQLite 迁移、多槽位管理 ❌ |
| 7 开放世界和成长 | — | 多区域地图、程序化世界、NPC、成长（未开始） |
| 8 正式版本 | — | 导出打包（模板未装）、发布打磨（未开始） |

## 系统清单

| 系统 | 位置 | 状态 |
|---|---|---|
| 施法管线 | `scripts/magic/` | 缓存两层 + 本地规则 + 验证钳制 + 平衡 + 唯一性 + 工厂 + 执行器（projectile/explosion/field/tornado 四形状） |
| 执行形状 | `scripts/effects/` | 投射物 / 爆炸（玩家免疫）/ 冻结领域 / 狂风龙卷；area/beam/shield/summon 保持"未觉醒"退款 |
| 敌人 | `scripts/enemies/` | 史莱姆（游荡/追击/接触伤害/冻结/吹飞）、史莱姆王（休眠→追击→前摇→重砸→恢复循环 + 落点预警圈） |
| 世界 | `scripts/world/` | 种子确定性重建 + 增量重放；河流/瀑布动画/树摇/BGM |
| 存档 | `scripts/save/` | 三层：世界记忆（永久）/ 会话槽 / 法术缓存；全部原子写 + 版本校验 + 损坏安全 |
| 音频 | `scripts/audio/` | 13 条程序化 SFX（元素化施法/受击/落地）+ 24s 循环 BGM；Music/SFX 总线 + 设置面板实时调节 |
| UI | `scripts/ui/` | 标题页（开始/继续/设置/退出）、暂停面板、法术图鉴（滚动/筛选）、HUD 血魔条 + Boss 血条 |
| 相机 | player 内置 | 平滑跟随 + 地图四边钳制 + 瞬移吸附 |

## 测试索引（26 套）

`tests/<name>_test.gd`，全部 `godot --headless --path . -s res://tests/<name>_test.gd` 运行：

player_movement · transition_tiles(40) · prop_sprites · prop_placement · prop_collision ·
river_collision · water_tiles · player_sprites · player_animation · magic_pipeline ·
slime_sprites · combat · spell_session · **spell_cache(21)** · **shapes(13)** · puzzle ·
save · sfx · water_anim · ambient · **boss(27)** · **world_memory(24)** · spellbook ·
**flow(14)** · camera(7) · **settings(18)**

（加粗为本轮新增套件；括号内为断言数，未标注者为早期套件。）
测试隔离：`tests/test_isolation.gd` 统一 stash/unstash `user://` 下真实文件
（世界记忆/法术缓存/设置/存档槽），测试批后开发机零残留。

## 里程碑（27 commits）

| 提交 | 内容 |
|---|---|
| d50fb5f → 73f2c8a | 素材盘点重组 → Phase 0 初始化 |
| 8c5c77b → 8dae4db | Phase 1：移动/过渡地块/物件/水系/角色精灵 |
| 29961c7 → 6357801 | Phase 2-3：施法核心/会话唯一性/战斗 |
| 437c5f9 | Phase 2 收口：唯一性+图鉴 |
| 0f8cea0 | Phase 4：符文解谜 |
| a88070f → f597530 | 存档体系/SFX/打磨/水动画 |
| 92ee63b | 氛围轮：BGM + 树摇 |
| 086247a → eccfa79 | Boss 战 / 世界记忆 |
| f410033 | 打磨包：预警圈/受击音/图鉴筛选 |
| 1eb6eb6 | 施法缓存层（Phase 5 离线） |
| 8f94284 | 法术形状执行器 ×3 |
| c67d5b1 → 30219f1 | 标题/暂停/流程 + 相机边界 |
| 1fa7afb | 设置页 + 键盘导航 |

## 已知限制与待办

- 退出期 ObjectDB 警告为已知良性项（音频流退出顺序，运行期零错误）。
- Boss 无冲刺落点地面预警圈之外的逃生窗口提示（末段加深）；冻结对 Boss 无抗性。
- 会话存档为单槽位（slot_01）；多槽位与槽位管理 UI 未做。
- 导出打包（Phase 8）待安装官方导出模板（~1GB）后执行。
- **AI Provider（Phase 5 后半）等待项目所有者提供 Base URL / API Key / 模型名**；
  密钥永不入库（AGENTS.md §8）。
