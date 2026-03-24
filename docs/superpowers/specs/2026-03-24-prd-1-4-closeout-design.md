# I.C.U. PRD 1.4 收口设计

日期：2026-03-24

## 背景

当前仓库已经具备 `1.0-1.4` 的主要代码骨架，但存在三类关键裂口：

1. `builder CLI`、`Avatar Wizard`、运行时资产加载各自维护一套逻辑，资产生成和消费没有完全打通。
2. `1.1-1.3` 的状态、提醒、饮水、报告统计没有统一主数据源，`daily_stats.json` 与 `SQLite` 并行存在，口径容易漂移。
3. `PRD 1.4` 的关键闭环未完全落地，包括 `--rescue` 缺失、UI 默认绕过检查点、运行时未优先消费 builder 生成的动作帧。

本次工作按“第二档”执行：以 `PRD 1.4` 为主收口，同时对齐直接影响闭环的 `1.0-1.3` 相关实现。

## 目标

本次收口完成后，系统应满足以下条件：

1. `builder` 成为唯一资产生产管线，CLI 和 UI 共用同一编排逻辑。
2. 运行时优先消费 `assets/pets/<pet_id>/<action>/0.png` 结构，`base.png` 仅作兼容 fallback。
3. 状态切换、提醒、饮水、日报、周报以 `SQLite` 为主数据源。
4. `daily_stats.json` 降级为兼容层，不再作为统计真相来源。
5. 保留旧宠物资产和现有菜单/桌宠基本可用，不做超出收口范围的大改。

## 范围

### 包含

1. 完成 `builder` 的 `checkpoint -> generate -> slice -> rescue -> pack` 闭环。
2. 实现 `--rescue`，并完整保留 `_needs_rescue/<pet_id>/` 救援现场。
3. 让 `Avatar Wizard` 复用 builder 编排和打包能力，不再单独写资产目录。
4. 增加运行时资产解析层，支持 builder 产物与旧资产并存。
5. 统一提醒类型和关键统计口径到 `SQLite`。
6. 调整日报/周报汇总逻辑，使其优先基于 `SQLite` 生成。
7. 为以上行为增加回归测试。

### 不包含

1. 不重写完整 AI 上下文感知引擎。
2. 不扩展新的 UI 流程或新入口。
3. 不对 `1.0-1.4` 做全面重构式 PRD 清扫。
4. 不要求一次性迁移或重建全部历史宠物资产。

## 设计

### 1. 统一资产管线

新增一个 builder 编排层，负责串起以下步骤：

1. persona 生成
2. 图像生成
3. 图像切割
4. 打包输出
5. 救援恢复

`builder.py` 仅负责参数解析和命令行输出，`Avatar Wizard` 改为调用同一编排层。

### 2. Rescue 机制

当切割失败时：

1. 创建 `_needs_rescue/<pet_id>/`
2. 保存 `raw_sheet.png`
3. 保存最小配置元数据，至少包含 `pet_id`、`display_name`、`expected_actions`、`ai_persona_system_prompt`
4. 输出明确的救援说明

`--rescue <pet_id>` 执行时：

1. 读取 `_needs_rescue/<pet_id>/`
2. 跳过 persona 和图像生成
3. 从人工补齐的切片或救援输入继续打包
4. 生成标准资产目录并保留兼容预览图

### 3. 资产格式与运行时消费

标准资产结构定义为：

```text
assets/pets/<pet_id>/
├── config.json
├── base.png
├── idle/0.png
├── working/0.png
└── alert/0.png
```

运行时新增资产解析逻辑，优先读取动作目录：

1. `idle -> idle`
2. `working -> working`
3. `focus/break/eye_care/stretch/hydration -> alert`

若动作缺失，按 `alert -> working -> idle -> base.png` 顺序降级。

`AssetPacker` 在打包时负责：

1. 写入动作帧目录
2. 生成或复制稳定的 `base.png`
3. 写入运行时需要的最小 `config.json`

### 4. SQLite 主数据源

保留现有 `Database` 作为底层连接和建表入口，并在其上收敛一层统一的业务数据访问。

本次统一以下写入路径：

1. 状态切换
2. 提醒展示
3. 提醒响应
4. 饮水记录
5. 报告汇总

提醒类型统一为：

1. `eye_care`
2. `stretch`
3. `hydration`

`water` 与 `hydration` 的混用在本次收口中清理掉。

### 5. `daily_stats.py` 的兼容策略

`daily_stats.py` 不立即删除，改为兼容门面：

1. 对现有调用点保持接口兼容
2. 内部优先写入 `SQLite`
3. 仅在必要时同步 JSON，避免现有 UI 直接失效

### 6. 报告生成

`ReportGenerator` 改为基于 `SQLite` 汇总关键指标：

1. 工作时长
2. 专注次数与时长
3. 暂离次数
4. 护眼/拉伸/补水响应率
5. 饮水达成率

`DailyReportDialog` 与 `WeeklyReportDialog` 继续保留现有 UI 外壳，但消费统一汇总结果。

## 迁移顺序

1. 先抽出统一 builder 编排层，并为其补测试。
2. 切换 CLI 到新编排层，完成 `--rescue`。
3. 切换 `Avatar Wizard` 到同一编排和打包路径。
4. 增加运行时资产解析层，兼容旧 `base.png` 资产。
5. 收敛提醒、饮水、状态切换和报告到 `SQLite` 主路径。
6. 最后把 `daily_stats.py` 降级为兼容门面。

## 测试策略

### Builder

1. 检查点命中时不重复生成
2. 切割失败时正确落地 `_needs_rescue/<pet_id>/`
3. `--rescue` 能恢复并完成打包
4. 打包后的资产目录和 `config.json` 满足运行时预期

### 运行时资产

1. 新资产结构可被正确解析
2. 缺失动作时 fallback 正确
3. 旧 `base.png` 资产仍可加载

### 数据与报告

1. 状态切换写库后，可生成正确的日报/周报关键字段
2. 提醒响应和饮水记录能被统一统计
3. `daily_stats.py` 的兼容调用不会绕开 `SQLite` 主路径

### 集成

1. 自定义形象从生成到选择再到桌宠加载形成闭环
2. UI 不再默认强制 `force=True` 绕过检查点

## 风险

1. 旧资产目录字段可能不完整，需要运行时解析层提供稳健 fallback。
2. `daily_stats.py` 的兼容改造如果处理不好，可能导致 UI 显示与数据库口径不一致。
3. builder 和 UI 共用编排层后，异常信息需要同时兼顾 CLI 与对话框两种消费方式。

## 说明

由于当前协作约束不允许启用子代理，本次设计文档采用人工自审代替 spec-review 子代理流程。实现前仍需用户确认该文档内容。
