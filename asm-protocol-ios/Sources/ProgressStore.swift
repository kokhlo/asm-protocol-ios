import Foundation
import Observation

/// Локальный прогресс + синхронизация с progress-API.
/// Каждое решение → clientRevision += 1 → PUT. 409 (стейл-ревизия) → перечитать
/// ревизию сервера и повторить (не более 3 попыток), локальное состояние не теряем.
@Observable
@MainActor
final class ProgressStore {
    private(set) var done: [String: Set<String>] = [:]     // lessonID -> режимы
    private(set) var clientRevision: Int = 0
    private(set) var lastError: String?
    private(set) var isSyncing = false

    /// Уроки, завершённые хотя бы в одном режиме (для галочек в списке).
    var completedLessonIDs: Set<String> { Set(done.keys.filter { !(done[$0] ?? []).isEmpty }) }

    private let api: any ProgressAPI
    private let userKey: String
    private let defaults: UserDefaults

    init(api: any ProgressAPI = APIClient(),
         userKey: String = UserKeyManager.default.loadOrCreate(),
         defaults: UserDefaults = .standard) {
        self.api = api
        self.userKey = userKey
        self.defaults = defaults
        restore()
    }

    // MARK: - Публичное

    /// Загрузить прогресс с сервера при старте (404 — просто нет записи).
    func bootstrap() async {
        isSyncing = true
        defer { isSyncing = false }
        do {
            if let doc = try await api.progress(key: userKey) {
                merge(remote: doc)
            }
        } catch {
            // офлайн-старт — работаем на локальной копии, ошибку не кричим
        }
    }

    /// Зафиксировать решённый урок: локально сразу, на сервер — инкрементом ревизии.
    func recordCompleted(lessonID: String, mode: String) async {
        var modes = done[lessonID] ?? []
        let isNew = !modes.contains(mode)
        modes.insert(mode)
        done[lessonID] = modes
        if isNew {
            clientRevision += 1
            persist()
            await push()
        }
    }

    func isCompleted(lessonID: String, mode: String) -> Bool {
        done[lessonID]?.contains(mode) ?? false
    }

    func isLessonDone(_ lessonID: String) -> Bool {
        !(done[lessonID] ?? []).isEmpty
    }

    // MARK: - Синхронизация

    private func push(attempt: Int = 0) async {
        isSyncing = true
        defer { isSyncing = false }
        let body = PutProgressBody(
            done: done.mapValues { Array($0).sorted() },
            position: nil,
            clientRevision: clientRevision
        )
        do {
            let resp = try await api.putProgress(key: userKey, body: body)
            clientRevision = resp.acceptedRevision
            lastError = nil
            persist()
        } catch let APIError.conflict(serverRevision) {
            guard attempt < 2 else {
                lastError = "КОНФЛИКТ РЕВИЗИЙ\nсервер на ревизии \(serverRevision), прогресс сохранён локально"
                return
            }
            clientRevision = serverRevision + 1
            await push(attempt: attempt + 1)
        } catch {
            lastError = "СИНХРОНИЗАЦИЯ ОТЛОЖЕНА\n\(error.localizedDescription)"
        }
    }

    private func merge(remote: ProgressDocument) {
        guard remote.serverRevision >= clientRevision else { return }
        for (lesson, modes) in remote.done {
            done[lesson] = done[lesson]?.union(modes) ?? Set(modes)
        }
        clientRevision = remote.serverRevision
        persist()
    }

    // MARK: - Локальная персистентность (между запусками до сети)

    private func persist() {
        let flat = done.mapValues { Array($0).sorted() }
        defaults.set(flat, forKey: Self.storageKey)
        defaults.set(clientRevision, forKey: Self.storageKey + ".rev")
    }

    private func restore() {
        if let flat = defaults.dictionary(forKey: Self.storageKey) as? [String: [String]] {
            done = flat.mapValues { Set($0) }
        }
        clientRevision = defaults.integer(forKey: Self.storageKey + ".rev")
    }

    private static let storageKey = "asm-protocol.progress"
}
