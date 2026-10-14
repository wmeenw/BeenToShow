import Foundation
import SwiftUI

struct WaitingScreen: View {
    @Environment(ConcertStore.self) private var store
    var upcoming: [Concert] {
        store.concerts
            .filter { $0.isPast }
            .sorted { $0.date < $1.date }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(upcoming) { concert in
                        NavigationLink {
                            WaitingCardView(concert: concert)
                        } label: {
                            ConcertRowView(concert: concert)
                                .concertCard()
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
            .navigationTitle("Ждем")
            .background(Color.btsBackground.ignoresSafeArea())
            .preferredColorScheme(.dark)
        }
    }
}

#Preview {
    WaitingScreen()
        .environment(ConcertStore())
}
