import Foundation

final class GenerationHTTPClient: GenerationTransport {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func completeJSON(prompt: String, capability: GenerationCapabilityConfig) throws -> String {
        switch capability.provider {
        case .ollama:
            return try callOllama(prompt: prompt, capability: capability)
        case .openAICompatible:
            return try callOpenAICompatible(prompt: prompt, capability: capability)
        case .huggingFace:
            throw GenerationRouteError.unsupportedProviderForTheme(capability.provider)
        }
    }

    private func callOllama(prompt: String, capability: GenerationCapabilityConfig) throws -> String {
        let endpoint = try endpointURL(baseURL: capability.baseURL, path: "api/generate")
        var payload: [String: Any] = [
            "model": capability.model,
            "prompt": prompt,
            "stream": false,
            "format": "json",
        ]
        if !capability.options.isEmpty {
            payload["options"] = capability.options
        }

        let json = try performJSONRequest(
            url: endpoint,
            payload: payload,
            auth: capability.auth
        )

        if let providerError = extractProviderError(from: json) {
            throw GenerationRouteError.providerReturnedError(providerError)
        }

        if let content = json["response"] as? String,
           !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return content
        }

        if let message = json["message"] as? [String: Any],
           let content = message["content"] as? String,
           !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return content
        }

        throw GenerationRouteError.responseMissingContent("ollama response field 'response'")
    }

    private func callOpenAICompatible(prompt: String, capability: GenerationCapabilityConfig) throws -> String {
        let endpoint = try endpointURL(baseURL: capability.baseURL, path: "chat/completions")
        var payload: [String: Any] = [
            "model": capability.model,
            "messages": [
                ["role": "system", "content": "Return valid JSON only."],
                ["role": "user", "content": prompt],
            ],
            "response_format": [
                "type": "json_object",
            ],
        ]
        for (key, value) in capability.options {
            payload[key] = value
        }
        if payload["temperature"] == nil {
            payload["temperature"] = 0.2
        }

        let json = try performJSONRequest(
            url: endpoint,
            payload: payload,
            auth: capability.auth
        )

        if let providerError = extractProviderError(from: json) {
            throw GenerationRouteError.providerReturnedError(providerError)
        }

        if let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first {
            if let message = firstChoice["message"] as? [String: Any],
               let content = message["content"] as? String,
               !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return content
            }
            if let content = firstChoice["text"] as? String,
               !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return content
            }
        }

        throw GenerationRouteError.responseMissingContent("openai-compatible response field 'choices[0].message.content'")
    }

    private func endpointURL(baseURL: String, path: String) throws -> URL {
        let trimmedBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let base = URL(string: trimmedBaseURL) else {
            throw GenerationRouteError.invalidBaseURL(baseURL)
        }

        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            throw GenerationRouteError.invalidBaseURL(baseURL)
        }

        let normalizedPath = "/" + path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if components.path.isEmpty || components.path == "/" {
            components.path = normalizedPath
        } else {
            let basePath = components.path.hasSuffix("/") ? String(components.path.dropLast()) : components.path
            components.path = basePath + normalizedPath
        }

        guard let resolvedURL = components.url else {
            throw GenerationRouteError.invalidBaseURL(baseURL)
        }
        return resolvedURL
    }

    private func performJSONRequest(
        url: URL,
        payload: [String: Any],
        auth: [String: String]
    ) throws -> [String: Any] {
        var request = URLRequest(url: url, timeoutInterval: 60)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        applyAuth(auth, to: &request)

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        } catch {
            throw GenerationRouteError.invalidResponse("unable to encode request payload")
        }

        let (data, response) = try perform(request)
        guard (200...299).contains(response.statusCode) else {
            let message = extractProviderError(from: data) ?? "HTTP \(response.statusCode)"
            throw GenerationRouteError.requestFailed("HTTP \(response.statusCode): \(message)")
        }

        let object: [String: Any]
        do {
            let parsed = try JSONSerialization.jsonObject(with: data, options: [])
            guard let dictionary = parsed as? [String: Any] else {
                throw GenerationRouteError.invalidResponse("response root is not a JSON object")
            }
            object = dictionary
        } catch let routeError as GenerationRouteError {
            throw routeError
        } catch {
            throw GenerationRouteError.invalidResponse(error.localizedDescription)
        }
        return object
    }

    private func perform(_ request: URLRequest) throws -> (Data, HTTPURLResponse) {
        let semaphore = DispatchSemaphore(value: 0)
        var responseData: Data?
        var responseObject: URLResponse?
        var responseError: Error?

        session.dataTask(with: request) { data, response, error in
            responseData = data
            responseObject = response
            responseError = error
            semaphore.signal()
        }.resume()

        semaphore.wait()

        if let responseError {
            throw GenerationRouteError.requestFailed(responseError.localizedDescription)
        }

        guard let httpResponse = responseObject as? HTTPURLResponse else {
            throw GenerationRouteError.invalidResponse("missing HTTP response")
        }
        return (responseData ?? Data(), httpResponse)
    }

    private func applyAuth(_ auth: [String: String], to request: inout URLRequest) {
        if let authorization = auth["authorization"], !authorization.isEmpty {
            request.setValue(authorization, forHTTPHeaderField: "Authorization")
        } else if let apiKey = auth["api_key"], !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        } else if let token = auth["token"], !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let xAPIKey = auth["x-api-key"] ?? auth["x_api_key"], !xAPIKey.isEmpty {
            request.setValue(xAPIKey, forHTTPHeaderField: "x-api-key")
        }
    }

    private func extractProviderError(from object: [String: Any]) -> String? {
        if let message = object["error"] as? String, !message.isEmpty {
            return message
        }
        if let errorObject = object["error"] as? [String: Any] {
            if let message = errorObject["message"] as? String, !message.isEmpty {
                return message
            }
            if let details = errorObject["details"] as? String, !details.isEmpty {
                return details
            }
        }
        return nil
    }

    private func extractProviderError(from data: Data) -> String? {
        if let object = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
           let providerError = extractProviderError(from: object) {
            return providerError
        }

        let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let text, !text.isEmpty {
            return text
        }
        return nil
    }
}
