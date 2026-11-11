# 提交前检查表（Pre-commit Checklist）

每轮开发提交前按序过一遍。全部打勾才 `git commit`（AGENTS.md §15/§16）。

## 1. 编译与类缓存

- [ ] 新增/重命名 `class_name` 后跑过一次 `godot --headless --editor --quit --path .`
      （headless `-s` 测试靠 `.godot` 类缓存解析全局类，不刷新会假失败）
- [ ] `godot --headless --check-only -s <改动的脚本>` 无 Parse Error
      （编译错误会静默让脚本挂不上节点 → 测试挂起而非报错）

## 2. 回归

- [ ] `tools/dev/run_tests.sh` 全绿（31 套 / 600+ 断言，~2.5 分钟）
      - 改动只触及个别系统时至少跑 `--filter <相关套件>` + 全量留到提交前
- [ ] 挂起（HANG）= 通常是被 SCRIPT ERROR 打断的 `await`：看 runner 保留的日志路径

## 3. 冒烟（改了玩法/场景/UI 时）

- [ ] `godot --path . res://scenes/dev/gameplay_screenshot.tscn --quit-after 900`
      （**不要加 `--headless`**：截图流程靠真实渲染帧驱动）
- [ ] 日志无 SCRIPT ERROR；截图正常落盘 `/tmp/wm_gameplay_*.png`

## 4. 接真实 AI 时（可选，改了 provider/解析器才跑）

- [ ] `godot --headless --path . -s tools/dev/ai_smoke.gd`
      （真实网络请求，读 config/ai.json；密钥永不入库/入日志）

## 5. user:// 干净

- [ ] 测试/冒烟后 `ls ~/Library/Application\ Support/Godot/app_userdata/WordMagic/`
      应为空（套件自 stash/restore；出现残留说明某套件泄漏，先修它）

## 6. Git 卫生

- [ ] `git status` 无无关文件；`config/ai.json` 永不出现在暂存区（§8）
- [ ] 提交信息带前缀：`feat:` `fix:` `refactor:` `docs:` `test:` `assets:` `chore:`
- [ ] 一次提交一个主题；不夹带未汇报的改动

## 7. 汇报

- [ ] 报告含：实现内容 / 变更文件 / 测试与结果 / 已知限制 / 建议下一步（§18 Step 6）
- [ ] 未验证的路径明说（"生成 ≠ 完成"）
