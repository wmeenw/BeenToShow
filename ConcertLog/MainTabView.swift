import Foundation
import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Label("Концерты", systemImage: "music.note")
                }
            
            WaitingScreen()
                .tabItem {
                    Label("Ждем", systemImage: "clock")
                }
            
            Text("Профиль")
                .tabItem {
                    Label("Профиль", systemImage: "person")
                }
        }
        .tint(Color.btsPink)
    }
}
