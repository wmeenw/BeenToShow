import Foundation
import AVFoundation
import CoreTransferable
import UniformTypeIdentifiers
import UIKit

struct Concert: Identifiable, Codable {
    var id = UUID()
    let artist: String
    let city: String
    let date: Date
    let rating: Double?
    let tags: [String]
    let comment: String?
    var photoNames: [String] = []
    var videoNames: [String] = []
    var saleDate: Date? = nil
    var reminders: [String] = []
    var remindAfterConcert: Bool = false
    nonisolated var isPast: Bool {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())) ?? Date()
        return date < tomorrow
    }
}

private enum LegacyConcertCodingKeys: String, CodingKey {
    case photoName
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
        if let names = try container.decodeIfPresent([String].self, forKey: .photoNames) {
            photoNames = names
        } else {
            let legacyContainer = try decoder.container(keyedBy: LegacyConcertCodingKeys.self)
            if let legacy = try legacyContainer.decodeIfPresent(String.self, forKey: .photoName) {
                photoNames = [legacy]
            } else {
                photoNames = []
            }
        }
        videoNames = try container.decodeIfPresent([String].self, forKey: .videoNames) ?? []
        saleDate = try container.decodeIfPresent(Date.self, forKey: .saleDate)
        reminders = try container.decodeIfPresent([String].self, forKey: .reminders) ?? []
        remindAfterConcert = try container.decodeIfPresent(Bool.self, forKey: .remindAfterConcert) ?? false
    }
}

/// Видео, выбранное в PhotosPicker: файл копируется во временную папку (без загрузки в память).
struct PickedVideo: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let dest = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString + "." + ext)
            try FileManager.default.copyItem(at: received.file, to: dest)
            return PickedVideo(url: dest)
        }
    }
}

enum VideoLimits {
    static let maxCount = 3
    static let maxSeconds: Double = 60
}

enum VideoTools {
    static func duration(of url: URL) async -> Double {
        let asset = AVURLAsset(url: url)
        guard let time = try? await asset.load(.duration) else { return 0 }
        return time.seconds.isFinite ? time.seconds : 0
    }

    static func thumbnail(of url: URL) async -> UIImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 400, height: 400)
        guard let result = try? await generator.image(at: .zero) else { return nil }
        return UIImage(cgImage: result.image)
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
