import SwiftUI

struct ContentView: View {
    @State private var showPast = true
    @State private var showForm = false
    @State private var showWaitingForm = false
    @Environment(ConcertStore.self) private var store

    var concerts: [Concert] {
        if showPast {
            return store.concerts
                .filter { $0.isPast }
                .sorted { $0.date > $1.date }
        } else {
            return store.concerts
                .filter { !$0.isPast }
                .sorted { $0.date < $1.date }
        }
    }
    var pastConcerts: [Concert] { return store.concerts.filter {$0.date < Calendar.current.startOfDay(for: Date())} }
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
            Text(value).font(.system(size: 36, weight: .heavy))
            Text(title).font(.caption).foregroundStyle(.white.opacity(0.8))
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

                Picker("Концерты", selection: $showPast) {
                    Text("Прошедшие").tag(true)
                    Text("Предстоящие").tag(false)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(concerts) { concert in
                            NavigationLink {
                                if showPast {
                                    ConcertCardView(initial: concert)
                                } else {
                                    WaitingCardView(concert: concert)
                                }
                            } label: {
                                ConcertRowView(concert: concert)
                                    .concertCard()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Мои концерты")
            .background(Color.btsBackground.ignoresSafeArea())
            .overlay(alignment: .bottomTrailing) {
                Button {
                    if showPast {
                        showForm = true
                    } else {
                        showWaitingForm = true
                    }
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
        .sheet(isPresented: $showWaitingForm) {
            NewWaitingView()
        }
    }
}

#Preview {
    ContentView()
        .environment(ConcertStore())
}
