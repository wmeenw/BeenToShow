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

    func add(artist: String, city: String, date: Date, rating: Double, comment: String, tags: [String] = [], photoDatas: [Data] = [], saleDate: Date? = nil, reminders: [String] = [], remindAfterConcert: Bool = false) {
        let newConcert = Concert(
            artist: artist,
            city: city,
            date: date,
            rating: rating < 0.05 ? nil : rating,
            tags: tags,
            comment: comment.isEmpty ? nil : comment,
            photoNames: writePhotos(photoDatas),
            saleDate: saleDate,
            reminders: reminders,
            remindAfterConcert: remindAfterConcert
        )
        concerts.append(newConcert)
        save()
        scheduleNotifications(for: newConcert)
    }

    func update(_ old: Concert, artist: String, city: String, date: Date, rating: Double, comment: String, tags: [String], keptPhotoNames: [String]? = nil, newPhotoDatas: [Data] = [], saleDate: Date?, reminders: [String], remindAfterConcert: Bool) {
        guard let index = concerts.firstIndex(where: { $0.id == old.id }) else { return }
        let existingNames = concerts[index].photoNames
        let namesToKeep = keptPhotoNames ?? existingNames
        let removedNames = Set(existingNames).subtracting(namesToKeep)
        for name in removedNames {
            try? FileManager.default.removeItem(at: URL.documentsDirectory.appending(path: name))
        }
        let finalNames = namesToKeep + writePhotos(newPhotoDatas)
        let updatedConcert = Concert(
            id: old.id,
            artist: artist,
            city: city,
            date: date,
            rating: rating < 0.05 ? nil : rating,
            tags: tags,
            comment: comment.isEmpty ? nil : comment,
            photoNames: finalNames,
            saleDate: saleDate,
            reminders: reminders,
            remindAfterConcert: remindAfterConcert
        )
        concerts[index] = updatedConcert
        save()
        scheduleNotifications(for: updatedConcert)
    }

    func delete(_ concert: Concert) {
        for name in concert.photoNames {
            try? FileManager.default.removeItem(at: URL.documentsDirectory.appending(path: name))
        }
        concerts.removeAll { $0.id == concert.id }
        save()
        cancelNotifications(for: concert)
    }

    func deleteAll() {
        for concert in concerts {
            for name in concert.photoNames {
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
