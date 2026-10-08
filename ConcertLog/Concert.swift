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
