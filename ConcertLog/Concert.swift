import Foundation

struct Concert: Identifiable, Codable {
    var id = UUID()
    let artist: String
    let city: String
    let date: Date
    let rating: Double?
    let tags: [String]
    let comment: String?
    var photoName: String? = nil
    var saleDate: Date? = nil
    var reminders: [String] = []
    var remindAfterConcert: Bool = false
    var isPast: Bool {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())) ?? Date()
        return date < tomorrow
    }
}

extension Concert {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        artist = try container.decode(String.self, forKey: .artist)
        city = try container.decode(String.self, forKey: .city)
        date = try container.decode(Date.self, forKey: .date)
        rating = try container.decodeIfPresent(Double.self, forKey: .rating)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        comment = try container.decodeIfPresent(String.self, forKey: .comment)
        photoName = try container.decodeIfPresent(String.self, forKey: .photoName)
        saleDate = try container.decodeIfPresent(Date.self, forKey: .saleDate)
        reminders = try container.decodeIfPresent([String].self, forKey: .reminders) ?? []
        remindAfterConcert = try container.decodeIfPresent(Bool.self, forKey: .remindAfterConcert) ?? false
    }
}

func makeDate(day: Int, month: Int, year: Int) -> Date {
    var date = DateComponents()
    date.year = year
    date.month = month
    date.day = day
    return Calendar.current.date(from: date)!
}

let sampleConcerts = [
    Concert(artist: "Billie Eilish", city: "Лондон", date: makeDate(day: 16, month: 7, year: 2025), rating: 5.0, tags: ["круто", "мечта"], comment: "Это был лучший день в моей жизни! Я теперь без голоса ахах"),
    Concert(artist: "Kendrick Lamar", city: "Лондон", date: makeDate(day: 22, month: 7, year: 2025), rating: 4.5, tags: ["вау"], comment: "Танцоры! Салютыыы"),
    Concert(artist: "The Weeknd", city: "Мадрид", date: makeDate(day: 30, month: 6, year: 2025), rating: 4.8, tags: ["кайф", "огонь"], comment: "Очень крутое шоу"),
    Concert(artist: "Lana Del Rey", city: "Париж", date: makeDate(day: 12, month: 3, year: 2027), rating: nil, tags: [], comment: nil),
    Concert(artist: "Charli XCX", city: "Милан", date: makeDate(day: 1, month: 5, year: 2027), rating: nil, tags: [], comment: nil)
]
