import Foundation

public enum StudyCategory: String, Codable, CaseIterable {
    case reading, practice, project
}

public enum StudyPlanError: Error, Equatable {
    case blankTitle
    case nonPositiveEstimatedMinutes
    case duplicateID(String)
    case unknownID(String)
}

public struct StudyItem: Codable, Equatable {
    public let id: String
    public let title: String
    public let estimatedMinutes: Int
    public let category: StudyCategory
    public private(set) var isCompleted: Bool

    public init(
        id: String,
        title: String,
        estimatedMinutes: Int,
        category: StudyCategory,
        isCompleted: Bool = false
    ) throws {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw StudyPlanError.blankTitle
        }
        guard estimatedMinutes > 0 else {
            throw StudyPlanError.nonPositiveEstimatedMinutes
        }
        self.id = id
        self.title = title
        self.estimatedMinutes = estimatedMinutes
        self.category = category
        self.isCompleted = isCompleted
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, estimatedMinutes, category, isCompleted
    }

    /// Decodes through the validating initializer so invalid JSON cannot bypass validation.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: container.decode(String.self, forKey: .id),
            title: container.decode(String.self, forKey: .title),
            estimatedMinutes: container.decode(Int.self, forKey: .estimatedMinutes),
            category: container.decode(StudyCategory.self, forKey: .category),
            isCompleted: container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        )
    }

    fileprivate mutating func markCompleted() {
        isCompleted = true
    }
}

public struct StudyPlan: Codable, Equatable {
    public private(set) var items: [StudyItem]

    public init(items: [StudyItem]) throws {
        var seenIDs = Set<String>()
        for item in items where !seenIDs.insert(item.id).inserted {
            throw StudyPlanError.duplicateID(item.id)
        }
        // Sort by title A–Z; when two titles are equal, sort those items by ID.
        self.items = items.sorted { firstItem, secondItem in
            if firstItem.title != secondItem.title {
                return firstItem.title < secondItem.title
            }
            return firstItem.id < secondItem.id
        }
    }

    private enum CodingKeys: String, CodingKey {
        case items
    }

    /// Decodes `{"items": [...]}` through the validating initializer.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(items: container.decode([StudyItem].self, forKey: .items))
    }

    /// Decodes a top-level JSON array of study items.
    public static func decode(from data: Data) throws -> StudyPlan {
        try StudyPlan(items: JSONDecoder().decode([StudyItem].self, from: data))
    }

    public func items(in category: StudyCategory) -> [StudyItem] {
        items.filter { $0.category == category }
    }

    public func incompleteMinutes() -> Int {
        items.filter { !$0.isCompleted }.reduce(0) { $0 + $1.estimatedMinutes }
    }

    public mutating func markCompleted(id: String) throws {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            throw StudyPlanError.unknownID(id)
        }
        items[index].markCompleted()
    }

    public mutating func importMerging(_ importedItems: [StudyItem]) throws {
        // Optional bonus intentionally not implemented. Throws instead of crashing
        // so a test run that calls it cannot abort the whole test process.
        throw StudyPlanError.unknownID("importMerging is not implemented")
    }
}
