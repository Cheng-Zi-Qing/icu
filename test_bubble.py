"""测试气泡提示"""
import json
import time

# 模拟提醒触发
state = {
    'state': 'working',
    'timestamp': int(time.time())
}

with open('data/current_state.json', 'w') as f:
    json.dump(state, f)

print("已设置为工作状态，等待提醒触发...")
