import SwiftUI

/// Первый экран для вышедшего пользователя: вход или регистрация (ник + пароль, затем имя).
struct AuthView: View {
    @Environment(AccountManager.self) private var account

    private enum Mode: String, CaseIterable {
        case signIn = "Войти"
        case signUp = "Создать аккаунт"
    }

    private enum Field { case nick, password, name }

    @State private var mode: Mode = .signIn
    @State private var nick = ""
    @State private var password = ""
    @State private var displayName = ""
    /// Второй шаг регистрации: «Как к тебе обращаться?»
    @State private var askName = false
    @State private var isLoading = false
    @State private var errorText: String?
    @FocusState private var focus: Field?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                logo
                    .padding(.top, 48)

                if !askName {
                    Picker("Режим", selection: $mode) {
                        ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: mode) { _, _ in errorText = nil }
                }

                if askName {
                    nameStep
                } else {
                    credentialsStep
                }

                if let errorText {
                    Text(errorText)
                        .font(.onest(14))
                        .foregroundStyle(Color.btsPink)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }

                primaryButton

                if askName {
                    Button("Назад") {
                        errorText = nil
                        askName = false
                    }
                    .font(.onest(15, .medium))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .disabled(isLoading)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.btsBackground.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .disabled(isLoading)
    }

    // MARK: Части экрана

    private var logo: some View {
        VStack(spacing: 14) {
            Image(systemName: "music.note")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Color.white)
                .frame(width: 84, height: 84)
                .background(
                    LinearGradient(colors: [Color.btsPink, Color.btsViolet],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 26))
                .shadow(color: Color.btsPink.opacity(0.5), radius: 16)
            Text("BeenToShow")
                .font(.unbounded(28, .bold))
                .foregroundStyle(Color.white)
            Text("Дневник концертов, который всегда с тобой")
                .font(.onest(15))
                .foregroundStyle(Color.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
    }

    private var credentialsStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Ник", text: $nick)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.username)
                .keyboardType(.asciiCapable)
                .submitLabel(.next)
                .focused($focus, equals: .nick)
                .onSubmit { focus = .password }
                .font(.onest(17))
                .inputCard()

            SecureField("Пароль", text: $password)
                .textContentType(mode == .signUp ? .newPassword : .password)
                .submitLabel(mode == .signUp ? .next : .go)
                .focused($focus, equals: .password)
                .onSubmit { primaryAction() }
                .font(.onest(17))
                .inputCard()

            if mode == .signUp {
                Text("Ник: от \(Nickname.minLength) до \(Nickname.maxLength) символов, латинские буквы, цифры и _ . -  Точка не может быть в начале, в конце и дважды подряд.  Пароль: минимум \(Nickname.minPasswordLength) символов.")
                    .font(.onest(13))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .padding(.horizontal, 4)
            }
        }
    }

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Как к тебе обращаться?")
                .font(.unbounded(20, .bold))
                .foregroundStyle(Color.white)
            Text("Это имя будет в твоём профиле. Его можно изменить позже.")
                .font(.onest(14))
                .foregroundStyle(Color.white.opacity(0.6))
            TextField("Имя", text: $displayName)
                .textContentType(.givenName)
                .submitLabel(.go)
                .focused($focus, equals: .name)
                .onSubmit { primaryAction() }
                .font(.onest(17))
                .inputCard()
        }
        .onAppear { focus = .name }
    }

    private var primaryButton: some View {
        Button {
            primaryAction()
        } label: {
            ZStack {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(buttonTitle)
                        .font(.onest(17, .semibold))
                }
            }
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(colors: [Color.btsPink, Color.btsViolet],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .opacity(canSubmit ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit || isLoading)
    }

    private var buttonTitle: String {
        if askName { return "Создать аккаунт" }
        return mode == .signIn ? "Войти" : "Далее"
    }

    private var canSubmit: Bool {
        if askName { return !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return !nick.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty
    }

    // MARK: Действия

    private func primaryAction() {
        guard canSubmit, !isLoading else { return }
        errorText = nil
        focus = nil

        if askName {
            run { try await account.signUp(nick: nick, password: password, displayName: displayName) } onFail: { error in
                // Ник занят или формат неверный: возвращаем на первый шаг, чтобы исправить.
                if let backend = error as? BackendError {
                    switch backend {
                    case .nickTaken, .invalidNick, .weakPassword: askName = false
                    default: break
                    }
                }
            }
            return
        }

        switch mode {
        case .signIn:
            run { try await account.signIn(nick: nick, password: password) }
        case .signUp:
            // Локальная проверка до второго шага.
            do {
                _ = try Nickname.normalize(nick)
                guard password.count >= Nickname.minPasswordLength else { throw BackendError.weakPassword }
                askName = true
            } catch {
                errorText = message(for: error)
            }
        }
    }

    private func run(_ work: @escaping () async throws -> Void, onFail: ((Error) -> Void)? = nil) {
        isLoading = true
        Task {
            do {
                try await work()
                // Успех: корневой экран сам переключится на приложение.
            } catch {
                errorText = message(for: error)
                onFail?(error)
            }
            isLoading = false
        }
    }

    private func message(for error: Error) -> String {
        if let backend = error as? BackendError, let text = backend.errorDescription { return text }
        if error is CancellationError { return "Запрос прерван, попробуй ещё раз" }
        return "Что-то пошло не так, попробуй ещё раз"
    }
}
