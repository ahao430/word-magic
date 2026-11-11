# Magic Engine 架构

> 对应 AGENTS.md §7 与 plan.md §5。记录已实现管线的现状与语义。
> 最后更新：2026-11-11（Phase 5 离线半场：施法缓存层落地）。

## 管线现状（AGENTS.md §7.1）

| 管线层 | 状态 | 实现 |
|---|---|---|
| Text Normalization | ✅ | `text_normalizer.gd`：去空白/标点、全角折叠、小写、CJK 保留 |
| **Exact Cache** | ✅ | `spell_cache.gd`：原样文本 → draft，跨冒险持久 |
| **Normalized Cache** | ✅ | 同上：规范化键 → {raw, draft}，同一咒语的标点/空格变体复用解析 |
| Local Spell Rules | ✅ | `local_spell_registry.gd`：7 条本地咒语习语 |
| Semantic Cache | ❌ | 等 Embedding Provider（可选配置项已预留） |
| AI Spell Parser | ✅ | `scripts/ai/spell_parser.gd`（OpenAI 兼容；经 `chat_provider.gd`，见下） |
| Schema/Skill Validation | ✅ | `spell_validator.gd`：白名单 + 数值钳制 |
| Balance Calculator | ✅ | `spell_balance.gd`：游戏侧统一算价 |
| Duplicate Detection | ✅ | `spell_session.gd`：exact → normalized → mechanism 三级 |
| Spell Factory | ✅ | `spell_factory.gd` |
| Spell Executor | ✅ | `spell_executor.gd`（**白名单 8 形状全部实装**：projectile / explosion / field / tornado / area / beam / shield / summon） |

`magic_facade.cast()` 按上表顺序编排，返回额外带 `source` 诊断字段
（`registry` / `cache_exact` / `cache_normalized`），UI 不消费。

## 缓存语义（信任规则）

缓存是**便利，不是权威**——命中后仍走完整验证路径：

1. 仍过 `SpellValidator`（参数钳制；即使缓存被污染，伤害也会被钳到上限 60）。
2. 仍过 `SpellSession` 唯一性门（同局重复照样拒绝，AGENTS §7.5）。
3. 仍扣等额魔力（缓存命中不免费）。
4. 执行失败退款不记录；只有真正发生的施法才进图鉴。

已验证：`tests/spell_cache_test.gd` 21 项（含「投毒条目被钳制」与
「重复施法仍被拒绝」两条对抗性用例）。

## 存储与安全

- `user://spell_cache.json`（全局层，跨存档槽共享），版本字段 `SPELL_CACHE_VERSION = 1`。
- 原子写（tmp + rename）；缺文件 = 冷缓存（非错误）；损坏/版本不符 → **降级为空缓存**，
  施法永远回落到本地注册表——缓存状态从不阻塞玩法（AGENTS §7.7）。
- 每次成功解析即写盘（低频事件，简单可靠）。
- 深拷贝出入：调用方修改返回 draft 不会污染缓存。

## AI Provider 层（已接入）

- **配置**：`config/ai.json`（gitignored；模板 `config/ai.example.json`）。
  字段：base_url / api_key / chat_model / embedding_model / 超时。留空 = 离线模式，
  本地一切照常（AGENTS §8 本地回退）。`user://ai_config.json` 为导出版备选路径。
- **ChatProvider**（`scripts/ai/chat_provider.gd`）：唯一网络缝。OpenAI 兼容
  `POST {base_url}/chat/completions`；HTTPRequest 异步 + 超时；失败分类
  ai_timeout / ai_rate_limited(429) / ai_unavailable / ai_invalid_response。
  **密钥只出现在 Authorization 头，绝不打日志、绝不进错误信息。**
- **SpellParser**：提示词由 SpellValidator 白名单**动态生成**（单一事实来源——
  模型永远学不到游戏会拒绝的选项）；纯文本解析容忍 ``` 围栏与前后废话；
  产出与 registry 同构的 draft。
- **Facade 集成**：cache/registry 全 miss 且 AI 已配置才走网络；AI draft 走
  **同一条**验证/钳制/定价/唯一性路径（source="ai"）；成功后入缓存，
  变体短语下次免网络。**基础设施失败软着陆**：不扣魔、不记录、可重试
  （AGENTS §7.7）。
- **可测性**：`ChatProvider.mock_complete` 为离线测试缝，28 套测试零网络。
- cast() 因此是协程——所有调用点 `await`（本地路径同步完成）。
