import SwiftUI

@main
struct ConcertLogApp: App {
    @State private var store = ConcertStore()
    init() { BTSFonts.register() }
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(store)
        }
    }
}
