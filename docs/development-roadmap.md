# 开发路线进度表

> 对应 `plan.md` 的 Phase 0-8 路线图。最后更新：2026-11-12（平衡轮 af4fd8f）。

## Phase 状态

| Phase | 状态 | 内容摘要 |
|---|---|---|
| 0 项目初始化 | ✅ | Godot 4.7.2 工程、目录结构、输入映射、GameManager、引擎内地块验证 |
| 1 基础游戏原型 | ✅ | 玩家移动/相机/地图/过渡地块/物件层/水系/角色动画 |
| 2 语言施法核心 | ✅（离线部分） | 归一化/本地注册表/验证/平衡（潜力计价）/唯一性/图鉴/工厂/执行器 |
| 3 森林战斗样板 | ✅ | 史莱姆 AI/伤害循环/玩家受击与重生/**史莱姆王 Boss 战**（预警圈/血条/技能循环/风暴狂怒） |
| 4 环境互动与机关 | ✅ | 符文石解谜（规则验证）→ 渡口重建 |
| 5 AI 缓存和语音 | ✅ | Exact/Normalized/**Semantic** 三层缓存 + AI 解析（live e2e 通过）+ 语音输入（PTT + 确认流 + 口令门控）；语音 ASR 与语义 Embedding 等所有者配置端点即启用 |
| 6 世界记忆和存档 | ✅ | 三层模型（世界记忆/会话/缓存）+ **多槽位管理 UI（3 槽 + 元信息卡 + 删除）** + 设置持久化 |
| 7 开放世界和成长 | — | 多区域地图、程序化世界、NPC、成长（未开始；数值框架已稳） |
| 8 正式版本 | ◐ | **导出打包 ✅**（本地双平台 + CI 滚动 Release）；平衡守卫 ✅；发布打磨进行中 |

## 系统清单

| 系统 | 位置 | 状态 |
|---|---|---|
| 施法管线 | `scripts/magic/` | 三层缓存（exact/normalized/semantic 余弦 ≥0.86）+ 本地规则 + 验证钳制 + **潜力计价（2.0 效率守卫）** + 唯一性 + 工厂 + 执行器 |
| 执行形状 | `scripts/effects/` | **8/8 全觉醒**：投射物 / 爆炸 / 范围爆发 / 光束 / 冻结领域 / 狂风龙卷 / 护壁 / 唤灵 |
| 敌人 | `scripts/enemies/` | 史莱姆（游荡/追击/冻结/吹飞/**畏水/湿天减速**）、史莱姆王（技能循环 + 预警圈 + 二段狂怒 + **风暴狂怒**） |
| 天气 | `scripts/world/` | 四态游走（种子）/ 风偏弹道 / 雨系元素修正 / **雨中链电** / 区域随风漂移 / 晴日回蓝 / 敌我双向适配 |
| 输入 | `scripts/core/` `scripts/voice/` | 暗黑式鼠标（LMB 普攻吸附 / RMB 法术回响）+ 键盘 + 语音 PTT（AGENTS §9 全规则） |
| AI Provider | `scripts/ai/` | Chat/ASR/Embedding 三抽象（OpenAI 兼容）+ mock 缝离线全覆盖 + 失败分类学；密钥仅存 config/ai.json |
| 世界 | `scripts/world/` | 种子确定性重建 + 增量重放；河流/瀑布动画/树摇/BGM |
| 存档 | `scripts/save/` | 三层：世界记忆（永久）/ 会话槽（3 槽管理 UI）/ 法术缓存；全部原子写 + 版本校验 + 损坏安全 |
| 音频 | `scripts/audio/` | 13 条程序化 SFX（元素化施法/受击/落地）+ 24s 循环 BGM；Music/SFX 总线 + 设置面板实时调节 |
| UI | `scripts/ui/` | 标题页、暂停面板、法术图鉴（滚动/筛选）、存档槽面板、HUD 血魔条 + Boss 血条 + 天气指示 |
| 工具链 | `tools/dev/` `.github/` | run_tests.sh 一键回归（看门狗/汇总）+ 提交前检查表 + CI（测试 + 双平台导出 + 滚动 Release） |

## 测试索引（32 套 / 713+ 断言）

`tools/dev/run_tests.sh` 一键全量（发现 + 看门狗 + 汇总）；单套
`godot --headless --path . -s res://tests/<name>_test.gd`：

player_movement · transition_tiles(40) · prop_sprites · prop_placement ·
prop_collision · river_collision · water_tiles · player_sprites ·
player_animation · magic_pipeline · slime_sprites · combat · spell_session ·
spell_cache(35) · shapes(28) · puzzle · save · sfx · water_anim · ambient ·
boss(31) · world_memory(24) · spellbook · flow(14) · camera(7) · settings(18) ·
slots(18) · **ai_provider(34)** · **mouse_combat(20)** · **voice(19)** ·
**weather(50)** · **balance(30)**

（加粗为 AI/语音/天气/平衡阶段新增；括号内为断言数。）
测试隔离：`tests/test_isolation.gd` 统一 stash/unstash `user://` 下真实文件
（世界记忆/法术缓存/设置/存档槽），测试批后开发机零残留。

## 里程碑（47 commits）

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
| 8f94284 | 法术形状执行器 ×3（area/beam/summon） |
| c67d5b1 → 30219f1 | 标题/暂停/流程 + 相机边界 + 多槽位 UI |
| 1fa7afb | 设置页 + 键盘导航 |
| 8a0eeaa → 802be91 | AI Provider 接入 + 真实本地配置（live e2e 通过） |
| 110b330 | 暗黑式鼠标战斗（普攻 / 法术回响） |
| 2783353 | 语音施法（PTT + 确认流，AGENTS §9） |
| c2c72c1 → 41889c1 | 天气系统 + 交叉深化（链电 / 漂移 / 回蓝） |
| 52f7ef0 | 一键回归 runner + 提交前检查表 |
| 55e79b6 | 敌人天气 AI（湿天减速 / 畏水 / 风暴狂怒） |
| 71f8e41 | 语义缓存（§7.1 管线收口） |
| 9c92c68 → cc3e229 | 导出打包（本地双平台 + CI 滚动 Release，四轮调试全绿） |
| af4fd8f | 平衡轮（潜力计价 + 2.0 效率守卫 + knockback 真实现） |

## 已知限制与待办

- 退出期 ObjectDB 警告为已知良性项（音频流退出顺序，运行期零错误）。
- Boss 无冲刺落点地面预警圈之外的逃生窗口提示（末段加深）；冻结对 Boss 无抗性。
- **语音 ASR / 语义 Embedding**：实现完整、离线全测；本地端点经探测两者均无
  （404）。所有者在 config/ai.json 填 `asr_model`（任意 OpenAI 兼容
  `/audio/transcriptions`）或 `embedding_model`（任意 `/embeddings`）即启用。
- 存档为 JSON 三层（AGENTS §11）；SQLite 迁移未做（当前规模无需求）。
- macOS 为 ad-hoc 签名，首次打开需右键→打开；Windows exe 未签名
  （SmartScreen 可能提示）。正式发布需 Apple 开发者证书 / Windows 证书。

## 下一步（Phase 7 备选方向，源自 plan.md）

多区域地图与程序化世界骨架、兴趣点（POI）、NPC 与长期反馈、玩家成长曲线——
数值与测试框架已就绪，任一方向均可独立成轮。
