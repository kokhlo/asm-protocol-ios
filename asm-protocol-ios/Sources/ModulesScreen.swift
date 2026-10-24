import SwiftUI

/// Корневой экран: треки → модули.
struct ModulesScreen: View {
    @State private var store = ModulesStore()
    @State private var progress = ProgressStore()
    @State private var path: [ModuleSummary] = []

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle("ASM://PROTOCOL")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        if store.isLoading {
                            ProgressView().tint(Term.green)
                        } else {
                            Button {
                                Task { await store.reload() }
                            } label: {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundStyle(Term.dim)
                            }
                        }
                    }
                }
        }
        .preferredColorScheme(.dark)
        .tint(Term.green)
        .task {
            await store.loadIfNeeded()
            await progress.bootstrap()
        }
    }

    @ViewBuilder
    private var content: some View {
        if let error = store.loadError, store.modules.isEmpty {
            ScrollView {
                ErrorBlockView(message: error)
                    .padding()
                Button {
                    Task { await store.reload() }
                } label: {
                    TermButtonLabel(title: "[ ПОВТОРИТЬ СОЕДИНЕНИЕ ]")
                }
                .padding(.horizontal)
            }
        } else if store.modules.isEmpty && store.isLoading {
            Spacer()
            VStack(spacing: 8) {
                Text("установка соединения...")
                    .font(Term.mono())
                    .foregroundStyle(Term.dim)
                ProgressView().tint(Term.green)
            }
            Spacer()
        } else {
            list
        }
    }

    private var list: some View {
        List {
            ForEach(store.grouped, id: \.track) { group in
                Section {
                    ForEach(group.modules) { module in
                        NavigationLink(value: module) {
                            ModuleRow(module: module, isDone: progress.isLessonDone)
                        }
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("── \(group.track.title) ──")
                            .font(Term.mono(13, weight: .semibold))
                            .foregroundStyle(Term.amber)
                        Text(group.track.subtitle)
                            .font(Term.mono(11))
                            .foregroundStyle(Term.dim)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Term.bg)
        .navigationDestination(for: ModuleSummary.self) { module in
            LessonListScreen(moduleID: module.id, title: module.title.text, progress: progress)
        }
    }
}

struct ModuleRow: View {
    let module: ModuleSummary
    let isDone: (String) -> Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(String(format: "%02d", module.module))
                    .font(Term.mono(13))
                    .foregroundStyle(Term.dim)
                Text(module.title.text)
                    .font(Term.mono(15, weight: .medium))
                    .foregroundStyle(Term.paper)
            }
            Text(module.description.text)
                .font(Term.mono(12))
                .foregroundStyle(Term.dim)
                .lineLimit(2)
            HStack(spacing: 16) {
                Text("уроков: \(module.lessonsCount)")
                Text("id: \(module.id)")
            }
            .font(Term.mono(11))
            .foregroundStyle(Term.dim.opacity(0.8))
        }
        .padding(.vertical, 2)
    }
}
