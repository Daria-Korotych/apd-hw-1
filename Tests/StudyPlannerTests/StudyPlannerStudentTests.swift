import XCTest
@testable import StudyPlanner

final class StudyPlannerStudentTests: XCTestCase {
    private func item(
        _ id: String,
        _ title: String,
        _ minutes: Int = 10,
        _ category: StudyCategory = .reading,
        completed: Bool = false
    ) throws -> StudyItem {
        try StudyItem(id: id, title: title, estimatedMinutes: minutes, category: category, isCompleted: completed)
    }

    // MARK: Validation

    func testZeroAndNegativeMinutesAreRejected() {
        for minutes in [0, -1, -120] {
            XCTAssertThrowsError(
                try StudyItem(id: "x", title: "Valid", estimatedMinutes: minutes, category: .practice)
            ) { error in
                XCTAssertEqual(error as? StudyPlanError, .nonPositiveEstimatedMinutes)
            }
        }
    }

    func testBlankTitleTakesPrecedenceOverInvalidMinutes() {
        XCTAssertThrowsError(
            try StudyItem(id: "x", title: " \t\n", estimatedMinutes: 0, category: .project)
        ) { error in
            XCTAssertEqual(error as? StudyPlanError, .blankTitle)
        }
    }

    func testEmptyTitleIsRejectedWithBlankTitle() {
        XCTAssertThrowsError(
            try StudyItem(id: "x", title: "", estimatedMinutes: 5, category: .reading)
        ) { error in
            XCTAssertEqual(error as? StudyPlanError, .blankTitle)
        }
    }

    // MARK: Duplicates and ordering

    func testFirstDuplicateIDIsReported() throws {
        let items = [
            try item("a", "A"), try item("b", "B"),
            try item("b", "B2"), try item("a", "A2")
        ]
        XCTAssertThrowsError(try StudyPlan(items: items)) { error in
            XCTAssertEqual(error as? StudyPlanError, .duplicateID("b"))
        }
    }

    func testItemsAreOrderedByTitleThenID() throws {
        let plan = try StudyPlan(items: [
            try item("z", "Beta"),
            try item("c", "Alpha"),
            try item("a", "Beta"),
            try item("b", "Alpha")
        ])
        XCTAssertEqual(plan.items.map(\.id), ["b", "c", "a", "z"])
    }

    // MARK: Codable

    func testFixtureDecodesAsTopLevelArray() throws {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "study-items", withExtension: "json", subdirectory: "Fixtures")
        )
        let plan = try StudyPlan.decode(from: Data(contentsOf: url))

        XCTAssertEqual(plan.items.count, 3)
        XCTAssertEqual(plan.incompleteMinutes(), 45 + 90)
        XCTAssertEqual(plan.items(in: .practice).map(\.id), ["collections-drill"])
    }

    func testDecodingInvalidItemThrowsValidationError() {
        let json = Data("""
        [{"id": "x", "title": "   ", "estimatedMinutes": 10, "category": "reading", "isCompleted": false}]
        """.utf8)
        XCTAssertThrowsError(try StudyPlan.decode(from: json)) { error in
            XCTAssertEqual(error as? StudyPlanError, .blankTitle)
        }
    }

    func testKeyedPlanDecodingRejectsDuplicates() {
        let json = Data("""
        {"items": [
          {"id": "a", "title": "A", "estimatedMinutes": 10, "category": "reading", "isCompleted": false},
          {"id": "a", "title": "B", "estimatedMinutes": 20, "category": "project", "isCompleted": false}
        ]}
        """.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(StudyPlan.self, from: json)) { error in
            XCTAssertEqual(error as? StudyPlanError, .duplicateID("a"))
        }
    }

    func testKeyedPlanRoundTripsThroughJSON() throws {
        let plan = try StudyPlan(items: [try item("a", "A", 15, .project, completed: true)])
        let data = try JSONEncoder().encode(plan)
        XCTAssertEqual(try JSONDecoder().decode(StudyPlan.self, from: data), plan)
    }

    // MARK: Queries and completion

    func testCategoryQueryReturnsOnlyMatchingItemsInPlanOrder() throws {
        let plan = try StudyPlan(items: [
            try item("p2", "Drill B", 10, .practice),
            try item("r1", "Read", 10, .reading),
            try item("p1", "Drill A", 10, .practice)
        ])
        XCTAssertEqual(plan.items(in: .practice).map(\.id), ["p1", "p2"])
        XCTAssertTrue(plan.items(in: .project).isEmpty)
    }

    func testMarkCompletedUnknownIDThrowsAndLeavesPlanUnchanged() throws {
        var plan = try StudyPlan(items: [try item("a", "A")])
        let original = plan
        XCTAssertThrowsError(try plan.markCompleted(id: "missing")) { error in
            XCTAssertEqual(error as? StudyPlanError, .unknownID("missing"))
        }
        XCTAssertEqual(plan, original)
    }

    func testMarkCompletedIsIdempotent() throws {
        var plan = try StudyPlan(items: [try item("a", "A", 10), try item("b", "B", 25)])
        try plan.markCompleted(id: "a")
        let afterFirst = plan
        try plan.markCompleted(id: "a")

        XCTAssertEqual(plan, afterFirst)
        XCTAssertEqual(plan.incompleteMinutes(), 25)
    }
}
