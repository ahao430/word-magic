# Word Magic: The Living World

语言驱动的 2D 奇幻像素 RPG。玩家用自然语言与语音创造魔法，世界记住每一次选择。

- 引擎：Godot 4.7.2（GDScript）
- 平台：macOS（首发）/ Windows（后续）
- 美术：HD Pixel Art（全程程序化生成，零外部素材依赖）

## 当前状态（2026-11-11）

垂直切片完整可玩：**标题 → 森林探索 → 文字施法 → 战斗 → 史莱姆王 Boss → 符文解谜 →
存读档 → 世界记忆跨重启**。31 套自动化测试全绿（617 断言）。详见
`docs/development-roadmap.md`。

## 快速开始

```bash
# 安装 Godot 4.x（macOS: brew install --cask godot）

# 首次导入资源（无窗口）
godot --headless --path . --import

# 运行游戏（从标题页开始）
godot --path .

# 一键全量回归（31 套 / 617 断言，~2.5 分钟；--filter 可跑子集）
tools/dev/run_tests.sh

# 游戏内截图验证（写 /tmp/wm_*.png；不要加 --headless）
godot --path . res://scenes/dev/gameplay_screenshot.tscn --quit-after 900
```

提交前流程见 [docs/pre-commit-checklist.md](docs/pre-commit-checklist.md)。

## 天气系统

世界在**晴朗 / 起风 / 细雨 / 风雨交加**间流转（右上角常驻指示：天气 + 风向箭头 + 风力 + 战术提示）。
- **风向影响弹道**：一切飞行物（含普攻、AI 法术、回响）顺风加速、逆风减速侧偏——
  风雨交加时 0.35×风力横向偏移，预判走位成为必修课
- **雨水改写元素伤害**：火 -25%、雷 +25%（在命中点结算）——雨中落雷成王牌，
  火系咒语慎选
- **雨中链电**：湿天雷电命中后跳弧到 110px 内的下一个敌人——细雨跳 1 次（60% 伤害）、
  风雨交加跳 2 次（60%→36%）。群怪站得越密，雷法越凶；HUD 提示「链电」
- **风场漂移**：领域/龙卷随风移动（龙卷 0.22×、领域 0.10×风速）——上风口施放，
  让龙卷卷进敌群
- **晴日回蓝**：晴朗天气魔力回复 +50%（HUD 提示「回蓝」）——晴天多搓大招，
  雨天省着花
- 天气随会话存档保存（F5/F9 一并恢复）

## 语音施法（可选）

按住 **V** 说话 → 松开 → 确认面板（Enter 施法 / Esc 取消）。识别错误取消零惩罚、
不扣魔力。config/ai.json 填 `asr_model`（如 `whisper-1`）即启用；`asr_base_url` 留空
复用 `base_url`，任何 OpenAI 兼容 `/audio/transcriptions` 服务均可（本地端点经探测
暂无 ASR，接 whisper.cpp server 只需填两个字段）。`cast_phrase` 可设口令前缀
（如"施法"，防止日常对话误触发；留空 = 所说即咒语）。

## AI 配置（可选）

游戏完全可离线游玩（本地 11 条咒语表）。接入任意 OpenAI 兼容接口以解锁自由施法：

```bash
cp config/ai.example.json config/ai.json   # 然后编辑 ai.json 填入：
# base_url     如 https://api.xxx.com/v1
# api_key      你的密钥（ai.json 已被 .gitignore 忽略，绝不入库）
# chat_model   模型名
```

保存即生效（无需改代码）：未收录的咒语将走 AI 解析，产出仍 100% 经过本地
白名单验证/数值钳制/平衡定价/会话唯一性——AI 只负责"听懂"，不负责"放行"。
AI 超时/限流/不可用时软失败：不扣魔力、不占咒语次数、稍后可重试。

## 操作

| 按键 | 作用 |
|---|---|
| WASD / 方向键 | 移动 |
| 鼠标左键 / 空格 | **普攻**：奥术飞弹（免费，0.35s 冷却，指向鼠标，点击自动吸附敌人） |
| 按住 V | 语音施法（需配置 asr_model；松开识别，Enter 确认，Esc 取消） |
| 鼠标右键 | **法术回响**：重放最近一次文字施放的法术（40% 魔力、50% 伤害、可重复；文字创造唯一奇迹，鼠标释放回响） |
| 回车（输入框） | 输入咒语施法（本地 11 条 + AI 自由解析；火球术 / 寒冰箭 / 落雷 / 烈焰焚天 / 冰封千里 / 风卷残云 / 烈光贯日 / 大地脉动 / 守护之壁 / 唤灵术 …） |
| Tab | 法术图鉴（可筛选） |
| Esc | 暂停（继续 / 重新开始 / 回到标题） |
| F5 / F9 | 存档 / 读档（3 槽位面板：时间+摘要卡片，可删除） |
| F8 | 重置世界（清除世界记忆，从种子重建） |
| 鼠标 | 标题/暂停/设置界面 |

## 目录

| 目录 | 用途 |
|---|---|
| `scenes/` | Godot 场景（`main/` 主场景、`ui/` 标题、`enemies/`、`effects/`、`dev/` 验证） |
| `scripts/` | GDScript（`core/` 全局服务、`magic/` 施法管线、`world/`、`enemies/`、`effects/`、`ui/`） |
| `assets/tilesets/` | 生产用 TileSet 素材 |
| `assets/source/generated/` | AI 生成原始素材（只读，`.gdignore`） |
| `assets/manifest/` | 素材授权记录（`licenses.md`） |
| `docs/` | 设计文档 |
| `tests/` | 31 套 headless 测试（`-s` 直接运行） |
| `tools/dev/` | 素材生成器与一次性配置脚本 |

## 文档

| 文档 | 内容 |
|---|---|
| `plan.md` | 项目总计划（需求与路线图） |
| `AGENTS.md` | AI 代理开发规范 |
| `docs/development-roadmap.md` | 开发进度总表（Phase 状态 + 里程碑） |
| `docs/magic-system.md` | 施法管线架构（缓存/验证/平衡/唯一性/执行） |
| `docs/save-system.md` | 三层存档架构（世界记忆/会话/缓存） |
| `docs/ART_ASSET_IMPLEMENTATION.md` | 美术资源工程（盘点/处理/生成器） |

*Words become magic. Imagination shapes the world.*
