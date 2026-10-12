import Foundation

// MARK: - Локализуемый контент уроков (ru — базовый, en — опциональный)

struct LocalizedText: Codable, Hashable {
    let ru: String?
    let en: String?

    var text: String { ru ?? en ?? "" }

    init(ru: String? = nil, en: String? = nil) {
        self.ru = ru
        self.en = en
    }

    init(_ ru: String) {
        self.ru = ru
        self.en = nil
    }
}

// MARK: - Curriculum

struct ModulesResponse: Codable {
    let modules: [ModuleSummary]
}

struct ModuleSummary: Codable, Identifiable, Hashable {
    let id: String
    let module: Int
    let tier: String
    let title: LocalizedText
    let description: LocalizedText
    let icon: String?
    let lessonsCount: Int

    enum CodingKeys: String, CodingKey {
        case id, module, tier, title, description, icon
        case lessonsCount = "lessons_count"
    }
}

struct Module: Codable, Identifiable, Hashable {
    let id: String
    let module: Int
    let tier: String
    let title: LocalizedText
    let description: LocalizedText
    let storyIntro: LocalizedText?
    let prerequisites: [String]?
    let lessons: [Lesson]

    enum CodingKeys: String, CodingKey {
        case id, module, tier, title, description, lessons, prerequisites
        case storyIntro = "story_intro"
    }
}

struct Lesson: Codable, Identifiable, Hashable {
    let lessonID: String
    let modes: [String: Exercise]
    let skills: [String]?

    var id: String { lessonID }

    enum CodingKeys: String, CodingKey {
        case modes, skills
        case lessonID = "lesson_id"
    }
}

/// Упражнение. Поля зависят от типа, поэтому почти все опциональны —
/// интерпретация по `type` (choose/predict/translate → options+answer_index,
/// order → items, fill/trace/write → accepted).
struct Exercise: Codable, Hashable {
    let type: String
    let prompt: LocalizedText
    let intro: LocalizedText?
    let options: [LocalizedText]?
    let answerIndex: Int?
    let codeLines: [String]?
    let items: [LocalizedText]?
    let accepted: [String]?
    let hint: LocalizedText?
    let explanation: LocalizedText?

    enum CodingKeys: String, CodingKey {
        case type, prompt, intro, options, items, accepted, hint, explanation
        case answerIndex = "answer_index"
        case codeLines = "code_lines"
    }

    enum Kind: String {
        case choose, predict, translate, order, fill, trace, write
    }

    var kind: Kind? { Kind(rawValue: type) }
}

// MARK: - Skills

struct SkillsResponse: Codable {
    let skills: [Skill]
}

struct Skill: Codable, Identifiable, Hashable {
    let id: String
    let title: LocalizedText
    let domain: String
}

// MARK: - Progress

struct ProgressDocument: Codable, Equatable {
    let done: [String: [String]]
    let position: ProgressPosition?
    let serverRevision: Int

    enum CodingKeys: String, CodingKey {
        case done, position
        case serverRevision = "server_revision"
    }
}

/// Контракт сервера: position == {moduleId: String, lesson: Int >= 1} или null.
struct ProgressPosition: Codable, Hashable {
    let moduleId: String
    let lesson: Int
}

struct PutProgressBody: Codable, Equatable {
    let done: [String: [String]]
    let position: ProgressPosition?
    let clientRevision: Int

    enum CodingKeys: String, CodingKey {
        case done, position
        case clientRevision = "client_revision"
    }
}

struct PutProgressResponse: Codable, Equatable {
    let acceptedRevision: Int
    let serverRevision: Int

    enum CodingKeys: String, CodingKey {
        case acceptedRevision = "accepted_revision"
        case serverRevision = "server_revision"
    }
}
