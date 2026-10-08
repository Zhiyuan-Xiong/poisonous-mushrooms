# 引擎与网页再导出

Windows 完整发行包附带官方 Godot 4.7.2；Git 源码仓库不重复存储引擎可执行文件。

- 官方下载与模板：https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable
- 导出文档：https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html
- 引擎授权：[LICENSE.godot.txt](LICENSE.godot.txt)、[COPYRIGHT.godot.txt](COPYRIGHT.godot.txt)

## 编辑与导出

1. 使用 Godot 4.7.2 打开根目录的 project.godot。
2. 在「编辑器 → 管理导出模板」安装同版本官方模板。
3. Web 预设已配置单线程导出；临时结果写入 build/web/index.html。
4. 从项目根目录运行下面的脚本。脚本保留中文试玩页与素材页，更新引擎文件和 game.html。

```powershell
powershell -ExecutionPolicy Bypass -File tools/export-web.ps1 -GodotExe "你的路径/Godot_v4.7.2-stable_win64_console.exe"
```

提交更新后的 docs/ 到 main 后，GitHub Pages 自动发布网页版。首次加载下载引擎和游戏素材；页面提供键盘和屏幕按钮。

## 源码测试

```powershell
godot --headless --path . --script res://tests/test_model.gd
godot --headless --path . --script res://tests/test_integration.gd
godot --headless --path . --script res://tests/runtime_smoke.gd
```
