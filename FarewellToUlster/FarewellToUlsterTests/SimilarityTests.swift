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
        let centred = await similarity.similarPoemPairs(poems: texts, threshold: -2, book: texts)
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

    @Test("Shared subjects count by their rarity")
    func testSubjectBonus() {
        let rare = UUID()
        let common = UUID()
        let frequencies = [rare: 2, common: 90]
        #expect(PoemSimilarity.subjectBonus(shared: [], frequencies: frequencies, poemCount: 900) == 0)
        #expect(abs(PoemSimilarity.subjectBonus(shared: [rare], frequencies: frequencies, poemCount: 900) - 1) < 0.0001)
        let commonBonus = PoemSimilarity.subjectBonus(shared: [common], frequencies: frequencies, poemCount: 900)
        #expect(commonBonus > 0 && commonBonus < 0.5)
        #expect(PoemSimilarity.subjectBonus(shared: [rare, common], frequencies: frequencies, poemCount: 900) == 1)
    }

    @Test("A subject weight of 0 ignores subjects")
    func testZeroSubjectWeight() async throws {
        let storage = try #require(Storage.testStorage(with: "SmallBook"))
        let texts = storage.poems.map(\.similarityText)
        let similarity = PoemSimilarity()
        let centred = await similarity.similarPoemPairs(poems: texts, threshold: -2, book: texts)
        let weighted = await similarity.similarPoemPairs(poems: texts, threshold: -2, book: texts, subjectWeight: 0)
        #expect(centred.map(\.id) == weighted.map(\.id))
        #expect(centred.map(\.similarity) == weighted.map(\.similarity))
    }

    @Test("A shared rare subject raises a pair more than a shared common one")
    func testSharedSubjectsRaisePairs() async throws {
        let storage = try #require(Storage.testStorage(with: "SmallBook"))
        let plain = storage.poems.map { PoemSimilarity.PoemText(uuid: $0.uuid, text: $0.text) }
        let similarity = PoemSimilarity()
        let unweighted = await similarity.similarPoemPairs(poems: plain, threshold: -2, book: plain)
        // The least similar pair on text alone.
        let last = try #require(unweighted.last)
        let rare = UUID()
        let common = UUID()
        func tagged(_ subjectFor: (PoemSimilarity.PoemText) -> [UUID]) -> [PoemSimilarity.PoemText] {
            plain.map { PoemSimilarity.PoemText(uuid: $0.uuid, text: $0.text, subjects: subjectFor($0)) }
        }
        // The rare subject is only on the least similar pair; the common one is on every poem but one.
        let withRare = tagged { [last.uuid1, last.uuid2].contains($0.uuid) ? [rare] : [] }
        let others = plain.map(\.uuid).filter { $0 != last.uuid1 && $0 != last.uuid2 }
        let withCommon = tagged { $0.uuid == others.first ? [] : [common] }
        func rank(_ texts: [PoemSimilarity.PoemText]) async -> Int? {
            await similarity.similarPoemPairs(poems: texts, threshold: -2, book: texts, subjectWeight: 0.5)
                .firstIndex { $0.id == last.id }
        }
        let rareRank = try #require(await rank(withRare))
        let commonRank = try #require(await rank(withCommon))
        #expect(rareRank < unweighted.count - 1)
        #expect(rareRank < commonRank)
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
