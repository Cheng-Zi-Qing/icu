"""
State Machine Module
实现 FSM 核心逻辑
"""

from transitions import Machine

class HealthStateMachine:
    """健康状态机"""

    states = ['idle', 'working', 'focus', 'break']

    def __init__(self):
        self.machine = Machine(
            model=self,
            states=HealthStateMachine.states,
            initial='idle'
        )
