//
//  PoemSearchTokenTests.swift
//  FarewellToUlsterTests
//
//  Created by Michael Scott on 13/05/2026.
//

import Testing
@testable import FarewellToUlster

struct PoemSearchTokenTests {

    @Test func testAllCases() async throws {
        #expect(PoemSearchToken.allCases == [.status(.undevelopedIdea), .status(.gettingStarted), .status(.inProgress), .status(.almostFinished), .status(.finished), .status(.duplicate),
                                             .category(.complaint), .category(.descriptive), .category(.ironic), .category(.lament), .category(.lyric), .category(.narrative),
                                             .uncategorised, .noSubjects, .duplicateTitle, .firstLineTitle])
    }

    @Test func testGroupedCases() {
        #expect(PoemSearchToken.statusCases.allSatisfy { if case .status = $0 { true } else { false } })
        #expect(PoemSearchToken.categoryCases.allSatisfy { if case .category = $0 { true } else { false } })
        #expect(PoemSearchToken.otherCases.allSatisfy {
            switch $0 {
            case .status, .category: false
            default: true
            }
        })
    }

    @Test func testRawValue() async throws {
        #expect(PoemSearchToken(rawValue: "") == nil)
        #expect(PoemSearchToken(rawValue: "duplicate title") == .duplicateTitle)
        #expect(PoemSearchToken(rawValue: PoemStatus.undevelopedIdea.rawValue) == PoemSearchToken.status(.undevelopedIdea))
        #expect(PoemSearchToken(rawValue: PoemCategory.narrative.rawValue) == PoemSearchToken.category(.narrative))
    }

    @Test func testFilterStatus() {
        let finished = Poem(title: "Finished")
        finished.status = .finished
        let inProgress = Poem(title: "In progress")
        inProgress.status = .inProgress
        let noStatus = Poem(title: "No status")
        let found = PoemSearchToken.status(.finished).filter([finished, inProgress, noStatus])
        #expect(found.map(\.uuid) == [finished.uuid])
    }

    @Test func testFilterCategory() {
        let lyric = Poem(title: "Lyric")
        lyric.category = .lyric
        let lament = Poem(title: "Lament")
        lament.category = .lament
        let noCategory = Poem(title: "No category")
        let found = PoemSearchToken.category(.lyric).filter([lyric, lament, noCategory])
        #expect(found.map(\.uuid) == [lyric.uuid])
    }

    @Test func testFilterUncategorised() {
        let lyric = Poem(title: "Lyric")
        lyric.category = .lyric
        let noCategory = Poem(title: "No category")
        let found = PoemSearchToken.uncategorised.filter([lyric, noCategory])
        #expect(found.map(\.uuid) == [noCategory.uuid])
    }

    @Test func testFilterNoSubjects() {
        let nilSubjects = Poem(title: "Nil subjects")
        let emptySubjects = Poem(title: "Empty subjects")
        emptySubjects.subjects = []
        let withSubject = Poem(title: "With subject")
        withSubject.subjects = [Subject(title: "Thinking")]
        let found = PoemSearchToken.noSubjects.filter([nilSubjects, emptySubjects, withSubject])
        #expect(found.map(\.uuid) == [nilSubjects.uuid, emptySubjects.uuid])
    }

    @Test func testFilterDuplicateTitle() {
        let first = Poem(title: "Farewell")
        let second = Poem(title: "Farewell")
        // Titles that differ only by case are not duplicates.
        let lowercased = Poem(title: "farewell")
        let unique = Poem(title: "Ulster")
        let found = PoemSearchToken.duplicateTitle.filter([first, unique, lowercased, second])
        #expect(found.map(\.uuid) == [first.uuid, second.uuid])
        #expect(PoemSearchToken.duplicateTitle.filter([unique, lowercased]).isEmpty)
    }

    @Test func testFilterFirstLineTitle() {
        let matching = Poem(title: "The first line", text: "the First Line\nThe second line")
        let different = Poem(title: "A title", text: "The first line\nThe second line")
        let noText = Poem(title: "No text", text: "")
        let found = PoemSearchToken.firstLineTitle.filter([matching, different, noText])
        #expect(found.map(\.uuid) == [matching.uuid])
    }
}
