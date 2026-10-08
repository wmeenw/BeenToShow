import Foundation

@Observable class ConcertStore {
    var concerts: [Concert] = sampleConcerts
    
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
    }
}
