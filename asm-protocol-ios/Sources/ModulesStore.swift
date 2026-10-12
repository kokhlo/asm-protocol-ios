import Foundation
import Observation

/// Загрузка списка модулей с группировкой по трекам.
@Observable
@MainActor
final class ModulesStore {
    private(set) var modules: [ModuleSummary] = []
    private(set) var isLoading = false
    var loadError: String?

    private let api: APIClient

    init(api: APIClient = APIClient()) {
        self.api = api
    }

    /// Модули, сгруппированные по tier в каноническом порядке треков.
    var grouped: [(track: Track, modules: [ModuleSummary])] {
        let byTier = Dictionary(grouping: modules) { $0.tier }
        return Track.allCases
            .filter { byTier[$0.rawValue] != nil }
            .map { track in
                let mods = (byTier[track.rawValue] ?? []).sorted { $0.module < $1.module }
                return (track, mods)
            }
    }

    func loadIfNeeded() async {
        guard modules.isEmpty else { return }
        await reload()
    }

    func reload() async {
        isLoading = true
        defer { isLoading = false }
        do {
            modules = try await api.modules()
            loadError = nil
        } catch {
            loadError = "СОЕДИНЕНИЕ РАЗОРВАНО\n\(error.localizedDescription)"
        }
    }
}
