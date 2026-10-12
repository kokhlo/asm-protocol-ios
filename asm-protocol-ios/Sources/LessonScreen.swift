import SwiftUI

/// Экран упражнения: режим, код, вопрос, ввод ответа, проверка, разбор.
struct LessonScreen: View {
    let module: Module
    let lessonID: String
    let progress: ProgressStore

    @State private var store: LessonStore?

    var body: some View {
        Group {
            if let store {
                LessonContent(store: store)
            } else {
                VStack(spacing: 8) {
                    ProgressView().tint(Term.green)
                    Text("инициализация урока...")
                        .font(Term.mono())
                        .foregroundStyle(Term.dim)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(lessonID)
        .navigationBarTitleDisplayMode(.inline)
        .background(Term.bg)
        .onAppear {
            if store == nil {
                store = LessonStore(module: module, initialLessonID: lessonID, progress: progress)
            }
        }
    }
}

private struct LessonContent: View {
    @Bindable var store: LessonStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                modeSwitcher

                if let exercise = store.exercise {
                    ExerciseView(exercise: exercise, store: store)
                } else {
                    ErrorBlockView(message: "ERR 0x00: БИТЫЙ КОНТЕНТ\nв уроке нет режима \(store.mode)")
                }
            }
            .padding()
        }
        .background(Term.bg)
    }

    private var modeSwitcher: some View {
        HStack(spacing: 10) {
            ForEach(store.availableModes, id: \.self) { m in
                Button {
                    store.selectMode(m)
                } label: {
                    VStack(spacing: 2) {
                        Text(m)
                            .font(Term.mono(13, weight: .medium))
                        if store.isSolved {
                            Text("✓ решено")
                                .font(Term.mono(10))
                                .foregroundStyle(Term.green)
                        }
                    }
                    .foregroundStyle(store.mode == m ? Term.green : Term.dim)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(store.mode == m ? Term.green : Term.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }
}

/// Одно упражнение: вопрос, код, ввод, проверка, вердикт.
struct ExerciseView: View {
    let exercise: Exercise
    @Bindable var store: LessonStore

    @State private var selectedOption: Int?
    @State private var textAnswer: String = ""
    @State private var orderPicks: [Int] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PromptLine(text: store.selectedLesson?.lessonID ?? "")

            if let intro = exercise.intro?.text, !intro.isEmpty {
                Text(intro)
                    .font(Term.mono(13))
                    .foregroundStyle(Term.dim)
                    .textSelection(.enabled)
            }

            if let lines = exercise.codeLines, !lines.isEmpty {
                CodeListingView(lines: lines)
            }

            Text(exercise.prompt.text)
                .font(Term.mono(15))
                .foregroundStyle(Term.paper)
                .textSelection(.enabled)

            switch exercise.kind {
            case .choose, .predict, .translate:
                ChoiceInput
            case .order:
                OrderInput
            case .fill, .trace, .write:
                TextInput
            case nil:
                ErrorBlockView(message: "ERR 0x00: БИТЫЙ КОНТЕНТ\nнеизвестный тип: \(exercise.type)")
            }

            controls

            if let check = store.check {
                verdict(check)
            }

            if store.hintShown, let hint = exercise.hint?.text {
                hintView(hint)
            }
        }
        .panel()
        .onAppear {
            selectedOption = nil
            textAnswer = ""
            orderPicks = []
            if case .choice = store.answer { selectedOption = nil }
        }
    }

    // MARK: - Вводы по типам

    @ViewBuilder
    private var ChoiceInput: some View {
        VStack(spacing: 6) {
            ForEach(Array((exercise.options ?? []).enumerated()), id: \.offset) { pair in
                Button {
                    selectedOption = pair.offset
                    store.setAnswer(.choice(pair.offset))
                } label: {
                    HStack(alignment: .top, spacing: 8) {
                        Text(letters[pair.offset % letters.count])
                            .foregroundStyle(selectedOption == pair.offset ? Term.green : Term.dim)
                        Text(pair.element.text)
                            .foregroundStyle(selectedOption == pair.offset ? Term.green : Term.paper)
                            .multilineTextAlignment(.leading)
                    }
                    .font(Term.mono(14))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(selectedOption == pair.offset ? Term.green.opacity(0.08) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(selectedOption == pair.offset ? Term.green : Term.border, lineWidth: 1)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var OrderInput: some View {
        let items = exercise.items ?? []
        VStack(spacing: 6) {
            // выбранный порядок
            if orderPicks.isEmpty {
                Text("// шаги не выбраны — нажимай по порядку")
                    .font(Term.mono(12))
                    .foregroundStyle(Term.dim)
            } else {
                VStack(spacing: 4) {
                    ForEach(Array(orderPicks.enumerated()), id: \.element) { pair in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(pair.offset + 1).")
                                .foregroundStyle(Term.green)
                            Text(items[pair.element].text)
                                .foregroundStyle(Term.paper)
                        }
                        .font(Term.mono(13))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(8)
                .background(Term.bgCode)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Term.border, lineWidth: 1)
                )
            }
            // пул шагов
            ForEach(Array(items.enumerated()), id: \.element) { pair in
                let picked = orderPicks.contains(pair.offset)
                Button {
                    togglePick(pair.offset)
                } label: {
                    HStack(alignment: .top, spacing: 8) {
                        Text("::")
                            .foregroundStyle(Term.dim)
                        Text(pair.element.text)
                            .foregroundStyle(picked ? Term.dim : Term.paper)
                    }
                    .font(Term.mono(13))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .opacity(picked ? 0.45 : 1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Term.border, lineWidth: 1)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            if !orderPicks.isEmpty {
                Button {
                    orderPicks = []
                    store.setAnswer(.order([]))
                } label: {
                    Text("[ ОЧИСТИТЬ ПОСЛЕДОВАТЕЛЬНОСТЬ ]")
                        .font(Term.mono(12))
                        .foregroundStyle(Term.amber)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
private var TextInput: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("ответ", text: $textAnswer)
                .font(Term.mono(15))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(Term.green)
                .padding(8)
                .overlay(
                    RoundedRectangle(cornerRadius:  traceBorder)
                        .strokeBorder(checkTint, lineWidth: 1)
                )
                .onChange(of: textAnswer) { _, new in
                    store.setAnswer(.text(new))
                }
            Text("// ввод сравнивается с эталоном без учёта регистра")
                .font(Term.mono(11))
                .foregroundStyle(Term.dim)
        }
    }

    private var traceBorder: CGFloat { 6 }

    private var checkTint: Color {
        switch store.check {
        case .correct: return Term.green
        case .wrong: return Term.errorRed
        case nil: return Term.border
        }
    }

    private let letters = ["a)", "b)", "c)", "d)", "e)", "f)"]

    // MARK: - Кнопки и вердикт

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                Task { await store.submit() }
            } label: {
                TermButtonLabel(title: "[ ВЫПОЛНИТЬ ]")
            }
            .buttonStyle(.plain)

            if let hint = exercise.hint, !store.hintShown {
                Button {
                    store.showHint()
                } label: {
                    TermButtonLabel(title: "[ ПОДСКАЗКА ]", accent: Term.amber)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func verdict(_ check: CheckResult) -> some View {
        Group {
            if check.isCorrect {
                SuccessBlockView(explanation: exercise.explanation?.text ?? "Ответ верный.")
            } else if case .wrong(let message) = check {
                ErrorBlockView(message: message)
            }
        }
    }

    private func hintView(_ hint: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("┌─ HINT")
                .foregroundStyle(Term.amber)
            Text(hint)
                .foregroundStyle(Term.paper)
                .textSelection(.enabled)
            Text("└─")
                .foregroundStyle(Term.amber)
        }
        .font(Term.mono(13))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Term.amber.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Term.amber.opacity(0.6), lineWidth: 1)
        )
    }

    private func togglePick(_ index: Int) {
        if let pos = orderPicks.firstIndex(of: index) {
            orderPicks.remove(at: pos)
        } else {
            orderPicks.append(index)
        }
        store.setAnswer(.order(orderPicks))
    }
}
