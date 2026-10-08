import Foundation
import SwiftUI

struct WaitingScreen: View {
    var upcoming: [Concert] {
        sampleConcerts
            .filter { $0.date >= Calendar.current.startOfDay(for: Date()) }
            .sorted { $0.date < $1.date }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(upcoming) { concert in
                        ConcertRowView(concert: concert)
                            .concertCard()
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
}
