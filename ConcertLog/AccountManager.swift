import Foundation

/// Состояние аккаунта для UI. Создаётся один раз (например, в App) и передаётся в environment.
@Observable class AccountManager {
    enum State: Equatable {
        case signedOut
        case signedIn
    }

    private(set) var state: State = .signedOut
    private(set) var nick: String = ""
    private(set) var userID: String = ""
    private(set) var displayName: String = ""
    /// true, пока восстанавливаем сессию при запуске.
    private(set) var isRestoring = false

    /// Вызывается после успешного входа, до того как UI считает пользователя вошедшим:
    /// здесь приложение сверяет владельца локальных данных и стирает чужие.
    var willActivate: ((String) async -> Void)?

    private let client: SupabaseClient
    private var isObserving = false
    private static let displayNameKey = "account.displayName"

    init(client: SupabaseClient = .shared) {
        self.client = client
    }

    var isSignedIn: Bool { state == .signedIn }

    /// Регистрация: ник + пароль + отображаемое имя. Бросает BackendError с русским текстом.
    func signUp(nick: String, password: String, displayName: String) async throws {
        await observeSessionLoss()
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let session = try await client.signUp(nick: nick, password: password, displayName: name)
        let shown = name.isEmpty ? session.nick : name
        await willActivate?(session.userID)
        apply(session, displayName: shown)
        try? await client.upsertProfile(displayName: shown)
    }

    func signIn(nick: String, password: String) async throws {
        await observeSessionLoss()
        let session = try await client.signIn(nick: nick, password: password)
        await willActivate?(session.userID)
        let remoteName = try? await client.fetchProfileName()
        let cached = UserDefaults.standard.string(forKey: Self.displayNameKey)
        apply(session, displayName: (remoteName ?? nil) ?? cached ?? session.nick)
    }

    /// Локальный выход. Локальные данные концертов не трогаем (решает вызывающий код).
    func signOut() async {
        await client.signOut()
        markSignedOut()
    }

    private func markSignedOut() {
        UserDefaults.standard.removeObject(forKey: Self.displayNameKey)
        nick = ""
        userID = ""
        displayName = ""
        state = .signedOut
    }

    /// Сессия пропала сама (токен отозван или истёк навсегда): UI должен показать вход.
    /// Локальные данные не трогаем: владелец остаётся помечен, правки дождутся повторного входа.
    private func observeSessionLoss() async {
        guard !isObserving else { return }
        isObserving = true
        await client.setSessionLostHandler { [weak self] in
            await self?.markSignedOut()
        }
    }

    /// Меняет отображаемое имя локально и на сервере (ошибка сети не откатывает локальное имя).
    func updateDisplayName(_ name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        displayName = trimmed
        UserDefaults.standard.set(trimmed, forKey: Self.displayNameKey)
        try? await client.upsertProfile(displayName: trimmed)
    }

    /// Вызывать при запуске: поднимает сессию из Keychain (работает офлайн) и обновляет токен при необходимости.
    func restoreSession() async {
        await observeSessionLoss()
        guard let session = await client.currentSession else { return }
        await willActivate?(session.userID)
        isRestoring = true
        defer { isRestoring = false }
        apply(session, displayName: UserDefaults.standard.string(forKey: Self.displayNameKey) ?? session.nick)
        if session.expiresAt.timeIntervalSinceNow < 300 {
            do {
                let fresh = try await client.refresh()
                apply(fresh, displayName: displayName)
            } catch BackendError.sessionExpired {
                markSignedOut()
            } catch {
                // Нет сети: остаёмся в аккаунте, токен обновится при первом запросе.
            }
        }
        if let name = try? await client.fetchProfileName(), !name.isEmpty, name != displayName {
            displayName = name
            UserDefaults.standard.set(name, forKey: Self.displayNameKey)
        }
    }

    private func apply(_ session: AuthSession, displayName: String) {
        nick = session.nick
        userID = session.userID
        self.displayName = displayName
        UserDefaults.standard.set(displayName, forKey: Self.displayNameKey)
        state = .signedIn
    }
}
