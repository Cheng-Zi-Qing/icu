# AI 分层架构设计

## 一、分层原则

### 隐私分级

| 数据类型 | 敏感度 | 推荐方案 |
|---------|--------|---------|
| **形象生成** | 低（仅 Prompt） | ✅ 云端优先 |
| **文案生成（简单）** | 低（无上下文） | ✅ 云端/本地均可 |
| **文案生成（上下文）** | 高（代码/剪贴板） | ⚠️ 仅本地 |

---

## 二、分层架构

### Layer 1: 形象生成（云端多模态）

**场景**: 用户创建新形象

**数据流**:
```
用户输入 Prompt
    ↓
云端 API (DALL-E 3 / Midjourney)
    ↓
返回图像 URL
    ↓
下载到本地 assets/pets/
```

**隐私评估**:
- ✅ 仅上传用户主动输入的 Prompt
- ✅ 不涉及工作内容
- ✅ 可选择不使用（手动上传图片）

**API 选择**:
```python
IMAGE_GENERATION_APIS = {
    'openai': {
        'model': 'dall-e-3',
        'endpoint': 'https://api.openai.com/v1/images/generations',
        'cost': '$0.04/image'
    },
    'replicate': {
        'model': 'stability-ai/sdxl',
        'endpoint': 'https://api.replicate.com/v1/predictions',
        'cost': '$0.002/image'
    }
}
```

---

### Layer 2: 文案生成（云端 + 本地双模式）

#### Mode A: 简单模式（云端/本地均可）

**场景**: 基础提醒，无敏感上下文

**Prompt 示例**:
```python
system_prompt = f"""
你是 {pet_name}，性格：{traits}，语气：{tone}。
用户工作了 {duration} 分钟，请提醒 TA {reminder_type}。
要求：1 句话，不超过 30 字。
"""
```

**数据流**:
```
基础上下文（工作时长、提醒类型）
    ↓
用户选择：云端 API / 本地 Ollama
    ↓
返回文案
```

**隐私评估**:
- ✅ 仅上传时长、提醒类型等非敏感信息
- ✅ 用户可选择本地模式

#### Mode B: 高级模式（仅本地）

**场景**: 上下文感知提醒

**Prompt 示例**:
```python
system_prompt = f"""
你是 {pet_name}，性格：{traits}，语气：{tone}。
禁止使用 AI 常用套话。

[Context]
- 当前应用：{active_app}
- 剪贴板类型：{clipboard_type}  # 仅类型，不传内容
- 键盘活动：{typing_activity}
- 工作时长：{duration} 分钟

请提醒用户 {reminder_type}，1 句话，不超过 30 字。
"""
```

**数据流**:
```
敏感上下文（应用名、剪贴板类型）
    ↓
强制本地 Ollama
    ↓
返回文案 + emotion_state
```

**隐私评估**:
- ✅ 敏感数据不离开本地
- ✅ 剪贴板仅传类型，不传内容

---

## 三、配置界面设计

### AI 设置 Tab

```
┌────────────────────────────────────────┐
│  AI 配置                               │
├────────────────────────────────────────┤
│                                        │
│  ━━━ 形象生成 ━━━                     │
│                                        │
│  ○ 使用云端 API（推荐）                │
│     [OpenAI DALL-E 3  ▼]              │
│     API Key: [••••••••••••]           │
│                                        │
│  ○ 手动上传图片                        │
│                                        │
│  ━━━ 文案生成 ━━━                     │
│                                        │
│  模式选择：                            │
│  ○ 简单模式（云端/本地均可）           │
│  ○ 高级模式（仅本地，上下文感知）      │
│                                        │
│  【简单模式配置】                      │
│  ○ 云端 API                           │
│     [OpenAI GPT-4o    ▼]              │
│     API Key: [••••••••••••]           │
│                                        │
│  ○ 本地 Ollama                        │
│     模型: [qwen2.5:7b  ▼]             │
│     URL: [http://localhost:11434]     │
│                                        │
│  【高级模式配置】                      │
│  ☑ 启用上下文感知（仅本地）            │
│     模型: [qwen2.5:7b  ▼]             │
│     URL: [http://localhost:11434]     │
│                                        │
│  超时时间: [3] 秒                      │
│                                        │
│  [测试连接] [保存]                     │
│                                        │
└────────────────────────────────────────┘
```

---

## 四、实现代码

### 配置文件结构

```json
{
  "ai_config": {
    "image_generation": {
      "enabled": true,
      "provider": "openai",
      "api_key": "sk-xxx",
      "model": "dall-e-3"
    },
    "text_generation": {
      "mode": "advanced",
      "simple_mode": {
        "provider": "ollama",
        "api_key": "",
        "model": "qwen2.5:7b",
        "ollama_url": "http://localhost:11434"
      },
      "advanced_mode": {
        "enabled": true,
        "ollama_url": "http://localhost:11434",
        "model": "qwen2.5:7b"
      },
      "timeout": 3
    }
  }
}
```

### AI 服务层

```python
class AIService:
    """AI 服务分层管理"""

    def generate_image(self, prompt: str) -> str:
        """形象生成（云端）"""
        config = self.config['image_generation']

        if not config['enabled']:
            raise AIDisabledError("请手动上传图片")

        if config['provider'] == 'openai':
            return self._call_openai_image(prompt, config)
        elif config['provider'] == 'replicate':
            return self._call_replicate_image(prompt, config)

    def generate_text(self, context: dict) -> tuple[str, str]:
        """文案生成（分层）"""
        config = self.config['text_generation']

        # 高级模式：强制本地
        if config['mode'] == 'advanced':
            return self._generate_advanced_local(context)

        # 简单模式：云端/本地可选
        else:
            return self._generate_simple(context, config['simple_mode'])

    def _generate_advanced_local(self, context: dict) -> tuple[str, str]:
        """高级模式：仅本地 Ollama"""
        config = self.config['text_generation']['advanced_mode']

        if not config['enabled']:
            # 降级到固定话术
            return self._get_fallback_message(context), 'idle'

        # 构建上下文感知 Prompt
        prompt = self._build_context_aware_prompt(context)

        try:
            response = self._call_ollama(prompt, config)
            result = json.loads(response)
            return result['dialogue'], result.get('emotion_state', 'idle')
        except Exception as e:
            logger.warning(f"Ollama failed: {e}")
            return self._get_fallback_message(context), 'idle'

    def _generate_simple(self, context: dict, config: dict) -> tuple[str, str]:
        """简单模式：云端/本地可选"""
        prompt = self._build_simple_prompt(context)

        try:
            if config['provider'] == 'openai':
                return self._call_openai_text(prompt, config), 'idle'
            elif config['provider'] == 'ollama':
                return self._call_ollama(prompt, config), 'idle'
        except Exception as e:
            logger.warning(f"AI failed: {e}")
            return self._get_fallback_message(context), 'idle'
```

---

## 五、用户选择建议

### 推荐配置

**极客用户（隐私优先）**:
```
形象生成：云端（仅 Prompt，无隐私风险）
文案生成：高级模式 + 本地 Ollama
```

**普通用户（便捷优先）**:
```
形象生成：云端
文案生成：简单模式 + 云端 API
```

**离线用户**:
```
形象生成：手动上传
文案生成：固定话术库
```

---

## 六、成本对比

### 云端 API 成本

| 服务 | 用途 | 成本 | 频率 |
|------|------|------|------|
| DALL-E 3 | 形象生成 | $0.04/次 | 低（用户主动） |
| GPT-4o | 文案生成 | $0.0025/次 | 高（每 20-45 分钟） |

**月成本估算**（工作日 8 小时）:
- 形象生成：$0.04 × 5 次 = $0.2
- 文案生成：$0.0025 × 20 次/天 × 22 天 = $1.1
- **总计**: ~$1.3/月

### 本地 Ollama 成本

- 硬件要求：16GB RAM（qwen2.5:7b）
- 电费：可忽略
- **总计**: $0/月

---

## 七、优势总结

### 分层架构优势

1. **灵活性** - 用户可根据需求选择
2. **隐私保护** - 敏感数据强制本地
3. **成本可控** - 可选择免费本地方案
4. **降级保证** - 任何模式失败都有兜底

### 与竞品对比

| 项目 | 形象生成 | 文案生成 | 隐私保护 |
|------|---------|---------|---------|
| BongoCat | ❌ 无 | ❌ 无 | N/A |
| I.C.U. | ✅ 云端 | ✅ 云端/本地 | ✅ 分层 |

---

**结论**: 分层架构既保证了灵活性，又保护了隐私，是最佳方案。
