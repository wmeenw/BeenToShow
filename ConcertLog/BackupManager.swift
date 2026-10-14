import Foundation

/// Резервная копия дневника в одном файле: концерты + фото (base64 внутри JSON).
/// Не зависит от iCloud-возможностей: файл можно сохранить в «Файлы» / iCloud Drive вручную.
nonisolated enum BackupError: LocalizedError {
    case empty
    case tooLarge
    case notBackup
    case unsupportedVersion
    case corrupted

    var errorDescription: String? {
        switch self {
        case .empty: return "Дневник пока пуст — копировать нечего."
        case .notBackup: return "Это не похоже на резервную копию BeenToShow."
        case .unsupportedVersion: return "Копия создана более новой версией приложения. Обнови BeenToShow и попробуй снова."
        case .corrupted: return "Файл повреждён или не читается."
        case .tooLarge: return "Файл копии слишком большой, чтобы восстановить его на этом устройстве."
        }
    }
}

nonisolated struct BackupPayload {
    let concerts: [Concert]
    let photos: [String: Data]
    var videos: [String: Data] = [:]
    let createdAt: Date
}

nonisolated enum BackupManager {
    /// Общий лимит медиа в одной копии (всё читается в память и кодируется в base64).
    static let mediaLimitBytes: Int64 = 150 * 1024 * 1024
    /// Файлы копии больше этого размера не читаем вовсе.
    static let restoreLimitBytes: Int64 = 300 * 1024 * 1024
    static let fileExtension = "btsbackup"
    private static let formatID = "BeenToShow.backup"
    private static let currentVersion = 1

    struct BackupResult {
        let url: URL
        let videosSkipped: Bool
    }

    private struct BackupFile: Codable {
        var format: String
        var version: Int
        var createdAt: Date
        var concerts: [Concert]
        var photos: [String: Data]
        var videos: [String: Data]? = nil
    }

    static func fileName(for date: Date = Date()) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return "BeenToShow-copy-\(f.string(from: date)).\(fileExtension)"
    }

    /// Имя фото должно быть простым именем файла, без путей.
    private static func isSafeName(_ name: String) -> Bool {
        !name.isEmpty && !name.contains("/") && !name.contains("\\") && name != "." && name != ".."
    }

    private static func fileSize(_ url: URL) -> Int64 {
        let n = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size]) as? NSNumber
        return n?.int64Value ?? 0
    }

    /// Собирает копию и пишет её во временный файл. Вызывать не с главного потока.
    /// Если фото+видео вместе больше лимита, видео в копию не входят (videosSkipped).
    static func createBackup(concerts: [Concert], photosDirectory: URL, outputDirectory: URL = FileManager.default.temporaryDirectory, now: Date = Date()) throws -> BackupResult {
        guard !concerts.isEmpty else { throw BackupError.empty }
        var photoNames: [String] = []
        var videoNames: [String] = []
        var seen = Set<String>()
        for concert in concerts {
            for name in concert.photoNames where isSafeName(name) && seen.insert(name).inserted { photoNames.append(name) }
            for name in concert.videoNames where isSafeName(name) && seen.insert(name).inserted { videoNames.append(name) }
        }
        let photoBytes = photoNames.reduce(Int64(0)) { $0 + fileSize(photosDirectory.appending(path: $1)) }
        let videoBytes = videoNames.reduce(Int64(0)) { $0 + fileSize(photosDirectory.appending(path: $1)) }
        let includeVideos = photoBytes + videoBytes <= mediaLimitBytes
        let videosSkipped = !includeVideos && !videoNames.isEmpty
        var photos: [String: Data] = [:]
        for name in photoNames {
            if let data = try? Data(contentsOf: photosDirectory.appending(path: name)) {
                photos[name] = data
            }
        }
        var videos: [String: Data] = [:]
        if includeVideos {
            for name in videoNames {
                if let data = try? Data(contentsOf: photosDirectory.appending(path: name), options: .mappedIfSafe) {
                    videos[name] = data
                }
            }
        }
        let file = BackupFile(format: formatID, version: currentVersion, createdAt: now, concerts: concerts, photos: photos, videos: videos.isEmpty ? nil : videos)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(file)
        let url = outputDirectory.appending(path: fileName(for: now))
        try? FileManager.default.removeItem(at: url)
        try data.write(to: url, options: .atomic)
        return BackupResult(url: url, videosSkipped: videosSkipped)
    }

    /// Читает и проверяет файл копии. Ничего не меняет в данных приложения.
    static func readBackup(at url: URL) throws -> BackupPayload {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        if fileSize(url) > restoreLimitBytes { throw BackupError.tooLarge }
        guard let data = try? Data(contentsOf: url) else { throw BackupError.corrupted }
        return try parse(data)
    }

    static func parse(_ data: Data) throws -> BackupPayload {
        // Сначала проверяем только заголовок, чтобы отличить «чужой» файл от повреждённого.
        struct Header: Decodable { var format: String; var version: Int }
        guard let header = try? JSONDecoder().decode(Header.self, from: data), header.format == formatID else {
            throw BackupError.notBackup
        }
        guard header.version <= currentVersion else { throw BackupError.unsupportedVersion }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let file = try? decoder.decode(BackupFile.self, from: data) else { throw BackupError.corrupted }
        guard !file.concerts.isEmpty else { throw BackupError.empty }
        let safePhotos = file.photos.filter { isSafeName($0.key) }
        var concerts = file.concerts
        for i in concerts.indices {
            concerts[i].photoNames = concerts[i].photoNames.filter { isSafeName($0) }
            concerts[i].videoNames = concerts[i].videoNames.filter { isSafeName($0) }
        }
        return BackupPayload(concerts: concerts, photos: safePhotos, videos: (file.videos ?? [:]).filter { isSafeName($0.key) }, createdAt: file.createdAt)
    }
}
