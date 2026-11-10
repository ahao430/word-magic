# Word Magic: The Living World

语言驱动的 2D 奇幻像素 RPG。玩家用自然语言与语音创造魔法，世界记住每一次选择。

- 引擎：Godot 4.x（GDScript）
- 平台：macOS（首发）/ Windows（后续）
- 美术：HD Pixel Art

## 快速开始

```bash
# 安装 Godot 4.x 后（macOS: brew install --cask godot）

# 首次导入资源（无窗口）
godot --headless --path . --import

# 运行游戏
godot --path .

# 地块平铺验证场景（渲染 10×10 地面拼块并截图）
godot --path . res://scenes/dev/ground_tile_test.tscn
```

## 目录

| 目录 | 用途 |
|---|---|
| `scenes/` | Godot 场景（`main/` 主场景，`dev/` 开发验证场景） |
| `scripts/` | GDScript（`core/` 全局服务，`dev/` 验证脚本） |
| `assets/tilesets/` | 生产用 TileSet 素材 |
| `assets/source/generated/` | AI 生成原始素材（只读） |
| `assets/manifest/` | 素材授权记录 |
| `docs/` | 设计文档（美术工程见 `ART_ASSET_IMPLEMENTATION.md`） |
| `tools/dev/` | 一次性项目配置脚本 |

## 文档

- 项目总计划：`PLAN.md`
- AI 代理开发规范：`AGENTS.md`
- 美术资源工程：`docs/ART_ASSET_IMPLEMENTATION.md`

*Words become magic. Imagination shapes the world.*
