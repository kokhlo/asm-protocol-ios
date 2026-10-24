import Foundation

enum APIError: Error, LocalizedError, Equatable {
    case badURL
    case transport(String)
    case http(status: Int, body: String)
    case conflict(serverRevision: Int)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .badURL:
            return "некорректный URL"
        case .transport(let message):
            return "сеть недоступна: \(message)"
        case .http(let status, let body):
            let clipped = body.prefix(160)
            return "HTTP \(status): \(clipped)"
        case .conflict(let revision):
            return "409 конфликт ревизий, сервер на \(revision)"
        case .decoding(let message):
            return "ошибка декодирования: \(message)"
        }
    }
}

/// Протокол прогресс-эндпоинтов — для подмены в тестах.
protocol ProgressAPI: Sendable {
    func progress(key: String) async throws -> ProgressDocument?
    func putProgress(key: String, body: PutProgressBody) async throws -> PutProgressResponse
    func deleteProgress(key: String) async throws
}

/// Тонкий клиент живого API ASM://PROTOCOL (https://asm-protocol.tech, TLS на Caddy).
/// Только URLSession + Codable, без сторонних зависимостей.
struct APIClient: ProgressAPI {
    /// Адрес API по умолчанию: build setting `ASM_API_BASE_URL` → ключ Info.plist.
    /// Резерв — прод-адрес, если ключа нет или он не https (ATS включён, http не пройдёт).
    static let defaultBaseURL: URL = {
        if let raw = Bundle.main.object(forInfoDictionaryKey: "ASM_API_BASE_URL") as? String,
           let url = URL(string: raw), url.scheme == "https", url.host != nil {
            return url
        }
        return URL(string: "https://asm-protocol.tech")!
    }()

    let baseURL: URL
    let session: URLSession

    init(baseURL: URL = APIClient.defaultBaseURL,
         session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    // MARK: - Curriculum

    func modules() async throws -> [ModuleSummary] {
        let data = try await get("api/v1/curriculum/modules")
        return try decode(ModulesResponse.self, from: data).modules
    }

    func module(id: String) async throws -> Module {
        let data = try await get("api/v1/curriculum/modules/\(id)")
        return try decode(Module.self, from: data)
    }

    func skills() async throws -> [Skill] {
        let data = try await get("api/v1/curriculum/skills")
        return try decode(SkillsResponse.self, from: data).skills
    }

    // MARK: - Progress

    func progress(key: String) async throws -> ProgressDocument? {
        do {
            let data = try await get("api/v1/progress/\(key)")
            return try decode(ProgressDocument.self, from: data)
        } catch let APIError.http(status, _) where status == 404 {
            return nil // прогресс ещё не заводился
        }
    }

    @discardableResult
    func putProgress(key: String, body: PutProgressBody) async throws -> PutProgressResponse {
        var request = URLRequest(url: try url("api/v1/progress/\(key)"))
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20
        request.httpBody = try JSONEncoder().encode(body)
        let data = try await send(request)
        return try decode(PutProgressResponse.self, from: data)
    }

    func deleteProgress(key: String) async throws {
        var request = URLRequest(url: try url("api/v1/progress/\(key)"))
        request.httpMethod = "DELETE"
        request.timeoutInterval = 20
        _ = try await send(request)
    }

    // MARK: - Внутреннее

    private func url(_ path: String) throws -> URL {
        guard let url = URL(string: baseURL.absoluteString + "/" + path) else {
            throw APIError.badURL
        }
        return url
    }

    private func get(_ path: String) async throws -> Data {
        var request = URLRequest(url: try url(path))
        request.timeoutInterval = 20
        return try await send(request)
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }
        return try Self.checked(data: data, response: response)
    }

    private static func checked(data: Data, response: URLResponse) throws -> Data {
        guard let http = response as? HTTPURLResponse else { return data }
        guard !(200..<300).contains(http.statusCode) else { return data }
        if http.statusCode == 409 {
            let revision = (try? JSONDecoder().decode(PutProgressResponse.self, from: data))?.serverRevision ?? 0
            throw APIError.conflict(serverRevision: revision)
        }
        throw APIError.http(status: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }
}
