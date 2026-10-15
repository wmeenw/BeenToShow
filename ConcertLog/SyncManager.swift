import Foundation

/// Синхронизация концертов с Supabase. Работает вне главного потока (actor).
///
/// Использование из ConcertStore (async):
///   - после add/update:  `await SyncManager.shared.push(concert)`
///   - после delete:      `await SyncManager.shared.delete(concert)`
///   - при входе/запуске: `let r = try await SyncManager.shared.pullAll(local: concerts)`; затем `concerts = r.concerts; save()`
///   - при выходе:        `await SyncManager.shared.reset()`
///
/// Офлайн-правки попадают в очередь (UserDefaults) и отправляются при следующем push/pullAll/flushPending.
actor SyncManager {
    static let shared = SyncManager()

    struct PullResult: Sendable {
        /// Итоговый список концертов (локальные + удалённые, объединённые по id).
        let concerts: [Concert]
        /// Локальные концерты, удалённые на другом устройстве (их файлы можно стереть).
        let removed: [Concert]
        /// Сколько медиафайлов не удалось скачать (повторится при следующем pullAll).
        let failedMedia: Int
        /// Остались ли неотправленные изменения.
        let hasPending: Bool
        /// Версии с сервера, которые вызывающий код применит локально; после применения нужно
        /// вызвать `confirmAdopted`, иначе отметки не ставятся и версия подтянется снова.
        let adopted: [UUID: Date]
    }

    struct PendingOp: Codable, Sendable {
        enum Kind: String, Codable, Sendable { case upsert, delete }
        var kind: Kind
        var id: UUID
        /// JSON концерта (для upsert).
        var data: Data?
        /// Момент правки; уходит как updated_at.
        var at: Date
        /// Файлы концерта (для delete: удалить из хранилища).
        var mediaNames: [String] = []
    }

    private let client: SupabaseClient
    private let defaults: UserDefaults
    private let documents: URL
    private var flushTask: Task<Bool, Never>?
    /// Растёт при каждом reset(): незавершённые операции старой эпохи ничего не сохраняют.
    private var epoch = 0
    /// Поколение ConcertStore: операции из более старого поколения (до выхода из аккаунта) отбрасываются.
    private var minGeneration = 0

    private enum Key {
        static let pending = "sync.pending"
        static let modified = "sync.modified"
        static let uploaded = "sync.uploadedMedia"
        static let owner = "sync.owner"
        static let dead = "sync.deadLetters"
    }

    init(client: SupabaseClient = .shared, defaults: UserDefaults = .standard, documents: URL = URL.documentsDirectory) {
        self.client = client
        self.defaults = defaults
        self.documents = documents
    }

    // MARK: Публичный API

    var pendingCount: Int { loadPending().count }
    var hasPending: Bool { !loadPending().isEmpty }
    /// Сколько изменений сервер отклонил насовсем (их повтор не поможет).
    var failedCount: Int { loadDead().count }

    /// Чьи данные лежат на устройстве (nil - данных без владельца нет).
    func ownerMismatch(for userID: String) -> Bool {
        guard let owner = defaults.string(forKey: Key.owner) else { return false }
        return owner != userID
    }

    func claim(userID: String) {
        defaults.set(userID, forKey: Key.owner)
    }

    /// Запоминает правку в очереди (даже без сессии) и пытается отправить сразу, если вошли.
    func push(_ concert: Concert, generation: Int = 0) async {
        guard generation >= minGeneration else { return }
        guard let data = try? JSONEncoder().encode(concert) else { return }
        let now = Date()
        var modified = loadModified()
        modified[concert.id.uuidString] = now.timeIntervalSince1970
        saveModified(modified)
        enqueue(PendingOp(kind: .upsert, id: concert.id, data: data, at: now))
        if await claimOwnership() { _ = await flushPending() }
    }

    /// Ставит удаление в очередь и пытается выполнить сразу. Локальные файлы здесь не трогаем.
    func delete(_ concert: Concert, generation: Int = 0) async {
        guard generation >= minGeneration else { return }
        var modified = loadModified()
        modified[concert.id.uuidString] = nil
        saveModified(modified)
        enqueue(PendingOp(kind: .delete, id: concert.id, data: nil, at: Date(),
                          mediaNames: (concert.photoNames + concert.videoNames).filter(MediaName.isSafe)))
        if await claimOwnership() { _ = await flushPending() }
    }

    /// Отправляет накопленные изменения. Возвращает true, если очередь пуста. Безопасно вызывать повторно:
    /// если отправка уже идёт, ждёт её завершения и затем сама добирает новое.
    @discardableResult
    func flushPending() async -> Bool {
        while let running = flushTask { _ = await running.value }
        let task = Task { () -> Bool in
            let result = await self.runFlush()
            self.flushTask = nil
            return result
        }
        flushTask = task
        return await task.value
    }

    private func runFlush() async -> Bool {
        guard await client.currentSession != nil else { return loadPending().isEmpty }
        let startEpoch = epoch
        while let op = loadPending().first {
            do {
                try await perform(op)
                guard epoch == startEpoch else { return false }
                removePending(id: op.id, at: op.at)
            } catch {
                guard epoch == startEpoch else { return false }
                if let backend = error as? BackendError, backend.isPermanent {
                    // Сервер никогда это не примет: убираем в «мёртвые», чтобы не блокировать остальное.
                    addDead(op)
                    removePending(id: op.id, at: op.at)
                    continue
                }
                // Нет сети / нет сессии / временная ошибка сервера: оставляем в очереди и пробуем позже.
                return false
            }
        }
        return true
    }

    /// Забирает все концерты с сервера, скачивает недостающие медиа и объединяет с локальными.
    /// Бросает ошибку при сбое сети - тогда вызывающий код ничего не меняет в локальных данных.
    func pullAll(local: [Concert], generation: Int = 0) async throws -> PullResult {
        guard generation >= minGeneration else { throw CancellationError() }
        guard await claimOwnership() else { throw BackendError.notSignedIn }
        let startEpoch = epoch
        _ = await flushPending()
        let remoteRows = try await client.fetchConcerts()
        try Task.checkCancellation()
        guard epoch == startEpoch else { throw CancellationError() }

        // Снимок состояния на момент слияния; после загрузок файлов он перечитывается.
        let snapPending = loadPending()
        let snapModified = loadModified()
        let pendingDeletes = Set(snapPending.filter { $0.kind == .delete }.map(\.id))
        let pendingUpserts = Set(snapPending.filter { $0.kind == .upsert }.map(\.id))

        var remote: [(concert: Concert, updatedAt: Date)] = []
        var tombstones: [UUID: Date] = [:]
        // Строки на сервере, которые не удалось разобрать: поверх них локальную копию не отправляем.
        var undecodable = Set<UUID>()
        for row in remoteRows where !pendingDeletes.contains(row.id) {
            if row.isDeleted { tombstones[row.id] = row.updatedAt; continue }
            if var concert = try? JSONDecoder().decode(Concert.self, from: row.data) {
                concert.photoNames = concert.photoNames.filter(MediaName.isSafe)
                concert.videoNames = concert.videoNames.filter(MediaName.isSafe)
                remote.append((concert, row.updatedAt))
            } else {
                undecodable.insert(row.id)
            }
        }

        let merged = Self.merge(local: local, remote: remote, modified: snapModified, pendingUpserts: pendingUpserts, tombstones: tombstones)

        // Скачиваем недостающие файлы.
        var downloadedFiles: [URL] = []
        var downloadedNames = Set<String>()
        var failed = 0
        for concert in merged.concerts {
            for name in concert.photoNames + concert.videoNames {
                guard MediaName.isSafe(name) else { continue }
                let dest = documents.appending(path: name)
                if FileManager.default.fileExists(atPath: dest.path) { continue }
                do {
                    try await client.downloadMedia(name: name, to: dest)
                    downloadedFiles.append(dest)
                    downloadedNames.insert(name)
                } catch {
                    failed += 1
                }
                if Task.isCancelled || epoch != startEpoch {
                    // Вышли из аккаунта: свежескачанное чужое медиа не оставляем.
                    for url in downloadedFiles { try? FileManager.default.removeItem(at: url) }
                    throw CancellationError()
                }
            }
        }
        if !downloadedNames.isEmpty { saveUploaded(loadUploaded().union(downloadedNames)) }

        // После всех await перечитываем состояние: пользователь мог править концерты, пока мы качали.
        let freshPending = loadPending()
        var freshModified = loadModified()
        func opSignature(_ list: [PendingOp], _ id: UUID) -> String {
            list.filter { $0.id == id }.map { "\($0.kind.rawValue)@\($0.at.timeIntervalSince1970)" }.joined(separator: ",")
        }
        func changedMeanwhile(_ id: UUID) -> Bool {
            freshModified[id.uuidString] != snapModified[id.uuidString]
                || opSignature(freshPending, id) != opSignature(snapPending, id)
        }

        var finalConcerts = merged.concerts
        var removed: [Concert] = []
        for concert in merged.removed {
            if changedMeanwhile(concert.id) { finalConcerts.append(concert) } else { removed.append(concert) }
        }
        // Версии с сервера, поверх которых пользователь успел что-то поменять, не применяем.
        var adopted: [UUID: Date] = [:]
        for (id, date) in merged.adoptedRemote where !changedMeanwhile(id) { adopted[id] = date }

        // Локальные, которых нет на сервере или которые новее, отправляем.
        for concert in merged.toPush where !undecodable.contains(concert.id) && !changedMeanwhile(concert.id) {
            guard let data = try? JSONEncoder().encode(concert) else { continue }
            let at = freshModified[concert.id.uuidString].map { Date(timeIntervalSince1970: $0) } ?? Date()
            if freshModified[concert.id.uuidString] == nil { freshModified[concert.id.uuidString] = at.timeIntervalSince1970 }
            enqueue(PendingOp(kind: .upsert, id: concert.id, data: data, at: at))
        }
        guard epoch == startEpoch else { throw CancellationError() }
        saveModified(freshModified)
        let flushed = await flushPending()

        return PullResult(concerts: finalConcerts, removed: removed, failedMedia: failed,
                          hasPending: !flushed, adopted: adopted)
    }

    /// Вызывается после того, как версии с сервера применены локально: ставит отметки «совпадает с сервером».
    func confirmAdopted(_ adopted: [UUID: Date], generation: Int = 0) {
        guard generation >= minGeneration, !adopted.isEmpty else { return }
        var modified = loadModified()
        let busy = Set(loadPending().map(\.id))
        for (id, date) in adopted where !busy.contains(id) {
            modified[id.uuidString] = date.timeIntervalSince1970
        }
        saveModified(modified)
    }

    /// Сбрасывает очередь и служебные данные (при выходе из аккаунта).
    func reset(minGeneration newMin: Int = 0) {
        epoch += 1
        minGeneration = max(minGeneration, newMin)
        flushTask?.cancel()
        for key in [Key.pending, Key.modified, Key.uploaded, Key.owner, Key.dead] { defaults.removeObject(forKey: key) }
    }

    // MARK: Слияние (чистая функция)

    struct MergeOutcome: Sendable {
        var concerts: [Concert]
        var toPush: [Concert]
        var adoptedRemote: [UUID: Date]
        /// Локальные концерты, которые удалены на сервере (надгробие новее).
        var removed: [Concert] = []
    }

    /// Объединение по id. Для одинакового id побеждает более новая версия (удалённая - по updated_at,
    /// локальная - по времени последней правки; если локальной отметки нет, побеждает удалённая).
    nonisolated static func merge(local: [Concert], remote: [(concert: Concert, updatedAt: Date)],
                                  modified: [String: Double], pendingUpserts: Set<UUID> = [],
                                  tombstones: [UUID: Date] = [:],
                                  tolerance: TimeInterval = 0.5) -> MergeOutcome {
        var result: [Concert] = []
        var toPush: [Concert] = []
        var adopted: [UUID: Date] = [:]
        var removed: [Concert] = []
        let remoteByID = Dictionary(remote.map { ($0.concert.id, $0) }, uniquingKeysWith: { a, b in a.updatedAt >= b.updatedAt ? a : b })
        var seen = Set<UUID>()

        for concert in local {
            guard seen.insert(concert.id).inserted else { continue }
            if let t = tombstones[concert.id], remoteByID[concert.id] == nil {
                let localTime = modified[concert.id.uuidString].map { Date(timeIntervalSince1970: $0) } ?? .distantPast
                if !pendingUpserts.contains(concert.id), t.timeIntervalSince(localTime) > tolerance {
                    removed.append(concert)
                    continue
                }
            }
            guard let r = remoteByID[concert.id] else {
                result.append(concert)
                toPush.append(concert)
                continue
            }
            let localTime = modified[concert.id.uuidString].map { Date(timeIntervalSince1970: $0) } ?? .distantPast
            if pendingUpserts.contains(concert.id) || localTime.timeIntervalSince(r.updatedAt) > tolerance {
                result.append(concert)
                toPush.append(concert)
            } else if r.updatedAt.timeIntervalSince(localTime) > tolerance {
                result.append(r.concert)
                adopted[concert.id] = r.updatedAt
            } else {
                result.append(concert)
            }
        }
        for r in remote.sorted(by: { $0.updatedAt < $1.updatedAt }) where !seen.contains(r.concert.id) {
            seen.insert(r.concert.id)
            result.append(remoteByID[r.concert.id]?.concert ?? r.concert)
            adopted[r.concert.id] = remoteByID[r.concert.id]?.updatedAt ?? r.updatedAt
        }
        return MergeOutcome(concerts: result, toPush: toPush, adoptedRemote: adopted, removed: removed)
    }

    // MARK: Внутреннее

    private func perform(_ op: PendingOp) async throws {
        switch op.kind {
        case .upsert:
            guard let data = op.data else { return }
            if let concert = try? JSONDecoder().decode(Concert.self, from: data) {
                var uploaded = loadUploaded()
                for name in concert.photoNames + concert.videoNames where !uploaded.contains(name) && MediaName.isSafe(name) {
                    let file = documents.appending(path: name)
                    guard FileManager.default.fileExists(atPath: file.path) else { continue }
                    do {
                        try await client.uploadMedia(name: name, fileURL: file)
                    } catch let error as BackendError where error.isPermanent {
                        // Файл сервер не принял (например, слишком большой): текст концерта всё равно отправим.
                        continue
                    }
                    uploaded.insert(name)
                    saveUploaded(loadUploaded().union([name]))
                }
            }
            try await client.upsertConcert(id: op.id, data: data, updatedAt: op.at)
        case .delete:
            try await client.deleteConcert(id: op.id, at: op.at)
            for name in op.mediaNames where MediaName.isSafe(name) { try? await client.deleteMedia(name: name) }
            var uploaded = loadUploaded()
            uploaded.subtract(op.mediaNames)
            saveUploaded(uploaded)
        }
    }

    /// Можно ли работать с сервером от имени текущей сессии. Чужие данные (владелец другой) не отправляем:
    /// их стирает приложение при входе (см. ownerMismatch), здесь только страховка.
    private func claimOwnership() async -> Bool {
        guard let session = await client.currentSession else { return false }
        if let owner = defaults.string(forKey: Key.owner), owner != session.userID { return false }
        defaults.set(session.userID, forKey: Key.owner)
        return true
    }

    private func enqueue(_ op: PendingOp) {
        var list = loadPending().filter { $0.id != op.id }
        list.append(op)
        savePending(list)
        // Новая правка заменяет отклонённую раньше.
        let dead = loadDead()
        if dead.contains(where: { $0.id == op.id }) { saveDead(dead.filter { $0.id != op.id }) }
    }

    private func loadDead() -> [PendingOp] {
        guard let data = defaults.data(forKey: Key.dead) else { return [] }
        return (try? JSONDecoder().decode([PendingOp].self, from: data)) ?? []
    }

    private func saveDead(_ list: [PendingOp]) {
        if let data = try? JSONEncoder().encode(list) { defaults.set(data, forKey: Key.dead) }
    }

    private func addDead(_ op: PendingOp) {
        saveDead(loadDead().filter { $0.id != op.id } + [op])
    }

    /// Удаляет операцию, только если её не заменили более новой за время отправки.
    private func removePending(id: UUID, at: Date) {
        savePending(loadPending().filter { !($0.id == id && $0.at == at) })
    }

    private func loadPending() -> [PendingOp] {
        guard let data = defaults.data(forKey: Key.pending) else { return [] }
        return (try? JSONDecoder().decode([PendingOp].self, from: data)) ?? []
    }

    private func savePending(_ list: [PendingOp]) {
        if let data = try? JSONEncoder().encode(list) { defaults.set(data, forKey: Key.pending) }
    }

    private func loadModified() -> [String: Double] {
        (defaults.dictionary(forKey: Key.modified) as? [String: Double]) ?? [:]
    }

    private func saveModified(_ m: [String: Double]) { defaults.set(m, forKey: Key.modified) }

    private func loadUploaded() -> Set<String> {
        Set(defaults.stringArray(forKey: Key.uploaded) ?? [])
    }

    private func saveUploaded(_ s: Set<String>) { defaults.set(Array(s), forKey: Key.uploaded) }
}
