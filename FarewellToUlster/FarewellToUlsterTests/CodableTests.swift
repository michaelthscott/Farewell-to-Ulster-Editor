//
//  CodableTests.swift
//  FarewellToUlsterTests
//
//  Created by Michael Scott on 13/05/2026.
//

import Foundation
import Testing
@testable import FarewellToUlster
import UIKit

struct CodableTests {
    enum TestError: Error {
        case invalidAsset
        case noTestBundle
    }

    /// The test bundle, which holds the SmallBook asset. The app no longer bundles a copy of the book.
    private func testBundle() throws -> Bundle {
        guard let bundle = Bundle(identifier: "org.michaelthscott.FarewellToUlsterTests") else { throw TestError.noTestBundle }
        return bundle
    }
    
    @Test func testImportJSON() async throws {
        guard let asset = NSDataAsset(name: "SmallBook", bundle: try testBundle()) else { throw TestError.invalidAsset }
        let data = asset.data
        let book = try JSONDecoder().decode(JSONBook.self, from: data)
        #expect(book.title == "The Blue Dawn")
        #expect(book.author == "Archibald Tumbledown")
        #expect(book.eras.count > 0)
        #expect(book.events.count > 0)
        #expect(book.subjects.count > 0)
        #expect(book.poems.count > 0)
    }

    @Test func testExportJSON() async throws {
        guard let asset = NSDataAsset(name: "SmallBook", bundle: try testBundle()) else { throw TestError.invalidAsset }
        let data1 = asset.data
        let book1 = try JSONDecoder().decode(JSONBook.self, from: data1)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data2 = try encoder.encode(book1)
        let book2 = try JSONDecoder().decode(JSONBook.self, from: data2)
        #expect(book1 == book2)
        // SmallBook is formatted by hand, so compare one export with the next rather than with the asset:
        // exporting the same book twice must give exactly the same bytes, so unchanged files aren't committed again.
        let data3 = try encoder.encode(book2)
        #expect(data2 == data3)
        #expect(book2.data == data2)
    }
}

