//
//  OrderedTests.swift
//  FarewellToUlsterTests
//
//  Created by Michael Scott on 13/05/2026.
//

import Testing
import SwiftData
import UIKit
@testable import FarewellToUlster

class OrderedTests {
    let fetchDescriptor = FetchDescriptor<Poem>(sortBy: [.init(\Poem.fileOrder)])

    @Test func testInsertOrderedWithoutDelete() async throws {
        let storage = try #require(Storage.testStorage(with: "SmallBook"))
        let originalCount = try storage.container.mainContext.fetchCount(fetchDescriptor)
        #expect(originalCount ==  6)
        let newPoem = Poem()
        try storage.insertOrdered(newPoem)
        let newCount = try storage.container.mainContext.fetchCount(fetchDescriptor)
        #expect(newCount ==  7)
        #expect(throws: Never.self) {
            let poems = try storage.container.mainContext.fetch(self.fetchDescriptor)
            #expect(poems.first?.fileOrder == "0001")
            #expect(poems.last?.fileOrder == "0007")
        }
    }
    
    @Test func testInsertOrderedAfterDelete() async throws {
        #expect(throws: Never.self) {
            let storage = try #require(Storage.testStorage(with: "SmallBook"))
            var poems = try storage.container.mainContext.fetch(fetchDescriptor)
            storage.container.mainContext.delete(poems[0])
            try storage.container.mainContext.save()
            let originalCount = try storage.container.mainContext.fetchCount(fetchDescriptor)
            #expect(originalCount == 5)
            let newPoem = Poem()
            try storage.insertOrdered(newPoem)
            let newCount = try storage.container.mainContext.fetchCount(fetchDescriptor)
            #expect(newCount ==  6)
            poems = try storage.container.mainContext.fetch(fetchDescriptor)
            #expect(poems.first?.fileOrder == "0002")
            #expect(poems.last?.fileOrder == "0007")
        }
    }
    
    @Test func testInsertOrderedAlreadyExists() async throws {
        let storage = try #require(Storage.testStorage(with: "SmallBook"))
        #expect(throws: FileOrderedError.alreadyExists) {
            let poems = try storage.container.mainContext.fetch(fetchDescriptor)
            try storage.insertOrdered(poems[0])
        }
    }
    
    @Test func testInsertOrderedParseFailed() async throws {
        let storage = try #require(Storage.testStorage(with: "SmallBook"))
        let poems = try storage.container.mainContext.fetch(fetchDescriptor)
        // Sorts after the numeric values, so it is the one insertOrdered tries to parse.
        poems[0].fileOrder = "abc"
        let error = #expect(throws: FileOrderedError.parseFailed(fileOrder: "abc")) {
            try storage.insertOrdered(Poem())
        }
        #expect(error?.localizedDescription == "Could not parse the file order \"abc\"")
        #expect(try storage.container.mainContext.fetchCount(fetchDescriptor) == 6)
    }

    @Test func testAdd() async throws {
        let storage = try #require(Storage.testStorage(with: "SmallBook"))
        let newPoem = Poem()
        #expect(storage.add(newPoem))
        #expect(storage.addError == nil)
        #expect(newPoem.fileOrder == "0007")
        #expect(try storage.container.mainContext.fetchCount(fetchDescriptor) == 7)
    }

    @Test func testAddFailed() async throws {
        let storage = try #require(Storage.testStorage(with: "SmallBook"))
        let poems = try storage.container.mainContext.fetch(fetchDescriptor)
        poems[0].fileOrder = "abc"
        #expect(!storage.add(Poem()))
        #expect(storage.addError as? FileOrderedError == .parseFailed(fileOrder: "abc"))
        #expect(try storage.container.mainContext.fetchCount(fetchDescriptor) == 6)
    }

    /// insertOrdered sorts on fileOrder in the database, so check that the sort works for every FileOrdered model, not just Poem.
    @Test func testInsertOrderedEveryModel() async throws {
        let storage = try #require(Storage.testStorage(with: "SmallBook"))
        try expectNextFileOrder(Era(), in: storage)
        try expectNextFileOrder(Event(), in: storage)
        try expectNextFileOrder(Subject(sortIndex: 0), in: storage)
        try expectNextFileOrder(Poem(), in: storage)
    }

    private func expectNextFileOrder<T: FileOrdered>(_ model: T, in storage: Storage) throws {
        let existing = try storage.container.mainContext.fetch(FetchDescriptor<T>())
        let highest = existing.compactMap { Int($0.fileOrder) }.max() ?? 0
        try storage.insertOrdered(model)
        #expect(model.fileOrder == String(format: "%04d", highest + 1), "\(T.self)")
    }

    @Test func testInsertOrderedFirstInsert() async throws {
        let storage = try #require(Storage.testStorage(with: "SmallBook"))
        let poems = try storage.container.mainContext.fetch(fetchDescriptor)
        for poem in poems {
            storage.container.mainContext.delete(poem)
        }
        let newPoem = Poem()
        #expect(throws: Never.self) {
            try storage.insertOrdered(newPoem)
        }
        #expect(newPoem.fileOrder == "0001")
    }
}
