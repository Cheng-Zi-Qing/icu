# I.C.U. 编码规范

## 1. 函数注释规范

所有函数必须包含文档字符串（docstring），说明功能、参数和返回值。

### 格式

```python
def function_name(param1, param2):
    """
    函数功能简述

    Args:
        param1: 参数1说明（中文）
        param2: 参数2说明（中文）

    Returns:
        返回值说明（中文）
    """
    pass
```

## 2. 重要参数中文注释

关键参数、配置项必须用中文注释说明用途。

```python
body_weight = 70  # 体重（kg）
cup_volume = 300  # 杯子容量（ml）
```

## 3. API 模块化

所有外部 API 调用必须抽取到独立模块 `src/api/`，便于维护和测试。

### 目录结构

```
src/api/
├── __init__.py
├── openai_api.py    # OpenAI API
├── ollama_api.py    # Ollama API
└── replicate_api.py # Replicate API
```

## 4. 代码组织

- 一个文件一个类/模块
- 文件名使用小写下划线
- 类名使用大驼峰
- 函数名使用小写下划线

## 5. 错误处理

所有外部调用必须有错误处理和降级方案。

```python
try:
    result = api_call()
except Exception as e:
    logger.error(f"API 调用失败: {e}")
    result = fallback_value
```
