import SwiftUI

/// Список уроков модуля + выбор режима + запуск упражнения.
struct LessonListScreen: View {
    let moduleID: String
    let title: String
    let progress: ProgressStore

    @State private var module: Module?
    @State private var loadError: String?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let module {
                inner(module: module)
            } else if isLoading {
                VStack(spacing: 8) {
                    ProgressView().tint(Term.green)
                    Text("загрузка модуля...")
                        .font(Term.mono())
                        .foregroundStyle(Term.dim)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let loadError {
                ScrollView {
                    ErrorBlockView(message: loadError).padding()
                    Button {
                        Task { await load() }
                    } label: {
                        TermButtonLabel(title: "[ ПОВТОРИТЬ СОЕДИНЕНИЕ ]")
                    }
                    .padding(.horizontal)
                }
            } else {
                Color.clear
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .background(Term.bg)
        .task { await load() }
    }

    private func inner(module: Module) -> some View {
        List {
            if let intro = module.storyIntro?.text, !intro.isEmpty {
                Section {
                    Text(intro)
                        .font(Term.mono(12))
                        .foregroundStyle(Term.dim)
                        .textSelection(.enabled)
                        .listRowBackground(Term.bg)
                }
            }
            Section {
                ForEach(module.lessons) { lesson in
                    NavigationLink {
                        LessonScreen(module: module, lessonID: lesson.lessonID, progress: progress)
                    } label: {
                        LessonRow(lesson: lesson, progress: progress)
                    }
                    .listRowBackground(Term.bg)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Term.bg)
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            module = try await APIClient().module(id: moduleID)
            loadError = nil
        } catch {
            loadError = "МОДУЛЬ НЕДОСТУПЕН\n\(error.localizedDescription)"
        }
    }
}

struct LessonRow: View {
    let lesson: Lesson
    let progress: ProgressStore

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: progress.isLessonDone(lesson.lessonID) ? "checkmark.square" : "square")
                .foregroundStyle(progress.isLessonDone(lesson.lessonID) ? Term.green : Term.dim)
                .font(.system(size: 14))
            VStack(alignment: .leading, spacing: 2) {
                Text(lesson.lessonID)
                    .font(Term.mono(14))
                    .foregroundStyle(Term.paper)
                HStack(spacing: 8) {
                    ForEach(sortedModeKeys(lesson), id: \.self) { mode in
                        Text(mode)
                            .font(Term.mono(10))
                            .foregroundStyle(progress.isCompleted(lessonID: lesson.lessonID, mode: mode) ? Term.green : Term.dim)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .strokeBorder(Term.border, lineWidth: 1)
                            )
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func sortedModeKeys(_ lesson: Lesson) -> [String] {
        let preferred = ["script_kiddie", "console_cowboy"]
        let known = preferred.filter { lesson.modes[$0] != nil }
        let rest = lesson.modes.keys.filter { !preferred.contains($0) }.sorted()
        return known + rest
    }
}
