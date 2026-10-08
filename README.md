# 《毒蘑菇》

AI 素材工作流、可编辑 Godot 跑酷游戏与浏览器试玩。

**[完整设计案例](https://xiongzhiyuan-portfolio.pages.dev/zh/work/poisonous-mushrooms/) · [求职作品总入口](https://github.com/Zhiyuan-Xiong/xiongzhiyuan-portfolio)**

**[点击在线试玩](https://zhiyuan-xiong.github.io/poisonous-mushrooms/) · [下载 Windows 完整游戏包](https://github.com/Zhiyuan-Xiong/poisonous-mushrooms/releases/tag/v1.0.0)**

<p align="center"><img src="previews/游戏开始预览.png" alt="《毒蘑菇》" width="350"></p>

## 项目目标

邓泽西的官方 MV，以一位职场女性进入奇幻游戏世界并成为蘑菇女巫为线索。我参与前期整体概念、场景与分镜设计，并设计用于宣传的小游戏玩法与视觉资产。

## 我的贡献

前期概念、场景与分镜；宣传小游戏玩法与视觉资产；参与调色与视觉统一

完成阶段：MV 已发布；本页展示个人参与部分

现有产出：概念方案、叙事分镜、游戏界面与视觉资产

## AI 与制作工作流

### 1. 视觉概念与参考

从歌曲、蘑菇森林与角色设定整理画面方向，明确色彩、场景层次、角色轮廓与竖屏构图。

### 2. AI 素材制作

以结构化提示词生成森林、UI、角色、金币与怪兽素材，保留透明 PNG、高分辨率原图、完整动画帧和 GIF。提示词与生成记录位于 source_assets/ 和 制作提示词.json。

### 3. AI 辅助 Godot 搭建

把素材清单、三路切换、跳跃、碰撞、金币、250 米里程反馈和胜负界面连接成可运行游戏，源代码和测试均保留。

### 4. 人工调整与验证

筛选视觉结果，调整透明边缘、画面比例、道路投影、场景密度、动画节奏和碰撞体验，使用原生运行截图和测试继续修正。

### 5. 可交付成果

浏览器试玩、Windows 完整包、可编辑 Godot 工程及全部素材。复用素材清单、帧序列和提示词减少重复整理；未记录量化工时对比。

## 仓库内容

| 内容 | 入口 |
| --- | --- |
| 可编辑游戏 | [project.godot](project.godot)、[scripts/](scripts/)、[scenes/](scenes/) |
| 运行素材 | [assets/](assets/)、[audio/](audio/) |
| 原始素材与全部动画帧 | [source_assets/](source_assets/) |
| AI 提示词与生成记录 | [制作提示词.json](制作提示词.json) |
| 测试与真实预览 | [tests/](tests/)、[verification/](verification/)、[previews/](previews/) |
| 浏览器版与素材浏览页 | [docs/](docs/) |

## 运行与编辑

在线试玩不需要安装软件。Windows 完整包包含官方 Godot 4.7.2，完整解压后双击 `启动游戏.cmd`。源码编辑使用 Godot 4.7.2 打开 `project.godot`。

操作：A／D 或左右方向键切换道路；空格跳跃；Esc／P 暂停；R／回车重跑。网页版提供对应触控按钮。

## 验证

226 个原始素材 SHA-256 全部一致；模型测试 11569 项、100 个完整跑程通过；集成测试 336 项通过；原生运行冒烟测试通过。浏览器导出使用官方单线程 Web 模板，实际浏览器已验证加载、键盘操作和屏幕按钮，无 JavaScript 错误。再导出方法见 [tools/README.md](tools/README.md)。

## 署名与使用

作品素材用于个人设计展示。协作项目以案例中的职责说明为准；字体、引擎和第三方资料遵循各自授权。未经许可，不将作品素材用于转载或商业用途。
