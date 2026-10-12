import Foundation

/// Порядок треков (tier) на главном экране.
enum Track: String, CaseIterable, Identifiable {
    case prologue, asm, c, cpp, ada, sys

    var id: String { rawValue }

    var title: String {
        switch self {
        case .prologue: return "ПРОЛОГ"
        case .asm: return "ASM"
        case .c: return "C"
        case .cpp: return "C++"
        case .ada: return "ADA"
        case .sys: return "SYS"
        }
    }

    /// Неизвестный tier не должен ронять список — он попадёт в хвост.
    var order: Int { Self.allCases.firstIndex(of: self) ?? Self.allCases.count }
}

extension ModuleSummary {
    var track: Track? { Track(rawValue: tier) }
}
