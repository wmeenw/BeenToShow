import Foundation

// MARK: - Ошибки

nonisolated enum BackendError: LocalizedError, Equatable {
    case invalidNick(String)
    case weakPassword
    case nickTaken
    case wrongCredentials
    case noNetwork
    case notSignedIn
    case sessionExpired
    case notSetUp
    case accessDenied
    case server(status: Int, message: String)

    /// Повтор не поможет: сервер отклонил именно эти данные (права, размер, формат).
    var isPermanent: Bool {
        switch self {
        case .accessDenied: return true
        case .server(let status, _): return [400, 413, 422].contains(status)
        default: return false
        }
    }

    var errorDescription: String? {
        switch self {
        case .invalidNick(let reason): return reason
        case .weakPassword: return "Пароль слишком короткий: нужно минимум 6 символов"
        case .nickTaken: return "Этот ник уже занят, попробуй другой"
        case .wrongCredentials: return "Неверный ник или пароль"
        case .noNetwork: return "Нет соединения с интернетом. Проверь сеть и попробуй ещё раз"
        case .notSignedIn: return "Нужно войти в аккаунт"
        case .sessionExpired: return "Сессия истекла, войди снова"
        case .notSetUp: return "Сервер ещё не настроен (нет таблиц или прав доступа)"
        case .accessDenied: return "Сервер отклонил изменение: нет доступа к этим данным"
        case .server(let status, let message): return "Ошибка сервера (\(status)): \(message)"
        }
    }
}

// MARK: - Ник -> email

nonisolated enum Nickname {
    static let domain = "beentoshow.app"
    static let minLength = 3
    static let maxLength = 20
    static let minPasswordLength = 6

    /// Приводит ник к нижнему регистру и проверяет формат: 3-20 символов, a-z 0-9 _ . -
    static func normalize(_ raw: String) throws -> String {
        let nick = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard nick.count >= minLength else {
            throw BackendError.invalidNick("Ник слишком короткий: минимум \(minLength) символа")
        }
        guard nick.count <= maxLength else {
            throw BackendError.invalidNick("Ник слишком длинный: максимум \(maxLength) символов")
        }
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789_.-")
        guard nick.allSatisfy({ allowed.contains($0) }) else {
            throw BackendError.invalidNick("В нике можно использовать только латинские буквы, цифры и символы _ . -")
        }
        guard !nick.hasPrefix("."), !nick.hasSuffix("."), !nick.contains("..") else {
            throw BackendError.invalidNick("Ник не может начинаться или заканчиваться точкой и содержать две точки подряд")
        }
        return nick
    }

    static func email(for nick: String) throws -> String {
        try normalize(nick) + "@" + domain
    }

    static func nick(fromEmail email: String) -> String {
        String(email.split(separator: "@").first ?? "")
    }
}

/// Имена файлов приходят с сервера и из резервных копий: пускаем только простое имя без путей.
nonisolated enum MediaName {
    static func isSafe(_ name: String) -> Bool {
        !name.isEmpty && name.count <= 255 && name == (name as NSString).lastPathComponent
            && !name.contains("/") && !name.contains("\\") && !name.contains("..") && name != "."
            && !name.contains("\0")
    }
}

// MARK: - Удалённые данные

nonisolated struct RemoteConcert: Sendable {
    let id: UUID
    /// JSON закодированного Concert.
    let data: Data
    let updatedAt: Date
    /// Надгробие: концерт удалён (строка остаётся, чтобы удаление дошло до других устройств).
    var isDeleted = false
}

nonisolated enum SupabaseDate {
    private static func make(_ fractional: Bool) -> ISO8601DateFormatter {
        let f = ISO8601DateFormatter()
        f.formatOptions = fractional ? [.withInternetDateTime, .withFractionalSeconds] : [.withInternetDateTime]
        return f
    }

    static func string(_ date: Date) -> String { make(true).string(from: date) }

    static func parse(_ string: String) -> Date? {
        make(true).date(from: string) ?? make(false).date(from: string)
    }
}

// MARK: - Клиент

/// Тонкий клиент Supabase поверх URLSession (Auth, PostgREST, Storage). Хранит сессию и сам её обновляет.
actor SupabaseClient {
    static let shared = SupabaseClient()

    static let baseURL = URL(string: Secrets.supabaseURL)!
    /// Публичный (publishable) ключ - по задумке его можно держать в приложении.
    static let publishableKey = Secrets.supabasePublishableKey

    private let urlSession: URLSession
    private var session: AuthSession?
    private var refreshTask: Task<AuthSession, Error>?
    /// Вызывается, когда сессия пропала сама (refresh-токен отозван), а не по явному выходу.
    private var onSessionLost: (@Sendable () async -> Void)?

    init(urlSession: URLSession = .shared, restoreFromKeychain: Bool = true) {
        self.urlSession = urlSession
        if restoreFromKeychain { session = Keychain.loadSession() }
    }

    var currentSession: AuthSession? { session }

    func setSessionLostHandler(_ handler: @escaping @Sendable () async -> Void) {
        onSessionLost = handler
    }

    // MARK: Auth

    func signUp(nick: String, password: String, displayName: String) async throws -> AuthSession {
        let email = try Nickname.email(for: nick)
        guard password.count >= Nickname.minPasswordLength else { throw BackendError.weakPassword }
        let body: [String: Any] = [
            "email": email,
            "password": password,
            "data": ["display_name": displayName, "nick": try Nickname.normalize(nick)]
        ]
        let (data, status) = try await raw(path: "/auth/v1/signup", method: "POST", json: body)
        guard (200..<300).contains(status) else { throw Self.authError(status: status, data: data) }
        // Если подтверждение почты включено, сессии в ответе не будет.
        guard let s = Self.parseSession(data, fallbackNick: try Nickname.normalize(nick)) else {
            throw BackendError.server(status: status, message: "Сервер не вернул сессию (проверь, что подтверждение почты отключено)")
        }
        setSession(s)
        return s
    }

    func signIn(nick: String, password: String) async throws -> AuthSession {
        let email = try Nickname.email(for: nick)
        let (data, status) = try await raw(
            path: "/auth/v1/token", query: [URLQueryItem(name: "grant_type", value: "password")],
            method: "POST", json: ["email": email, "password": password])
        guard (200..<300).contains(status) else { throw Self.authError(status: status, data: data) }
        guard let s = Self.parseSession(data, fallbackNick: try Nickname.normalize(nick)) else {
            throw BackendError.server(status: status, message: "Некорректный ответ сервера")
        }
        setSession(s)
        return s
    }

    /// Обновляет токен. Параллельные вызовы объединяются в один запрос.
    @discardableResult
    func refresh() async throws -> AuthSession {
        if let task = refreshTask { return try await task.value }
        guard let current = session else { throw BackendError.notSignedIn }
        let task = Task { try await self.performRefresh(current) }
        refreshTask = task
        defer { if refreshTask == task { refreshTask = nil } }
        return try await task.value
    }

    private func performRefresh(_ current: AuthSession) async throws -> AuthSession {
        let (data, status) = try await raw(
            path: "/auth/v1/token", query: [URLQueryItem(name: "grant_type", value: "refresh_token")],
            method: "POST", json: ["refresh_token": current.refreshToken])
        // Пока шёл запрос, могли выйти или войти заново: результат устарел, ничего не трогаем.
        guard session?.refreshToken == current.refreshToken else { throw BackendError.notSignedIn }
        if (200..<300).contains(status), let s = Self.parseSession(data, fallbackNick: current.nick) {
            setSession(s)
            return s
        }
        if status == 400 || status == 401 || status == 403 {
            // Refresh-токен недействителен: сессии больше нет.
            setSession(nil)
            if let handler = onSessionLost { Task { await handler() } }
            throw BackendError.sessionExpired
        }
        throw BackendError.server(status: status, message: Self.message(from: data))
    }

    /// Выход: отменяет обновление токена, локально забывает сессию и по возможности отзывает её на сервере.
    func signOut() {
        refreshTask?.cancel()
        refreshTask = nil
        let token = session?.accessToken
        setSession(nil)
        guard let token else { return }
        var request = makeRequest(path: "/auth/v1/logout", query: [URLQueryItem(name: "scope", value: "local")],
                                  method: "POST", token: token)
        request.timeoutInterval = 10
        let urlSession = self.urlSession
        let logout = request
        Task.detached { _ = try? await urlSession.data(for: logout) }
    }

    private func setSession(_ s: AuthSession?) {
        session = s
        if let s { Keychain.saveSession(s) } else { Keychain.deleteSession() }
    }

    private func validSession() async throws -> AuthSession {
        guard let s = session else { throw BackendError.notSignedIn }
        if s.expiresAt.timeIntervalSinceNow < 60 { return try await refresh() }
        return s
    }

    // MARK: Concerts (PostgREST)

    func upsertConcert(id: UUID, data: Data, updatedAt: Date) async throws {
        let obj = try JSONSerialization.jsonObject(with: data)
        let row: [String: Any] = ["id": id.uuidString, "data": obj, "updated_at": SupabaseDate.string(updatedAt)]
        _ = try await authed(
            path: "/rest/v1/concerts", query: [URLQueryItem(name: "on_conflict", value: "id")],
            method: "POST", json: [row], headers: ["Prefer": "resolution=merge-duplicates,return=minimal"])
    }

    func fetchConcerts() async throws -> [RemoteConcert] {
        let pageSize = 1000
        var result: [RemoteConcert] = []
        var offset = 0
        while true {
            let data = try await authed(
                path: "/rest/v1/concerts",
                query: [URLQueryItem(name: "select", value: "id,data,updated_at"),
                        URLQueryItem(name: "order", value: "id"),
                        URLQueryItem(name: "limit", value: String(pageSize)),
                        URLQueryItem(name: "offset", value: String(offset))], method: "GET")
            guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { break }
            for row in rows {
                guard let idString = row["id"] as? String, let id = UUID(uuidString: idString) else { continue }
                guard let obj = row["data"], JSONSerialization.isValidJSONObject(obj),
                      let json = try? JSONSerialization.data(withJSONObject: obj),
                      let dateString = row["updated_at"] as? String,
                      let date = SupabaseDate.parse(dateString) else {
                    // Строку не разобрать: отдаём пустой «пенёк», чтобы локальную копию не слали поверх неё.
                    result.append(RemoteConcert(id: id, data: Data(), updatedAt: .distantPast))
                    continue
                }
                let deleted = ((obj as? [String: Any])?["_deleted"] as? Bool) == true
                result.append(RemoteConcert(id: id, data: json, updatedAt: date, isDeleted: deleted))
            }
            if rows.count < pageSize { break }
            offset += rows.count
        }
        return result
    }

    /// Удаление без SQL-изменений: вместо DELETE пишем «надгробие» (data = {"_deleted": true}),
    /// чтобы другие устройства не вернули концерт обратно при объединении.
    func deleteConcert(id: UUID, at: Date) async throws {
        let row: [String: Any] = ["id": id.uuidString, "data": ["_deleted": true], "updated_at": SupabaseDate.string(at)]
        _ = try await authed(
            path: "/rest/v1/concerts", query: [URLQueryItem(name: "on_conflict", value: "id")],
            method: "POST", json: [row], headers: ["Prefer": "resolution=merge-duplicates,return=minimal"])
    }

    // MARK: Profiles

    func upsertProfile(displayName: String) async throws {
        guard let uid = session?.userID else { throw BackendError.notSignedIn }
        let row: [String: Any] = ["user_id": uid, "display_name": displayName]
        _ = try await authed(
            path: "/rest/v1/profiles", query: [URLQueryItem(name: "on_conflict", value: "user_id")],
            method: "POST", json: [row], headers: ["Prefer": "resolution=merge-duplicates,return=minimal"])
    }

    func fetchProfileName() async throws -> String? {
        let data = try await authed(
            path: "/rest/v1/profiles",
            query: [URLQueryItem(name: "select", value: "display_name"), URLQueryItem(name: "limit", value: "1")],
            method: "GET")
        let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        return rows?.first?["display_name"] as? String
    }

    // MARK: Storage (бакет media, пути <uid>/<имя>)

    private func objectPath(_ name: String, uid: String, authenticated: Bool = false) throws -> String {
        guard MediaName.isSafe(name), !uid.isEmpty, !uid.contains("/") else {
            throw BackendError.server(status: 400, message: "Недопустимое имя файла")
        }
        return "/storage/v1/object/" + (authenticated ? "authenticated/" : "") + "media/\(uid)/\(name)"
    }

    /// Загружает файл. Если такой уже есть на сервере - считаем успехом.
    func uploadMedia(name: String, fileURL: URL, retried: Bool = false) async throws {
        let s = try await validSession()
        var request = makeRequest(path: try objectPath(name, uid: s.userID), method: "POST", token: s.accessToken)
        request.setValue(Self.mimeType(for: name), forHTTPHeaderField: "Content-Type")
        request.setValue("false", forHTTPHeaderField: "x-upsert")
        let (data, response) = try await perform { try await self.urlSession.upload(for: request, fromFile: fileURL) }
        let status = response.statusCode
        if (200..<300).contains(status) { return }
        let text = Self.message(from: data)
        if status == 409 || text.lowercased().contains("already exists") || text.lowercased().contains("duplicate") { return }
        if Self.isAuthExpired(status: status, data: data), !retried {
            _ = try await refresh()
            return try await uploadMedia(name: name, fileURL: fileURL, retried: true)
        }
        throw Self.restError(status: status, data: data)
    }

    /// Скачивает файл в `destination` (атомарно перемещает из временного места).
    func downloadMedia(name: String, to destination: URL, retried: Bool = false) async throws {
        let s = try await validSession()
        let request = makeRequest(path: try objectPath(name, uid: s.userID, authenticated: true), method: "GET", token: s.accessToken)
        let (tmp, response) = try await perform { try await self.urlSession.download(for: request) }
        guard (200..<300).contains(response.statusCode) else {
            let data = (try? Data(contentsOf: tmp)) ?? Data()
            try? FileManager.default.removeItem(at: tmp)
            if Self.isAuthExpired(status: response.statusCode, data: data), !retried {
                _ = try await refresh()
                return try await downloadMedia(name: name, to: destination, retried: true)
            }
            throw Self.restError(status: response.statusCode, data: data)
        }
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: tmp, to: destination)
    }

    func deleteMedia(name: String, retried: Bool = false) async throws {
        let s = try await validSession()
        let request = makeRequest(path: try objectPath(name, uid: s.userID), method: "DELETE", token: s.accessToken)
        let (data, response) = try await perform { try await self.urlSession.data(for: request) }
        if (200..<300).contains(response.statusCode) || response.statusCode == 404 { return }
        if Self.isAuthExpired(status: response.statusCode, data: data), !retried {
            _ = try await refresh()
            return try await deleteMedia(name: name, retried: true)
        }
        throw Self.restError(status: response.statusCode, data: data)
    }

    // MARK: Низкий уровень

    nonisolated func makeRequest(path: String, query: [URLQueryItem] = [], method: String, token: String? = nil) -> URLRequest {
        var comps = URLComponents(url: Self.baseURL, resolvingAgainstBaseURL: false)!
        comps.path = path
        if !query.isEmpty { comps.queryItems = query }
        var request = URLRequest(url: comps.url!)
        request.httpMethod = method
        request.timeoutInterval = 60
        request.setValue(Self.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer " + (token ?? Self.publishableKey), forHTTPHeaderField: "Authorization")
        return request
    }

    /// Запрос без пользовательского токена (auth-эндпоинты). Возвращает тело и статус.
    private func raw(path: String, query: [URLQueryItem] = [], method: String, json: Any) async throws -> (Data, Int) {
        var request = makeRequest(path: path, query: query, method: method)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: json)
        let (data, response) = try await perform { try await self.urlSession.data(for: request) }
        return (data, response.statusCode)
    }

    /// Запрос с токеном пользователя; один раз повторяется после обновления токена при 401.
    private func authed(path: String, query: [URLQueryItem] = [], method: String, json: Any? = nil,
                        headers: [String: String] = [:], retried: Bool = false) async throws -> Data {
        let s = try await validSession()
        var request = makeRequest(path: path, query: query, method: method, token: s.accessToken)
        if let json {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: json)
        }
        for (k, v) in headers { request.setValue(v, forHTTPHeaderField: k) }
        let (data, response) = try await perform { try await self.urlSession.data(for: request) }
        if Self.isAuthExpired(status: response.statusCode, data: data) && !retried {
            _ = try await refresh()
            return try await authed(path: path, query: query, method: method, json: json, headers: headers, retried: true)
        }
        guard (200..<300).contains(response.statusCode) else {
            throw Self.restError(status: response.statusCode, data: data)
        }
        return data
    }

    private func perform<T>(_ work: () async throws -> (T, URLResponse)) async throws -> (T, HTTPURLResponse) {
        do {
            let (value, response) = try await work()
            guard let http = response as? HTTPURLResponse else {
                throw BackendError.server(status: 0, message: "Некорректный ответ сервера")
            }
            return (value, http)
        } catch let error as BackendError {
            throw error
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost,
                 .cannotConnectToHost, .dnsLookupFailed, .dataNotAllowed, .internationalRoamingOff:
                throw BackendError.noNetwork
            case .cancelled:
                throw CancellationError()
            default:
                throw BackendError.noNetwork
            }
        }
    }

    // MARK: Разбор ответов

    nonisolated static func parseSession(_ data: Data, fallbackNick: String) -> AuthSession? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let access = obj["access_token"] as? String,
              let refresh = obj["refresh_token"] as? String,
              let user = obj["user"] as? [String: Any],
              let uid = user["id"] as? String else { return nil }
        let expiresIn = (obj["expires_in"] as? Double) ?? 3600
        var nick = fallbackNick
        if let email = user["email"] as? String, !email.isEmpty { nick = Nickname.nick(fromEmail: email) }
        return AuthSession(accessToken: access, refreshToken: refresh,
                           expiresAt: Date().addingTimeInterval(expiresIn), userID: uid, nick: nick)
    }

    nonisolated static func message(from data: Data) -> String {
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for key in ["msg", "message", "error_description", "error"] {
                if let s = obj[key] as? String, !s.isEmpty { return s }
            }
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    nonisolated static func authError(status: Int, data: Data) -> BackendError {
        let obj = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        let code = (obj["error_code"] as? String) ?? (obj["code"] as? String) ?? ""
        let text = message(from: data)
        let lower = text.lowercased()
        if code == "user_already_exists" || code == "email_exists" || lower.contains("already registered") || lower.contains("already been registered") {
            return .nickTaken
        }
        if code == "invalid_credentials" || lower.contains("invalid login credentials") { return .wrongCredentials }
        if code == "weak_password" || lower.contains("password should be") { return .weakPassword }
        if status == 429 { return .server(status: status, message: "Слишком много попыток, подожди немного") }
        return .server(status: status, message: text)
    }

    /// 401, а также 400/403 с текстом про просроченный JWT: нужно обновить токен и повторить.
    nonisolated static func isAuthExpired(status: Int, data: Data) -> Bool {
        if status == 401 { return true }
        guard status == 400 || status == 403 else { return false }
        let text = message(from: data).lowercased()
        return text.contains("jwt") || text.contains("expired")
    }

    nonisolated static func restError(status rawStatus: Int, data: Data) -> BackendError {
        let obj = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        let code = (obj["code"] as? String) ?? ""
        let text = message(from: data)
        let lower = text.lowercased()
        // Storage отдаёт реальный код в теле ({"statusCode":"413"}), а HTTP-статус бывает 400.
        let status = (obj["statusCode"] as? String).flatMap(Int.init) ?? (obj["statusCode"] as? Int) ?? rawStatus
        // PGRST205/42P01 - нет таблицы, 404 - нет бакета/таблицы.
        if code == "PGRST205" || code == "42P01" || (status == 404 && code.hasPrefix("PGRST")) {
            return .notSetUp
        }
        // 42501: либо не выданы GRANT (сервер не настроен), либо строку отклонила политика RLS.
        if code == "42501" || lower.contains("row-level security") || lower.contains("violates row-level") {
            return lower.contains("permission denied for") ? .notSetUp : .accessDenied
        }
        if status == 401 { return .sessionExpired }
        if lower.contains("bucket not found") { return .notSetUp }
        return .server(status: status, message: text)
    }

    nonisolated static func mimeType(for name: String) -> String {
        switch (name as NSString).pathExtension.lowercased() {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "heic": return "image/heic"
        case "mov": return "video/quicktime"
        case "mp4", "m4v": return "video/mp4"
        default: return "application/octet-stream"
        }
    }
}
