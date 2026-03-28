import Foundation

struct BridgeImageModel: Codable, Equatable {
    var name: String
    var url: String
    var token: String
}

enum AvatarBuilderBridgeError: Error, LocalizedError {
    case executionFailed(command: String, details: String)
    case invalidResponse(command: String)

    var errorDescription: String? {
        switch self {
        case let .executionFailed(command, details):
            return "\(TextCatalog.shared.text(.errorBridgeCommandFailedPrefix)) '\(command)': \(details)"
        case let .invalidResponse(command):
            return "\(TextCatalog.shared.text(.errorBridgeInvalidResponse)) '\(command)'"
        }
    }
}

struct AvatarBuilderBridge {
    let scriptURL: URL
    let runnerURL: URL
    let environment: [String: String]

    init(
        scriptURL: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("tools", isDirectory: true)
            .appendingPathComponent("avatar_builder_bridge.py", isDirectory: false),
        runnerURL: URL = URL(fileURLWithPath: "/usr/bin/env", isDirectory: false),
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.scriptURL = scriptURL
        self.runnerURL = runnerURL
        self.environment = environment
    }

    func optimizePrompt(_ text: String) throws -> String {
        let response: OptimizePromptResponse = try run(
            command: "optimize-prompt",
            arguments: ["--text", text]
        )
        return response.prompt
    }

    func listImageModels(repoRootURL: URL? = nil) throws -> [BridgeImageModel] {
        let response: ListImageModelsResponse = try run(
            command: "list-image-models",
            arguments: repoRootURL.map { ["--repo-root", $0.path] } ?? []
        )
        return response.models
    }

    func generateImage(
        prompt: String,
        model: BridgeImageModel,
        sessionID: String
    ) throws -> URL {
        let response: GenerateImageResponse = try run(
            command: "generate-image",
            arguments: [
                "--prompt", prompt,
                "--model-url", model.url,
                "--token", model.token,
                "--session-id", sessionID,
            ]
        )
        return URL(fileURLWithPath: response.path, isDirectory: false)
    }

    func generatePersona(_ text: String) throws -> String {
        let response: GeneratePersonaResponse = try run(
            command: "generate-persona",
            arguments: ["--text", text]
        )
        return response.persona
    }

    private func run<Response: Decodable>(
        command: String,
        arguments: [String]
    ) throws -> Response {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()

        process.executableURL = runnerURL
        process.arguments = ["python3", scriptURL.path, command] + arguments
        process.environment = environment
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
        let stderrText = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let stdoutText = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard process.terminationStatus == 0 else {
            let details = stderrText.isEmpty ? stdoutText : stderrText
            throw AvatarBuilderBridgeError.executionFailed(command: command, details: details)
        }

        guard !outputData.isEmpty else {
            throw AvatarBuilderBridgeError.invalidResponse(command: command)
        }

        do {
            return try JSONDecoder().decode(Response.self, from: outputData)
        } catch {
            throw AvatarBuilderBridgeError.invalidResponse(command: command)
        }
    }
}

private struct OptimizePromptResponse: Codable {
    var prompt: String
}

private struct ListImageModelsResponse: Codable {
    var models: [BridgeImageModel]
}

private struct GenerateImageResponse: Codable {
    var path: String
}

private struct GeneratePersonaResponse: Codable {
    var persona: String
}
