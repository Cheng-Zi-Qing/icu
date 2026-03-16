"""状态同步模块"""
import json
import os
from pathlib import Path
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler


class StateSync:
    """状态同步管理器"""

    def __init__(self, state_file='data/current_state.json'):
        self.state_file = Path(state_file)
        self.state_file.parent.mkdir(parents=True, exist_ok=True)
        self.observer = None

    def write_state(self, state, metadata=None):
        """写入状态到文件"""
        import time
        data = {
            'state': state,
            'timestamp': int(time.time()),
            **(metadata or {})
        }
        with open(self.state_file, 'w') as f:
            json.dump(data, f, indent=2)

    def read_state(self):
        """读取当前状态"""
        if not self.state_file.exists():
            return None
        with open(self.state_file, 'r') as f:
            return json.load(f)

    def watch_state(self, callback):
        """监听状态变化"""
        state_file = self.state_file

        class StateChangeHandler(FileSystemEventHandler):
            def on_modified(self, event):
                if event.src_path.endswith('current_state.json'):
                    callback(StateSync(state_file).read_state())

        self.observer = Observer()
        self.observer.schedule(StateChangeHandler(), str(self.state_file.parent), recursive=False)
        self.observer.start()

    def stop_watch(self):
        """停止监听"""
        if self.observer:
            self.observer.stop()
            self.observer.join()
