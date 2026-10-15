import SwiftUI

@main
struct ConcertLogApp: App {
    @State private var store = ConcertStore()
    @State private var account = AccountManager()
    /// false, пока не понятно, есть ли сохранённая сессия (показываем заставку).
    @State private var didRestore = false
    @Environment(\.scenePhase) private var scenePhase
    init() { BTSFonts.register() }

    var body: some Scene {
        WindowGroup {
            Group {
                if account.isSignedIn {
                    MainTabView()
                } else if didRestore {
                    AuthView()
                } else {
                    splash
                }
            }
            .environment(store)
            .environment(account)
            .preferredColorScheme(.dark)
            .task {
                account.willActivate = { uid in await store.prepareForUser(uid) }
                await account.restoreSession()
                didRestore = true
            }
            .onChange(of: account.isSignedIn) { _, signedIn in
                // Вход, регистрация или восстановление сессии: объединяем локальные концерты с серверными.
                if signedIn { store.startSync() }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active, account.isSignedIn {
                    Task { await store.flushPending() }
                }
            }
        }
    }

    private var splash: some View {
        ZStack {
            Color.btsBackground.ignoresSafeArea()
            VStack(spacing: 16) {
                Text("BeenToShow")
                    .font(.unbounded(28, .bold))
                    .foregroundStyle(Color.white)
                ProgressView().tint(Color.btsPink)
            }
        }
    }
}
