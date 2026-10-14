import SwiftUI

struct ContentView: View {
    @State private var showForm = false
    @Environment(ConcertStore.self) private var store

    var concerts: [Concert] {
        store.concerts
            .filter { $0.isPast }
            .sorted { $0.date > $1.date }
    }
    var pastConcerts: [Concert] { return store.concerts.filter { $0.isPast } }
    var concertsCount: Int { return pastConcerts.count }
    var citiesCount: Int { return Set(pastConcerts.map { $0.city }).count }
    var averageRating: Double {
        let ratings = pastConcerts.compactMap { $0.rating }
        if ratings.isEmpty {
            return 0
        }
        return ratings.reduce(0, +) / Double(ratings.count)
    }

    func statColumn(value: String, title: String) -> some View {
        VStack {
            Text(value).font(.unbounded(36, .bold))
            Text(title).font(.onest(12)).foregroundStyle(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
    }

    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    statColumn(value: "\(concertsCount)", title: "концертов")
                    statColumn(value: "\(citiesCount)", title: "городов")
                    statColumn(value: String(format: "%.1f", averageRating), title: "средняя оценка")
                }
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color.btsPink, Color.btsViolet],
                        startPoint: .topLeading,
                        endPoint: UnitPoint.bottomTrailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 26))
                .padding(.horizontal)

                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(concerts) { concert in
                            NavigationLink {
                                ConcertCardView(initial: concert)
                            } label: {
                                ConcertRowView(concert: concert)
                                    .concertCard()
                            }
                            .buttonStyle(.plain)
                        }
                        if concerts.isEmpty {
                            Text("Концертов пока нет")
                                .font(.onest(14))
                                .foregroundStyle(.white.opacity(0.5))
                                .padding(.top, 40)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Мои концерты")
            .background(Color.btsBackground.ignoresSafeArea())
            .overlay(alignment: .bottomTrailing) {
                Button {
                    showForm = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(
                            LinearGradient(
                                colors: [Color.btsPink, Color.btsViolet],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Circle())
                        .shadow(color: Color.btsPink.opacity(0.5), radius: 12)
                }
                .padding()
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showForm) {
            NewConcertView()
        }
    }
}

#Preview {
    ContentView()
        .environment(ConcertStore())
}
