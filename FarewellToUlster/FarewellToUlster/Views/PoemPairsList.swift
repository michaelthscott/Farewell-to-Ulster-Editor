//
//  PoemPairsList.swift
//  FarewellToUlster
//
//  Created by Michael Scott on 05/06/2026.
//

import SwiftUI
import SwiftData

/// A form section listing pairs of similar poems, most similar first, as a backlog for review.
struct PoemPairsList: View {
    let pairs: [Pair]

    var body: some View {
        Section("Similar Poems") {
            ForEach(pairs) { pair in
                NavigationLink("\(pair.poem1.title) & \(pair.poem2.title)", value: Path.poemPair(pair.poem1, pair.poem2))
            }
        }
    }

    struct Pair: Identifiable {
        let id: String
        let poem1: Poem
        let poem2: Poem
    }

    /// Everything the pairs depend on. Use as a task id, so the pairs are found again whenever
    /// a poem's text, the poems, the book's poems, or the threshold change.
    struct Request: Equatable {
        let poems: [PoemSimilarity.PoemText]
        /// Every poem in the book. Their average is subtracted before comparing, so the voice and themes
        /// common to the whole book don't make every pair look similar.
        let bookPoems: [PoemSimilarity.PoemText]
        let threshold: Double

        init(poems: [Poem], bookPoems: [Poem], threshold: Double) {
            // Sorted by UUID, so the order poems are fetched in doesn't matter.
            self.poems = Self.sortedTexts(poems)
            self.bookPoems = Self.sortedTexts(bookPoems)
            self.threshold = threshold
        }

        private static func sortedTexts(_ poems: [Poem]) -> [PoemSimilarity.PoemText] {
            poems.map(\.similarityText).sorted { $0.uuid.uuidString < $1.uuid.uuidString }
        }
    }

    /// The pairs of similar poems, most similar first.
    static func pairs(in poems: [Poem], for request: Request) async -> [Pair] {
        let found = await PoemSimilarity.shared.similarPoemPairs(poems: request.poems, threshold: Float(request.threshold), centredOn: request.bookPoems)
        let poemsByUUID = Dictionary(poems.map { ($0.uuid, $0) }, uniquingKeysWith: { first, _ in first })
        return found.compactMap { pair in
            guard let poem1 = poemsByUUID[pair.uuid1], let poem2 = poemsByUUID[pair.uuid2] else { return nil }
            return Pair(id: pair.id, poem1: poem1, poem2: poem2)
        }
    }
}

#if DEBUG
#Preview(traits: .sampleData) {
    @Previewable @State var navigation = Navigation()
    @Previewable @Environment(Storage.self) var storage
    @Previewable @State var pairs: [PoemPairsList.Pair] = []
    let poems = try! storage.fetchPoems()
    NavigationStack {
        Form {
            PoemPairsList(pairs: pairs)
        }
        .task {
            pairs = await PoemPairsList.pairs(in: poems, for: .init(poems: poems, bookPoems: poems, threshold: 0.0))
        }
        .navigationDestination(for: Path.self) { path in
            DestinationView(path: path)
        }
        .environment(navigation)
    }
}
#endif
