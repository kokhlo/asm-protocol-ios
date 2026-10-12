import SwiftUI

/// Терминальная эстетика: тёмный фон, моноширинный шрифт, сигнатурный зелёный.
enum Term {
    static let green = Color(red: 0.29, green: 0.87, blue: 0.51)
    static let dim = Color(white: 0.55)
    static let paper = Color(white: 0.92)
    static let errorRed = Color(red: 0.93, green: 0.26, blue: 0.26)
    static let amber = Color(red: 0.98, green: 0.75, blue: 0.16)
    static let bg = Color.black
    static let bgPanel = Color(white: 0.07)
    static let bgCode = Color(white: 0.04)
    static let border = Color(white: 0.22)

    static func mono(_ size: CGFloat = 15, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

/// Заголовок-приглашение терминала: "guest@asm:~$ ...".
struct PromptLine: View {
    let text: String
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("operator@asm")
                .foregroundStyle(Term.dim)
            Text(":")
            Text(text)
                .foregroundStyle(Term.amber)
            Text("$")
                .foregroundStyle(Term.dim)
        }
        .font(Term.mono())
        .textSelection(.enabled)
    }
}

/// Код листинга: тёмная вставка с построчным нумером.
struct CodeListingView: View {
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(lines.enumerated()), id: \.offset) { pair in
                HStack(alignment: .top, spacing: 8) {
                    Text(String(format: "%02d", pair.offset + 1))
                        .foregroundStyle(Term.dim)
                        .frame(width: 24, alignment: .trailing)
                    Text(pair.element)
                        .foregroundStyle(Term.paper)
                        .textSelection(.enabled)
                }
                .font(Term.mono(14))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Term.bgCode)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Term.border, lineWidth: 1)
        )
    }
}

/// Красный блок ошибки с машинным текстом.
struct ErrorBlockView: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("┌─ FAULT")
                .foregroundStyle(Term.errorRed)
            Text(message)
                .foregroundStyle(Term.errorRed)
            Text("└─")
                .foregroundStyle(Term.errorRed)
        }
        .font(Term.mono(14))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.red.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Term.errorRed, lineWidth: 1)
        )
    }
}

/// Зелёный блок успеха.
struct SuccessBlockView: View {
    let explanation: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("┌─ OK: РЕЗУЛЬТАТ ПРИНЯТ")
                .foregroundStyle(Term.green)
            Text(explanation)
                .foregroundStyle(Term.paper)
                .textSelection(.enabled)
            Text("└─")
                .foregroundStyle(Term.green)
        }
        .font(Term.mono(14))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Term.green.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Term.green.opacity(0.6), lineWidth: 1)
        )
    }
}

/// Универсальная кайса-панель фона.
struct PanelBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(12)
            .background(Term.bgPanel)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Term.border, lineWidth: 1)
            )
    }
}

extension View {
    func panel() -> some View { modifier(PanelBackground()) }
}

/// Кнопка-строка терминала.
struct TermButtonLabel: View {
    let title: String
    var accent: Color = Term.green

    var body: some View {
        Text(title)
            .font(Term.mono(15, weight: .medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundStyle(accent)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(accent.opacity(0.7), lineWidth: 1)
            )
            .contentShape(Rectangle())
    }
}
