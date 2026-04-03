import Foundation

final class GenerationHTTPClient: GenerationTransport, GenerationConnectionTesting {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func testConnection(provider: GenerationProvider, defaults: GenerationProviderDefaultConfig) throws {
        switch provider {
        case .openAI, .openAICompatible:
            let endpoint = try endpointURL(baseURL: defaults.baseURL, path: "models")
            try performStatusRequest(
                url: endpoint,
                headers: defaults.headers,
                auth: defaults.resolvedAuth
            )
        case .anthropic:
            let endpoint = try endpointURL(baseURL: defaults.baseURL, path: "models")
            var headers = defaults.headers
            if headers["anthropic-version"] == nil {
                headers["anthropic-version"] = "2023-06-01"
            }

            var auth = defaults.resolvedAuth
            if auth["x-api-key"] == nil,
               auth["x_api_key"] == nil,
               let apiKey = auth["api_key"],
               !apiKey.isEmpty {
                auth["x-api-key"] = apiKey
                auth["api_key"] = nil
            }

            try performStatusRequest(
                url: endpoint,
                headers: headers,
                auth: auth
            )
        case .ollama:
            let endpoint = try endpointURL(baseURL: defaults.baseURL, path: "api/tags")
            try performStatusRequest(
                url: endpoint,
                headers: defaults.headers,
                auth: defaults.resolvedAuth
            )
        case .huggingFace:
            let endpoint = try endpointURL(baseURL: defaults.baseURL, path: "")
            try performStatusRequest(
                url: endpoint,
                headers: defaults.headers,
                auth: defaults.resolvedAuth,
                acceptedStatusCodes: 200 ... 499
            )
        }
    }

    func completeJSON(prompt: String, capability: GenerationCapabilityConfig) throws -> String {
        switch capability.provider {
        case .ollama:
            return try callOllama(prompt: prompt, capability: capability)
        case .openAI:
            return try callOpenAICompatible(prompt: prompt, capability: capability)
        case .openAICompatible:
            return try callOpenAICompatible(prompt: prompt, capability: capability)
        case .anthropic:
            return try callAnthropic(prompt: prompt, capability: capability)
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
            headers: capability.headers,
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
            headers: capability.headers,
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

    private func callAnthropic(prompt: String, capability: GenerationCapabilityConfig) throws -> String {
        let endpoint = try endpointURL(baseURL: capability.baseURL, path: "messages")
        var payload: [String: Any] = [
            "model": capability.model,
            "messages": [
                ["role": "user", "content": prompt],
            ],
            "max_tokens": 1024,
        ]
        for (key, value) in capability.options {
            payload[key] = value
        }

        var headers = capability.headers
        if headers["anthropic-version"] == nil {
            headers["anthropic-version"] = "2023-06-01"
        }

        var auth = capability.auth
        if auth["x-api-key"] == nil,
           auth["x_api_key"] == nil,
           let apiKey = auth["api_key"],
           !apiKey.isEmpty {
            auth["x-api-key"] = apiKey
            // Native Anthropic uses x-api-key and should not duplicate the same
            // credential as Authorization: Bearer <api_key>.
            auth["api_key"] = nil
        }

        let json = try performJSONRequest(
            url: endpoint,
            payload: payload,
            headers: headers,
            auth: auth
        )

        if let providerError = extractProviderError(from: json) {
            throw GenerationRouteError.providerReturnedError(providerError)
        }

        if let contentItems = json["content"] as? [[String: Any]] {
            for item in contentItems {
                if let content = item["text"] as? String,
                   !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return content
                }
            }
        }

        throw GenerationRouteError.responseMissingContent("anthropic response field 'content[0].text'")
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
        headers: [String: String] = [:],
        auth: [String: String]
    ) throws -> [String: Any] {
        var request = URLRequest(url: url, timeoutInterval: 60)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
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

    private func performStatusRequest(
        url: URL,
        method: String = "GET",
        headers: [String: String] = [:],
        auth: [String: String],
        acceptedStatusCodes: ClosedRange<Int> = 200 ... 299
    ) throws {
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
        applyAuth(auth, to: &request)

        let (data, response) = try perform(request)
        guard acceptedStatusCodes.contains(response.statusCode) else {
            let message = extractProviderError(from: data) ?? "HTTP \(response.statusCode)"
            throw GenerationRouteError.requestFailed("HTTP \(response.statusCode): \(message)")
        }
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
