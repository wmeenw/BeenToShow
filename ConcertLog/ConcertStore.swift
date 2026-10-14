import Foundation

@Observable class ConcertStore {
    var concerts: [Concert] = sampleConcerts
    
    func save() {
        if let data = try? JSONEncoder().encode(concerts) {
            UserDefaults.standard.set(data, forKey: "concerts")
        }
    }
    
    func add(artist: String, city: String, date: Date, rating: Double, comment: String, tags: [String] = [], photoData: Data? = nil) {
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
                tags: tags,
                comment: comment.isEmpty ? nil : comment,
                photoName: photoName
            ))
        save()
    }
    
    func update(_ old: Concert, artist: String, city: String, date: Date, rating: Double, comment: String, tags: [String], photoData: Data? = nil) {
        guard let index = concerts.firstIndex(where: { $0.id == old.id }) else { return }
        var photoName = concerts[index].photoName
        if let photoData {
            if let oldName = photoName {
                try? FileManager.default.removeItem(at: URL.documentsDirectory.appending(path: oldName))
            }
            let name = UUID().uuidString + ".jpg"
            try? photoData.write(to: URL.documentsDirectory.appending(path: name))
            photoName = name
        }
        concerts[index] = Concert(
            id: old.id,
            artist: artist,
            city: city,
            date: date,
            rating: rating < 0.05 ? nil : rating,
            tags: tags,
            comment: comment.isEmpty ? nil : comment,
            photoName: photoName
        )
        save()
    }
    
    init() {
        if let concert = UserDefaults.standard.data(forKey: "concerts"),
           let saved = try? JSONDecoder().decode([Concert].self, from: concert) {
            concerts = saved
        }
    }
}
