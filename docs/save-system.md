# Save System Architecture

> 依据 AGENTS.md §11 与 PLAN.md：存档体系分三个逻辑层。本文记录已实现的部分。
> 最后更新：2026-11-11（世界记忆层落地）。

## 三层结构

| 层 | 内容 | 存储位置 | 生命周期 |
|---|---|---|---|
| 1. 永久世界进度（世界记忆） | 世界增量事件：Boss 被击败、符文苏醒、渡口建成 | `user://world_memory.json` | 跨会话、跨重启，直到 F8 重置 |
| 2. 当前冒险会话 | 玩家状态、法术会话（唯一性+图鉴）、世界瞬态（史莱姆存活、Boss 血量、渡口旗标） | `user://saves/<slot>/save.json` | F5/F9 存读，一次冒险 |
| 3. 全局 AI 缓存 | AI 解析缓存（精确/归一化/语义） | 未实现（等 AI Provider 接入） | 跨会话，与存档分离 |

## 核心模型：种子重建 + 增量重放

世界本身**不进存档**：每次启动由确定性种子（噪声种子、`PROP_SEED`、`SLIME_SEED`）
完整重建，然后把两层状态叠加：

1. 先重放**世界记忆**（永久层）——`world.gd _apply_world_memory()`：
   - `boss_slime_defeated` → 移除史莱姆王（永久死亡）
   - `rune_awakened` → 符文静默回放到 ACTIVATED
   - `ford_built` → 重建石桥渡口
2. 会话读取（F9）时再叠加**会话层**瞬态（血量、坐标、已死史莱姆名单）。

**优先级规则**：永久层 > 会话层。旧会话存档无法复活已永久死亡的 Boss
（`restore_state` 里 `get_boss()` 为空即提前返回，会话数据不生效）。
已验证：`tests/world_memory_test.gd`「session save cannot resurrect…」。

## 文件格式与安全

- JSON，带 `version` 字段；loader 拒绝未知版本（前向兼容走迁移，暂无先例）。
- 写入原子化：先写 `.tmp` 再 `rename_absolute`，崩溃不会破坏上一份有效数据。
- 损坏文件：会话槽报错返回 `{ok:false}`；世界记忆损坏时**降级为空世界开局**
  （游戏永不为元进度损坏而阻塞），仅在日志留警告。
- 世界记忆缺文件 = 全新世界（非错误）。

## 触发点

| 事件 | 写入时机 |
|---|---|
| Boss 死亡（`world._on_boss_died`） | `WorldMemory.record_and_persist` 立即落盘（崩溃安全） |
| 渡口建成（`world.build_ford`） | 同上（同时记录 ford + rune 两个事件，幂等） |
| F5/F9 | 只读写会话槽，不触碰世界记忆 |
| F8（dev） | `WorldMemory.clear_persisted()` 删文件 + `reload_current_scene()` 从种子重建 |

## 实现位置

- `scripts/world/world_memory.gd` — 静态类（沿 Sfx/SaveManager 先例，非 autoload）；
  事件 ID 常量（`EVENT_BOSS/EVENT_FORD/EVENT_RUNE`）、惰性加载、record/persist/replay。
- `scripts/save/save_manager.gd` — `save_world_memory / load_world_memory /
  delete_world_memory`（原子写、版本校验、损坏拒读）。
- `scripts/world/world.gd` — `_apply_world_memory()`（启动重放）、事件记录。
- `scripts/core/main.gd` — F8 重置、提示文案。

## 测试

`tests/world_memory_test.gd`（24 项）：文件 I/O 语义（缺文件/往返/损坏/版本）、
WorldMemory 单元（幂等记录、capture/apply、reload_from_disk）、重启循环
（杀 Boss/建渡口 → 新世界重放）、会话 vs 记忆优先级、F8 重置复原。
所有会触发永久事件的测试套件（puzzle/save/boss/water_anim/world_memory 与
gameplay_screenshot 场景）均做了**真实文件备份/清空/恢复隔离**，测试批结束后
开发机世界记忆文件保持原样。
