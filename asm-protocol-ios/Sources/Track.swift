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
        case .sys: return "СИСТЕМЫ"
        }
    }

    /// Неизвестный tier не должен ронять список — он попадёт в хвост.
    var order: Int { Self.allCases.firstIndex(of: self) ?? Self.allCases.count }

    /// Подзаголовок секции: без него SYS-модули (регистры syscall, ABI) читаются
    /// как продолжение трека ADA, который идёт прямо перед ними.
    var subtitle: String {
        switch self {
        case .prologue: return "вход: как устроена машина"
        case .asm: return "язык: x86-64 ассемблер"
        case .c: return "язык: C"
        case .cpp: return "язык: C++"
        case .ada: return "язык: Ada — типы, контракты, задачи"
        case .sys: return "сквозные темы поверх ASM/C: syscall, линковка, ABI, память"
        }
    }
}

extension ModuleSummary {
    var track: Track? { Track(rawValue: tier) }
}
