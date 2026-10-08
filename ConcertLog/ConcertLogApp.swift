import SwiftUI

@main
struct ConcertLogApp: App {
    @State private var store = ConcertStore()
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(store)
        }
    }
}
