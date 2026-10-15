//
//  StorageTests.swift
//  FarewellToUlsterTests
//
//  Created by Michael Scott on 13/05/2026.
//

import Foundation
import Testing
import SwiftData
@testable import FarewellToUlster

struct StorageTests {

    @Test func testEmptyBook() throws {
        let storage = try #require(Storage.testStorage(with: "EmptyBook"))
        let book = try #require(storage.book)
        #expect(book.title == "")
        #expect(book.author == "")
        let eras = storage.eras
        #expect(eras.count == 0)
        let events = storage.events
        #expect(events.count == 0)
        let subjects = storage.subjects
        #expect(subjects.count == 0)
        let poems = storage.poems
        #expect(poems.count == 0)
    }
    
    @Test func testSmallBook() throws {
        let storage = try #require(Storage.testStorage(with: "SmallBook"))
        let book = try #require(storage.book)
        #expect(book.title == "The Blue Dawn")
        #expect(book.author == "Archibald Tumbledown")
        let eras = storage.eras
        #expect(eras.count == 3)
        let events = storage.events
        #expect(events.count == 3)
        let subjects = storage.subjects
        #expect(subjects.count == 3)
        let poems = storage.poems
        #expect(poems.count == 6)
    }

    @Test func testNoBook() throws {
        #expect(Storage.testStorage(with: "NoBook") == nil)
    }

    @Test func testMissingAssetError() throws {
        let bundle = try #require(Bundle(identifier: "org.michaelthscott.FarewellToUlsterTests"))
        let error = try #require(throws: StorageError.self) {
            _ = try Storage(isStoredInMemoryOnly: true, assetName: "DoesNotExist", bundle: bundle)
        }
        guard case .missingAsset(let name) = error else {
            Issue.record("Expected missingAsset, got \(error)")
            return
        }
        #expect(name == "DoesNotExist")
    }

    @Test func testInvalidAssetError() throws {
        let bundle = try #require(Bundle(identifier: "org.michaelthscott.FarewellToUlsterTests"))
        let error = try #require(throws: StorageError.self) {
            _ = try Storage(isStoredInMemoryOnly: true, assetName: "NoBook", bundle: bundle)
        }
        guard case .invalidAsset(let name, let underlying) = error else {
            Issue.record("Expected invalidAsset, got \(error)")
            return
        }
        #expect(name == "NoBook")
        // The decoding error is kept, so the message says why the asset could not be read.
        #expect(underlying is DecodingError)
        #expect(error.description.hasPrefix("Could not decode the asset NoBook: "))
    }

    @Test func testLoadWarnings() throws {
        // In SmallBook, two poems refer to a subject that isn't in the book.
        let storage = try #require(Storage.testStorage(with: "SmallBook"))
        #expect(storage.loadWarnings == [
            "Azure twinkles: subject F317C79E-8975-4B3A-A842-CA670BCE5DBF not found",
            "Twilight: subject F317C79E-8975-4B3A-A842-CA670BCE5DBF not found",
        ])
        // The missing subject is left out, and the links that do match are kept.
        let azure = try #require(storage.poems.first { $0.title == "Azure twinkles" })
        #expect(azure.subjects?.isEmpty == true)
        let green = try #require(storage.poems.first { $0.title == "Green whispers" })
        #expect(green.subjects?.map(\.title) == ["The Horizon"])
        #expect(green.era?.title == "The Middle")
        #expect(green.events?.map(\.uuid.uuidString) == ["42149FEA-4DB0-43CC-BC42-04D98E5C6D1A"])
    }

    @Test func testNoLoadWarnings() throws {
        let storage = try #require(Storage.testStorage(with: "EmptyBook"))
        #expect(storage.loadWarnings.isEmpty)
    }

    @Test func testLoadedBookIsSaved() throws {
        let storage = try #require(Storage.testStorage(with: "SmallBook"))
        #expect(!storage.container.mainContext.hasChanges)
        // A separate context only sees what has been written to the store.
        let otherContext = ModelContext(storage.container)
        #expect(try otherContext.fetchCount(FetchDescriptor<Book>()) == 1)
        #expect(try otherContext.fetchCount(FetchDescriptor<Era>()) == 3)
        #expect(try otherContext.fetchCount(FetchDescriptor<Event>()) == 3)
        #expect(try otherContext.fetchCount(FetchDescriptor<Subject>()) == 3)
        #expect(try otherContext.fetchCount(FetchDescriptor<Poem>()) == 6)
    }

    @Test func testSave() throws {
        let storage = try #require(Storage.testStorage(with: "SmallBook"))
        let poem = try #require(storage.poems.first)
        let uuid = poem.uuid
        poem.title = "Saved title"
        storage.save()
        #expect(storage.saveError == nil)
        #expect(!storage.container.mainContext.hasChanges)
        // A separate context only sees what has been written to the store.
        let otherContext = ModelContext(storage.container)
        let descriptor = FetchDescriptor<Poem>(predicate: #Predicate { $0.uuid == uuid })
        let savedPoem = try #require(try otherContext.fetch(descriptor).first)
        #expect(savedPoem.title == "Saved title")
    }
}
