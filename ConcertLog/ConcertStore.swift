import Foundation

@Observable class ConcertStore {
    var concerts: [Concert] = sampleConcerts
    
    func save() {
        if let data = try? JSONEncoder().encode(concerts) {
            UserDefaults.standard.set(data, forKey: "concerts")
        }
    }
    
    func add(artist: String, city: String, date: Date, rating: Double, comment: String) {
        concerts.append(
            Concert(
                artist: artist,
                city: city,
                date: date,
                rating: rating < 0.05 ? nil : rating,
                tags: [],
                comment: comment.isEmpty ? nil : comment
            ))
        save()
    }
    
    init() {
        if let concert = UserDefaults.standard.data(forKey: "concerts"),
           let saved = try? JSONDecoder().decode([Concert].self, from: concert) {
            concerts = saved
        }
    }
}
