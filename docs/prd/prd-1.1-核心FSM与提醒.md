---
版本: "1.1"
标题: "I.C.U. - 核心 FSM 与基础提醒系统"
日期: "2026-03-15"
状态: 待开发
前置: ""
---

## 1. Scope (范围)

> v1.1 实现核心有限状态机（FSM）、Menu Bar 入口、基础健康提醒（护眼/拉伸/补水）与数据记录功能。

**交付物：**
- 可运行的 Menu Bar 应用
- 4 种状态切换（待机/工作/专注/暂离）
- 3 种健康提醒（护眼 20min、拉伸 45min、补水动态间隔）
- SQLite 数据持久化
- 提醒响应记录

---

## 2. 背景 & 动机

### 当前痛点

- 传统定时提醒工具打断心流
- 固定间隔不考虑个体差异
- 缺少健康行为追踪

### 为什么先做这个

- FSM 是整个系统的核心架构
- Menu Bar 是最轻量的 UI 入口
- 验证核心逻辑可行性

---

## 3. 目标

| 指标 | 目标值 |
|------|--------|
| 状态切换成功率 | 100% |
| 提醒触发准确性 | ±5 秒 |
| 数据记录完整性 | 100% |
| CPU 占用（待机） | < 0.5% |

---

## 4. 方案设计

### 4.1 核心状态机

使用 `transitions` 库实现 4 种状态：

```python
states = ['idle', 'working', 'focus', 'break']

transitions = [
    {'trigger': 'start_work', 'source': 'idle', 'dest': 'working'},
    {'trigger': 'enter_focus', 'source': 'working', 'dest': 'focus'},
    {'trigger': 'take_break', 'source': 'working', 'dest': 'break'},
    {'trigger': 'stop_work', 'source': '*', 'dest': 'idle'},
]
```

**状态行为：**

| 状态 | 计时器行为 | UI 显示 |
|------|-----------|---------|
| idle | 全部销毁 | Menu Bar 灰色图标 |
| working | 启动 3 个计时器 | Menu Bar 绿色图标 |
| focus | 冻结计时器，记录专注时长 | Menu Bar 黄色图标 |
| break | 暂停计时器 | Menu Bar 蓝色图标 |

### 4.2 Menu Bar UI

使用 `rumps` 构建菜单：

```
┌─────────────────┐
│ 🟢 I.C.U.       │
├─────────────────┤
│ ▶ 开始工作      │
│ 🔕 进入专注     │
│ ☕ 暂离         │
│ 🛌 下班         │
├─────────────────┤
│ ⚙️ 设置         │
│ ❌ 退出         │
└─────────────────┘
```

### 4.3 动态水合算法

**初始化配置：**

```python
config = {
    'body_weight': 70,      # kg
    'cup_volume': 300,      # ml
    'work_hours': 8,        # h
}

# 计算
daily_water = body_weight * 35  # ml
work_water = daily_water * 0.65
cups_needed = ceil(work_water / cup_volume)
interval = (work_hours * 3600) / cups_needed  # 秒
```

**安全约束：**
- interval < 1800s (30min) → 提示更换大杯子
- interval > 7200s (120min) → 强制修正为 5400s (90min)

### 4.4 提醒弹窗

使用 `PySide6` 创建非模态弹窗：

```
┌─────────────────────────────┐
│ 💧 该喝水啦！               │
├─────────────────────────────┤
│ 海豹需要水，你也需要！      │
│ 喝一口吧~                   │
│                             │
│ [一口干了] [喝了半杯] [稍后]│
└─────────────────────────────┘
```

**响应记录：**
- [一口干了] → `completed`, 记录 100% 杯容量
- [喝了半杯] → `completed`, 记录 50% 杯容量
- [稍后] → `delayed`, 10 分钟后再次提醒

### 4.5 数据持久化

**SQLite Schema：**

```sql
-- 状态切换记录
CREATE TABLE state_transitions (
    id INTEGER PRIMARY KEY,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    from_state TEXT,
    to_state TEXT,
    duration_seconds INT
);

-- 健康提醒记录
CREATE TABLE health_reminders (
    id INTEGER PRIMARY KEY,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    reminder_type TEXT,  -- eye/stretch/water
    focus_duration INT,  -- 专注时长（秒）
    user_response TEXT,  -- completed/delayed/ignored
    response_time INT    -- 响应延迟（秒）
);

-- 饮水记录
CREATE TABLE water_intake (
    id INTEGER PRIMARY KEY,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    volume_ml INT,
    cup_percentage INT  -- 100/50
);
```

### 4.6 默认文案库

每种提醒类型 3-4 条通用文案：

**护眼提醒：**
- "盯屏幕 20 分钟了，看看远处吧~"
- "休息眼睛，保护视力！"
- "远眺 20 秒，让眼睛放松一下"

**拉伸提醒：**
- "坐了 45 分钟，起来动动吧！"
- "拉伸一下，别让身体僵硬"
- "站起来走走，活动活动筋骨"

**补水提醒：**
- "该喝水啦，补充水分！"
- "喝口水，保持身体水分充足"
- "别忘了喝水哦~"

---

## 5. 风险 & 回退

| 风险 | 缓解措施 |
|------|----------|
| transitions 库不稳定 | 手动实现简单状态机 |
| rumps 在新版 macOS 不兼容 | 降级为命令行工具 |
| 计时器精度问题 | 使用 `threading.Timer` 替代 `time.sleep` |

---

## 6. 验收标准

### 功能验收

- [ ] 4 种状态可正常切换，无死锁
- [ ] 护眼提醒每 20 分钟触发（±5 秒）
- [ ] 拉伸提醒每 45 分钟触发（±5 秒）
- [ ] 补水提醒按动态间隔触发
- [ ] 用户点击"已完成"后，数据正确写入 SQLite
- [ ] 专注状态下，所有提醒被屏蔽
- [ ] 暂离状态下，计时器暂停

### 性能验收

- [ ] 待机状态 CPU < 0.5%
- [ ] 工作状态 CPU < 2%
- [ ] 内存占用 < 50 MB

---

## 7. 下一步

完成 v1.1 后，进入 **PRD 1.2 - 桌宠 UI + 形象系统**。
