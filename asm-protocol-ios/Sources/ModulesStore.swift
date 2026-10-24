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
    var sections: [ModuleSection] { Self.sections(for: modules) }

    /// Известные треки — в порядке `Track.allCases`; неизвестные tier (новый трек на сервере)
    /// не выбрасываются, а идут в хвост, по алфавиту tier.
    nonisolated static func sections(for modules: [ModuleSummary]) -> [ModuleSection] {
        let byTier = Dictionary(grouping: modules) { $0.tier }
        let sorted: (String) -> [ModuleSummary] = { tier in
            (byTier[tier] ?? []).sorted { $0.module < $1.module }
        }
        let known = Track.allCases
            .filter { byTier[$0.rawValue] != nil }
            .map { ModuleSection(id: $0.rawValue, title: $0.title, subtitle: $0.subtitle,
                                 modules: sorted($0.rawValue)) }
        let unknown = byTier.keys
            .filter { Track(rawValue: $0) == nil }
            .sorted()
            .map { ModuleSection(id: $0, title: $0.uppercased(), subtitle: "новый трек: \($0)",
                                 modules: sorted($0)) }
        return known + unknown
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

/// Секция главного экрана: трек и его модули.
struct ModuleSection: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let modules: [ModuleSummary]
}
