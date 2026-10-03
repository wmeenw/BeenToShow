import SwiftUI

struct ContentView: View {
    @State private var showPast = true

    var concerts: [Concert] {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        if showPast {
            return sampleConcerts
                .filter { $0.date < startOfToday }
                .sorted { $0.date > $1.date }
        } else {
            return sampleConcerts
                .filter { $0.date >= startOfToday }
                .sorted { $0.date < $1.date }
        }
    }
    var pastConcerts: [Concert] { return sampleConcerts.filter {$0.date < Calendar.current.startOfDay(for: Date())} }
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
            Text(value).font(.title).bold()
            Text(title).font(.caption).foregroundStyle(.secondary)
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
                .background(.gray.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 20))
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
                            NavigationLink(destination: ConcertCardView(concert: concert)){
                                ConcertRowView(concert: concert)
                                    .padding(.vertical)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(.gray.opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 20))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Мои концерты")
        }
    }
}

#Preview {
    ContentView()
}
