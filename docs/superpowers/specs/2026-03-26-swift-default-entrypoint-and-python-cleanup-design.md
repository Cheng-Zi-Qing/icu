# Swift 默认启动入口与 Python 中等清理设计

日期：2026-03-26

## 背景

当前仓库已经具备可运行的 Swift/AppKit shell：

1. `apps/macos-shell` 可在仅安装 `Command Line Tools` 的环境下通过 `swift build`
2. `bash tools/verify_macos_shell.sh` 可完成默认轻量验证
3. `bash tools/run_macos_shell.sh` 可直接启动原生 shell，并初始化 `~/Library/Application Support/ICU/state/current_state.json`

但用户入口和默认技术路线仍未真正切换：

1. 仓库根目录的 [`icu`](/Users/clement/Workspace/icu/icu) 仍默认启动旧的 Python/Qt 路径
2. [`run_pet.py`](/Users/clement/Workspace/icu/run_pet.py) 仍指向 `src.pet_main`
3. [`requirements.txt`](/Users/clement/Workspace/icu/requirements.txt) 仍包含为旧 Qt 启动链服务的依赖
4. README 中的技术栈和项目结构仍把 Python/Qt 视为主路径

用户当前要求是：

1. 废弃 Python 默认启动
2. 保留 Swift 作为主入口
3. 对“不再需要的 Python 部分和依赖”做清理，但不是一次性激进删除全部 Python

## 目标

本次设计完成后，应满足以下条件：

1. 仓库根目录存在单一默认启动命令：`./icu`
2. `./icu` 默认启动 Swift shell，而不是 Python/Qt
3. `./icu --verify` 可直接执行当前原生 shell 的默认轻量验证
4. `requirements.txt` 不再包含只服务旧 Qt 启动链的运行依赖
5. 仍被 builder、图像处理或迁移工具链使用的 Python 依赖继续保留
6. README 与中文 README 明确说明：Swift 是默认运行主路径，Python 只保留仍在迁移中的工具链角色

## 非目标

1. 本次不一次性删除全部 `src/` 下的 Python UI 文件
2. 本次不删除 builder、图像生成、切图、资产打包所需 Python 依赖
3. 本次不接入 WorkerClient 或 Python worker 新协议
4. 本次不承诺彻底移除仓库中全部 PySide6 代码

## 当前依赖边界

### 应保留的 Python 依赖

以下依赖仍在当前仓库内被非默认启动路径真实使用：

1. `transitions`
   - 用于 `src/state_machine.py`
2. `requests`
   - 用于 `builder/persona_forge.py`、`builder/prompt_optimizer.py` 等 builder/AI 调用
3. `Pillow`
   - 用于 `builder/vision_slicer.py`
4. `huggingface-hub`
   - 用于 `builder/vision_generator.py` 与若干图像脚本
5. `rembg`
   - 用于图像处理链路
6. `opencv-python`
   - 用于切图与图像处理
7. `watchdog`
   - 当前 `src/state_sync.py` 仍在使用

### 应退出默认运行依赖的内容

以下内容当前主要服务旧 Qt 主路径，不应继续作为默认启动依赖：

1. `PySide6`
   - 旧桌宠 UI、旧 Avatar Wizard、旧配置对话框、旧报告对话框均依赖它
2. `pytest`
   - 属于开发/测试依赖，不应留在运行依赖中

### 历史说明

README 中目前仍提到 `rumps`，但代码内已经没有实际引用。本次应一并从文档中移除，避免继续误导默认技术栈。

## 设计

### 1. 单命令默认入口

把仓库根目录的 [`icu`](/Users/clement/Workspace/icu/icu) 改造成 Swift shell 统一入口：

1. `./icu`
   - 默认执行原生 shell 启动逻辑
   - 等价于当前的 `bash tools/run_macos_shell.sh`
2. `./icu --verify`
   - 执行原生 shell 轻量验证
   - 等价于当前的 `bash tools/verify_macos_shell.sh`

这样用户以后只需要记一个入口，而不是分别记 `tools/run_macos_shell.sh` 和 `tools/verify_macos_shell.sh`。

### 2. Python 入口降级为 legacy

以下旧入口不再作为默认用户路径：

1. [`run_pet.py`](/Users/clement/Workspace/icu/run_pet.py)
2. `python3 -m src.pet_main`

本次不要求彻底删除所有 legacy Python UI 文件，但必须明确：

1. 它们不再由默认入口触发
2. 它们不再被 README 当作推荐运行方式
3. 如需保留，可在脚本或文件头部标注为 legacy / transitional

### 3. 依赖清理策略

对依赖做“中等清理”，不是激进删除：

1. 从 [`requirements.txt`](/Users/clement/Workspace/icu/requirements.txt) 中移除 `PySide6`
2. 从 [`requirements.txt`](/Users/clement/Workspace/icu/requirements.txt) 中移除 `pytest`
3. 在 [`requirements-dev.txt`](/Users/clement/Workspace/icu/requirements-dev.txt) 中保留 `pytest`
4. 保留 builder、图像处理、状态同步仍在使用的 Python 依赖

这样可以达到两个目的：

1. 默认运行链路不再要求安装旧 Qt UI 依赖
2. builder/图像工具链不会因为过早清理而被破坏

### 4. 文档同步

README 与中文 README 需要同步更新：

1. Quick Start 默认命令改为 `./icu`
2. 原生 shell 验证命令保留，但归入 Swift shell 开发说明
3. 技术栈不再把 `PySide6` 和 `rumps` 列为默认主栈
4. 项目结构里应开始显式体现 `apps/macos-shell`
5. Python 相关内容只描述为“builder / legacy / transitional”，而不是默认 UI 主路径

### 5. 本地测试体验

完成后，用户最小本地工作流应当是：

```bash
./icu
```

以及：

```bash
./icu --verify
```

不再要求用户记住更长的 `bash tools/...` 命令。

## 备选方案比较

### 方案 A：只改 README，不改根入口

优点：

1. 改动小

缺点：

1. 用户仍然要记多个命令
2. 仓库根入口继续误导到 Python/Qt

### 方案 B：切换根入口到 Swift，并做中等依赖清理

优点：

1. 用户入口最直接
2. 与当前迁移目标一致
3. 不会一次性破坏 builder 工具链

缺点：

1. 旧 Python UI 代码仍会暂时留在仓库内

本次采用方案 B。

### 方案 C：直接删除全部 Python UI 与依赖

优点：

1. 结构最干净

缺点：

1. 风险太高
2. 容易误删仍在迁移中或工具链仍依赖的 Python 部分

## 测试策略

### 启动入口

验证以下内容：

1. `./icu` 能启动 Swift shell
2. `./icu --verify` 能执行轻量验证
3. 非法参数有清晰错误信息

### 依赖边界

验证以下内容：

1. `requirements.txt` 不再包含 `PySide6` 与 `pytest`
2. `requirements-dev.txt` 仍包含 `pytest`
3. builder 相关 Python 依赖仍保留

### 文档一致性

验证以下内容：

1. README 与中文 README 的 Quick Start 改为 `./icu`
2. README 技术栈不再把 Qt/rumps 当默认运行栈
3. `apps/macos-shell` 已被纳入主项目结构说明

## 风险

1. 如果依赖清理过度，可能误伤 builder 或状态同步路径。
2. 如果根入口切换但 README 未同步，用户仍会被旧路径误导。
3. 旧 Python UI 文件短期仍会存在，必须通过文档和入口约束明确它们已退出主路径。

## 说明

由于当前协作约束不允许启用子代理，本次规格文档采用人工自审代替 spec-review 子代理流程。

当前仓库工作区已存在未提交内容，本次仅写入规格文档，不在此步骤执行额外 git commit。
