#!/usr/bin/env python3
"""I.C.U. 资源监控工具"""
import subprocess
import sys


def get_icu_processes():
    """获取 I.C.U. 相关进程"""
    try:
        # 先用 top 获取所有 Python 进程
        result = subprocess.run(
            ["top", "-l", "1", "-stats", "pid,command,cpu,mem"],
            capture_output=True,
            text=True
        )
        python_pids = []
        for line in result.stdout.split('\n'):
            if 'Python' in line:
                parts = line.split()
                if parts:
                    python_pids.append(parts[0])

        # 用 ps 检查哪些是 I.C.U. 进程
        if not python_pids:
            return []

        ps_result = subprocess.run(
            ["ps", "-p", ",".join(python_pids), "-o", "pid,command"],
            capture_output=True,
            text=True
        )

        icu_pids = []
        for line in ps_result.stdout.split('\n'):
            if 'src' in line or 'pet_main' in line or '__main__' in line:
                parts = line.split()
                if parts:
                    icu_pids.append(parts[0])

        # 获取资源信息
        processes = []
        for line in result.stdout.split('\n'):
            if 'Python' in line:
                parts = line.split()
                if parts and parts[0] in icu_pids:
                    processes.append({
                        'pid': parts[0],
                        'cpu': parts[2],
                        'mem': parts[3]
                    })
        return processes
    except Exception as e:
        print(f"错误: {e}")
        return []


def get_process_details(pids):
    """获取进程详细信息"""
    if not pids:
        return []

    try:
        pid_str = ','.join(pids)
        result = subprocess.run(
            ["ps", "-p", pid_str, "-o", "pid,ppid,%cpu,%mem,vsz,rss,comm"],
            capture_output=True,
            text=True
        )
        return result.stdout
    except Exception as e:
        print(f"错误: {e}")
        return ""


def main():
    print("=== I.C.U. 资源消耗报告 ===\n")

    processes = get_icu_processes()

    if not processes:
        print("未检测到运行中的 I.C.U. 进程")
        sys.exit(1)

    pids = [p['pid'] for p in processes]
    details = get_process_details(pids)

    print("进程详情:")
    print(details)

    total_cpu = sum(float(p['cpu']) for p in processes)
    total_mem = sum(float(p['mem'].rstrip('M')) for p in processes if 'M' in p['mem'])

    print(f"\n总计:")
    print(f"  CPU: {total_cpu:.1f}%")
    print(f"  物理内存: ~{int(total_mem)} MB")
    print(f"\n评估:")
    print(f"  {'✓' if total_cpu < 5 else '⚠'} CPU 占用{'极低' if total_cpu < 2 else '正常' if total_cpu < 5 else '偏高'} ({total_cpu:.1f}%)")
    print(f"  {'✓' if total_mem < 300 else '⚠'} 内存占用{'合理' if total_mem < 300 else '偏高'} ({int(total_mem)}MB)")


if __name__ == '__main__':
    main()
