import Foundation

@Observable class ConcertStore {
    var concerts: [Concert] = sampleConcerts
    
    func save() {
        if let data = try? JSONEncoder().encode(concerts) {
            UserDefaults.standard.set(data, forKey: "concerts")
        }
    }
    
    func add(artist: String, city: String, date: Date, rating: Double, comment: String, photoData: Data? = nil) {
        var photoName: String? = nil
        if let photoData {
                let name = UUID().uuidString + ".jpg"
                let url = URL.documentsDirectory.appending(path: name)
                try? photoData.write(to: url)
                photoName = name
            }
        concerts.append(
            Concert(
                artist: artist,
                city: city,
                date: date,
                rating: rating < 0.05 ? nil : rating,
                tags: [],
                comment: comment.isEmpty ? nil : comment,
                photoName: photoName
            ))
        save()
    }
    
    func update(_ old: Concert, artist: String, city: String, date: Date, rating: Double, comment: String) {
        if let index = concerts.firstIndex(where: { $0.id == old.id }) {
            concerts[index] = Concert(id: old.id, artist: artist, city: city, date: date, rating: rating < 0.05 ? nil : rating, tags: old.tags, comment: comment.isEmpty ? nil : comment, photoName: old.photoName)
            }
        save()
    }
    
    init() {
        if let concert = UserDefaults.standard.data(forKey: "concerts"),
           let saved = try? JSONDecoder().decode([Concert].self, from: concert) {
            concerts = saved
        }
    }
}
