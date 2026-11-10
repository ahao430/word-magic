# Word Magic: The Living World

语言驱动的 2D 奇幻像素 RPG。玩家用自然语言与语音创造魔法，世界记住每一次选择。

- 引擎：Godot 4.7.2（GDScript）
- 平台：macOS（首发）/ Windows（后续）
- 美术：HD Pixel Art（全程程序化生成，零外部素材依赖）

## 当前状态（2026-11-11）

垂直切片完整可玩：**标题 → 森林探索 → 文字施法 → 战斗 → 史莱姆王 Boss → 符文解谜 →
存读档 → 世界记忆跨重启**。26 套自动化测试全绿（493+ 断言）。详见
`docs/development-roadmap.md`。

## 快速开始

```bash
# 安装 Godot 4.x（macOS: brew install --cask godot）

# 首次导入资源（无窗口）
godot --headless --path . --import

# 运行游戏（从标题页开始）
godot --path .

# 运行全部自动化测试（26 套）
for t in player_movement transition_tiles prop_sprites prop_placement \
         prop_collision river_collision water_tiles player_sprites player_animation \
         magic_pipeline slime_sprites combat spell_session spell_cache shapes \
         puzzle save sfx water_anim ambient boss world_memory spellbook \
         flow camera settings; do
  godot --headless --path . -s res://tests/${t}_test.gd
done

# 游戏内截图验证（写 /tmp/wm_*.png）
godot --path . res://scenes/dev/gameplay_screenshot.tscn --quit-after 900
```

## 操作

| 按键 | 作用 |
|---|---|
| WASD / 方向键 | 移动 |
| 回车（输入框） | 输入咒语施法（如：火球术 / 烈焰焚天 / 冰封千里 / 风卷残云 / 落雷） |
| Tab | 法术图鉴（可筛选） |
| Esc | 暂停（继续 / 重新开始 / 回到标题） |
| F5 / F9 | 存档 / 读档（本冒险会话） |
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
| `tests/` | 26 套 headless 测试（`-s` 直接运行） |
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
