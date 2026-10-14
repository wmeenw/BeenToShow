import Foundation
import UserNotifications

@Observable class ConcertStore {
    var concerts: [Concert] = []
    
    func save() {
        if let data = try? JSONEncoder().encode(concerts) {
            UserDefaults.standard.set(data, forKey: "concerts")
        }
    }

    private func writePhotos(_ datas: [Data]) -> [String] {
        datas.map { data in
            let name = UUID().uuidString + ".jpg"
            try? data.write(to: URL.documentsDirectory.appending(path: name))
            return name
        }
    }

    /// Переносит выбранные видео из временной папки в documents, возвращает имена файлов.
    private func writeVideos(_ urls: [URL]) -> [String] {
        urls.compactMap { url in
            let ext = url.pathExtension.isEmpty ? "mov" : url.pathExtension
            let name = UUID().uuidString + "." + ext
            let dest = URL.documentsDirectory.appending(path: name)
            do {
                do { try FileManager.default.moveItem(at: url, to: dest) }
                catch { try FileManager.default.copyItem(at: url, to: dest) }
                return name
            } catch {
                return nil
            }
        }
    }

    func add(artist: String, city: String, date: Date, rating: Double, comment: String, tags: [String] = [], photoDatas: [Data] = [], videoURLs: [URL] = [], saleDate: Date? = nil, reminders: [String] = [], remindAfterConcert: Bool = false) {
        let newConcert = Concert(
            artist: artist,
            city: city,
            date: date,
            rating: rating < 0.05 ? nil : rating,
            tags: tags,
            comment: comment.isEmpty ? nil : comment,
            photoNames: writePhotos(photoDatas),
            videoNames: writeVideos(videoURLs),
            saleDate: saleDate,
            reminders: reminders,
            remindAfterConcert: remindAfterConcert
        )
        concerts.append(newConcert)
        save()
        scheduleNotifications(for: newConcert)
    }

    func update(_ old: Concert, artist: String, city: String, date: Date, rating: Double, comment: String, tags: [String], keptPhotoNames: [String]? = nil, newPhotoDatas: [Data] = [], keptVideoNames: [String]? = nil, newVideoURLs: [URL] = [], saleDate: Date?, reminders: [String], remindAfterConcert: Bool) {
        guard let index = concerts.firstIndex(where: { $0.id == old.id }) else { return }
        let existingNames = concerts[index].photoNames
        let namesToKeep = keptPhotoNames ?? existingNames
        let removedNames = Set(existingNames).subtracting(namesToKeep)
        for name in removedNames {
            try? FileManager.default.removeItem(at: URL.documentsDirectory.appending(path: name))
        }
        let finalNames = namesToKeep + writePhotos(newPhotoDatas)
        let existingVideos = concerts[index].videoNames
        let videosToKeep = keptVideoNames ?? existingVideos
        for name in Set(existingVideos).subtracting(videosToKeep) {
            try? FileManager.default.removeItem(at: URL.documentsDirectory.appending(path: name))
        }
        let finalVideos = videosToKeep + writeVideos(newVideoURLs)
        let updatedConcert = Concert(
            id: old.id,
            artist: artist,
            city: city,
            date: date,
            rating: rating < 0.05 ? nil : rating,
            tags: tags,
            comment: comment.isEmpty ? nil : comment,
            photoNames: finalNames,
            videoNames: finalVideos,
            saleDate: saleDate,
            reminders: reminders,
            remindAfterConcert: remindAfterConcert
        )
        concerts[index] = updatedConcert
        save()
        scheduleNotifications(for: updatedConcert)
    }

    func delete(_ concert: Concert) {
        for name in concert.photoNames + concert.videoNames {
            try? FileManager.default.removeItem(at: URL.documentsDirectory.appending(path: name))
        }
        concerts.removeAll { $0.id == concert.id }
        save()
        cancelNotifications(for: concert)
    }

    /// Полная замена данных из резервной копии: фото, концерты, уведомления.
    /// Файлы пишутся вне главного потока; при любой ошибке записи старые данные не трогаем.
    @discardableResult
    func restore(_ payload: BackupPayload) async -> Bool {
        let docs = URL.documentsDirectory
        let restored = payload.concerts
        let needed = Set(restored.flatMap { $0.photoNames + $0.videoNames })
        let photos = payload.photos.filter { needed.contains($0.key) }
        let videos = payload.videos.filter { needed.contains($0.key) }
        let written: [String]? = await Task.detached(priority: .userInitiated) {
            var done: [String] = []
            for (name, data) in photos.map({ ($0.key, $0.value) }) + videos.map({ ($0.key, $0.value) }) {
                do {
                    try data.write(to: docs.appending(path: name), options: .atomic)
                    done.append(name)
                } catch {
                    return nil
                }
            }
            return done
        }.value
        guard written != nil else { return false }

        // Страховка: текущие данные кладём в concerts_backup до замены.
        if let current = UserDefaults.standard.data(forKey: "concerts") {
            UserDefaults.standard.set(current, forKey: "concerts_backup")
        }
        let old = concerts
        for concert in old { cancelNotifications(for: concert) }
        concerts = restored
        save()
        // Старые файлы удаляем только после сохранения.
        for concert in old {
            for name in concert.photoNames + concert.videoNames where !needed.contains(name) {
                try? FileManager.default.removeItem(at: docs.appending(path: name))
            }
        }
        for concert in concerts {
            scheduleNotifications(for: concert)
        }
        return true
    }

    func deleteAll() {
        for concert in concerts {
            for name in concert.photoNames + concert.videoNames {
                try? FileManager.default.removeItem(at: URL.documentsDirectory.appending(path: name))
            }
            cancelNotifications(for: concert)
        }
        concerts = []
        save()
    }
    
    init() {
        guard let stored = UserDefaults.standard.data(forKey: "concerts") else { return }
        if let saved = try? JSONDecoder().decode([Concert].self, from: stored) {
            concerts = saved
        } else {
            UserDefaults.standard.set(stored, forKey: "concerts_backup")
        }
    }
}

private let reminderOffsets: [(label: String, component: Calendar.Component, value: Int, title: String)] = [
    ("За неделю", .day, -7, "Билеты через неделю"),
    ("За день", .day, -1, "Билеты уже завтра"),
    ("За час", .hour, -1, "Билеты уже скоро")
]

extension ConcertStore {
    private func notificationIdentifier(for concert: Concert, suffix: String) -> String {
        "concert-\(concert.id.uuidString)-\(suffix)"
    }

    private func allNotificationIdentifiers(for concert: Concert) -> [String] {
        reminderOffsets.map { notificationIdentifier(for: concert, suffix: $0.label) } + [notificationIdentifier(for: concert, suffix: "after")]
    }

    func cancelNotifications(for concert: Concert) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: allNotificationIdentifiers(for: concert))
    }

    func scheduleNotifications(for concert: Concert) {
        let identifiers = allNotificationIdentifiers(for: concert)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)

        guard !concert.reminders.isEmpty || concert.remindAfterConcert else { return }

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                guard let self, self.concerts.contains(where: { $0.id == concert.id }) else { return }
                self.addNotificationRequests(for: concert)
            }
        }
    }

    private func addNotificationRequests(for concert: Concert) {
        let center = UNUserNotificationCenter.current()
        let calendar = Calendar.current
        let now = Date()
        let saleBase = concert.saleDate ?? concert.date

        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        timeFormatter.dateFormat = "HH:mm"
        let saleTimeString = timeFormatter.string(from: saleBase)

        for offset in reminderOffsets where concert.reminders.contains(offset.label) {
            guard let triggerDate = calendar.date(byAdding: offset.component, value: offset.value, to: saleBase),
                  triggerDate > now else { continue }
            let content = UNMutableNotificationContent()
            content.title = offset.title
            content.body = "В \(saleTimeString) старт продаж на \(concert.artist). Не пропусти!"
            content.sound = .default
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: triggerDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: notificationIdentifier(for: concert, suffix: offset.label), content: content, trigger: trigger)
            center.add(request)
        }

        if concert.remindAfterConcert {
            var components = calendar.dateComponents([.year, .month, .day], from: concert.date)
            components.hour = 23
            components.minute = 40
            if let triggerDate = calendar.date(from: components), triggerDate > now {
                let content = UNMutableNotificationContent()
                content.title = "Как прошёл концерт?"
                content.body = "Запиши впечатление, пока эмоции свежие"
                content.sound = .default
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(identifier: notificationIdentifier(for: concert, suffix: "after"), content: content, trigger: trigger)
                center.add(request)
            }
        }
    }
}
