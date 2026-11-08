//
//  SimilarityTests.swift
//  FarewellToUlsterTests
//
//  Created by Michael Scott on 04/06/2026.
//

import Testing
import Foundation
import SwiftData
import NaturalLanguage
@testable import FarewellToUlster

@Suite(.enabled(if: NLEmbedding.sentenceEmbedding(for: .english) != nil))
struct SimilarityTests {

    private func similarPairs(threshold: Float) async throws -> [(title1: String, title2: String, similarity: Float)] {
        let storage = try #require(Storage.testStorage(with: "SmallBook"))
        let poems = storage.poems
        let poemsByUUID = Dictionary(uniqueKeysWithValues: poems.map { ($0.uuid, $0) })
        let pairs = await PoemSimilarity().similarPoemPairs(poems: poems.map(\.similarityText), threshold: threshold)
        return try pairs.map { pair in
            let poem1 = try #require(poemsByUUID[pair.uuid1])
            let poem2 = try #require(poemsByUUID[pair.uuid2])
            // Order the titles, so the expectations don't depend on the UUIDs.
            let titles = [poem1.title, poem2.title].sorted()
            return (titles[0], titles[1], pair.similarity)
        }
    }

    @Test("Threshold: 0.0")
    func testFindSimilarPoemPairsZeroThreshold() async throws {
        let found = try await similarPairs(threshold: 0.0)
        #expect(found.count == 15)
        #expect(found.first?.title1 == "Azure twinkles")
        #expect(found.first?.title2 == "Twilight")
        #expect(found.last?.title1 == "Rosemary")
        #expect(found.last?.title2 == "Sleeping leaves")
    }

    @Test("Threshold: 0.5")
    func testFindSimilarPoemPairsMediumThreshold() async throws {
        let found = try await similarPairs(threshold: 0.5)
        #expect(found.count == 2)
        #expect(found.first?.title1 == "Azure twinkles")
        #expect(found.first?.title2 == "Twilight")
        #expect(found.last?.title1 == "Custard cake")
        #expect(found.last?.title2 == "Sleeping leaves")
    }

    @Test("Threshold: 0.8")
    func testFindSimilarPoemPairsHighThreshold() async throws {
        let found = try await similarPairs(threshold: 0.8)
        #expect(found.count == 0)
    }

    @Test("Pairs are sorted most similar first")
    func testSorted() async throws {
        let similarities = try await similarPairs(threshold: 0.0).map(\.similarity)
        #expect(similarities == similarities.sorted(by: >))
    }

    @Test("Raising the threshold only removes pairs from the end")
    func testThresholdKeepsOrder() async throws {
        let all = try await similarPairs(threshold: 0.0).map { $0.title1 + $0.title2 }
        let some = try await similarPairs(threshold: 0.5).map { $0.title1 + $0.title2 }
        #expect(Array(all.prefix(some.count)) == some)
    }

    @Test("Fewer than two poems give no pairs")
    func testTooFewPoems() async {
        let similarity = PoemSimilarity()
        let poem = PoemSimilarity.PoemText(uuid: UUID(), text: "The sea at night")
        #expect(await similarity.similarPoemPairs(poems: [], threshold: 0.0).isEmpty)
        #expect(await similarity.similarPoemPairs(poems: [poem], threshold: 0.0).isEmpty)
    }

    @Test("A pair is the same whichever poem comes first")
    func testPairOrder() {
        let uuid1 = UUID()
        let uuid2 = UUID()
        let pair = PoemPair(uuid1, uuid2, similarity: 0.5)
        let reversed = PoemPair(uuid2, uuid1, similarity: 0.5)
        #expect(pair.id == reversed.id)
        #expect(pair == reversed)
    }

    @Test("Subtracting the average poem lowers similarities and keeps them sorted")
    func testCentred() async throws {
        let storage = try #require(Storage.testStorage(with: "SmallBook"))
        let texts = storage.poems.map(\.similarityText)
        let similarity = PoemSimilarity()
        let plain = await similarity.similarPoemPairs(poems: texts, threshold: -2)
        let centred = await similarity.similarPoemPairs(poems: texts, threshold: -2, centredOn: texts)
        #expect(centred.count == plain.count)
        let similarities = centred.map(\.similarity)
        #expect(similarities == similarities.sorted(by: >))
        let mean = { (pairs: [PoemPair]) in pairs.map(\.similarity).reduce(0, +) / Float(pairs.count) }
        #expect(mean(centred) < mean(plain))
        // The two poems sharing "leaves me breathless" are still the most similar.
        let titles = Dictionary(uniqueKeysWithValues: storage.poems.map { ($0.uuid, $0.title) })
        let top = try #require(centred.first)
        #expect(Set([titles[top.uuid1], titles[top.uuid2]]) == Set(["Azure twinkles", "Twilight"]))
    }

    @Test("Thresholds are brought within the practical range")
    func testPracticalThreshold() {
        let range = PoemSimilarity.thresholdRange
        #expect(PoemSimilarity.practicalThreshold(0.05) == range.lowerBound)
        #expect(PoemSimilarity.practicalThreshold(1.0) == range.upperBound)
        #expect(PoemSimilarity.practicalThreshold(0.7) == 0.7)
        #expect(range.contains(PoemSimilarity.defaultThreshold))
    }

    @Test("Only new or edited poems are embedded again")
    func testCache() async {
        let similarity = PoemSimilarity()
        let sea = PoemSimilarity.PoemText(uuid: UUID(), text: "The sea at night")
        let hill = PoemSimilarity.PoemText(uuid: UUID(), text: "The hill in the morning")
        _ = await similarity.similarPoemPairs(poems: [sea, hill], threshold: 0.0)
        #expect(await similarity.embeddedCount == 2)
        _ = await similarity.similarPoemPairs(poems: [sea, hill], threshold: 0.0)
        #expect(await similarity.embeddedCount == 2)
        let editedHill = PoemSimilarity.PoemText(uuid: hill.uuid, text: "The hill at dusk")
        _ = await similarity.similarPoemPairs(poems: [sea, editedHill], threshold: 0.0)
        #expect(await similarity.embeddedCount == 3)
    }
}
