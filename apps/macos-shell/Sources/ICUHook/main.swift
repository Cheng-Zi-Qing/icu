import Foundation

// icu-hook：Claude Code 每个钩子事件都会调用它（异步，不拖慢 Claude）。
//
// 规矩：永远退出 0、什么都不输出。Stop 上退出 2 会让 Claude 停不下来，
// UserPromptSubmit / SessionStart 上的输出会被塞进对话。出了错也只能默默放弃。
//
// 记录写到 `<安装目录>/../agents/`（装在 ~/Library/Application Support/ICU/bin/ 下时
// 就是 ICU/agents/）；也可以用 `--dir <目录>` 指定。

func agentsDirectory(arguments: [String]) -> URL {
    if let index = arguments.firstIndex(of: "--dir"), arguments.indices.contains(index + 1) {
        return URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
    }
    let binary = URL(fileURLWithPath: arguments.first ?? "").resolvingSymlinksInPath()
    return binary.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("agents", isDirectory: true)
}

let input = FileHandle.standardInput.readDataToEndOfFile()
if let event = AgentHookEvent(stdin: input, environment: ProcessInfo.processInfo.environment, now: Date()) {
    try? AgentHookWriter.apply(event, in: agentsDirectory(arguments: CommandLine.arguments))
}
exit(0)
