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
    @Environment(Storage.self) private var storage
    let pairs: [Pair]
    // The pair to mark as not duplicates once the alert is confirmed.
    @State private var pairToConfirm: Pair?

    var body: some View {
        Section("Similar Poems") {
            ForEach(pairs) { pair in
                NavigationLink("\(pair.poem1.title) & \(pair.poem2.title)", value: Path.poemPair(pair.poem1, pair.poem2))
                    .swipeActions {
                        Button("Not Duplicate", systemImage: "rectangle.on.rectangle.slash") {
                            pairToConfirm = pair
                        }
                    }
            }
        }
        .alert("Not Duplicate?", isPresented: Binding(get: { pairToConfirm != nil }, set: { if !$0 { pairToConfirm = nil } }), presenting: pairToConfirm) { pair in
            Button("Cancel", role: .cancel) {}
            Button("Not Duplicate") {
                withAnimation {
                    pair.poem1.markDistinct(from: pair.poem2)
                    // Write the change now, rather than leaving it to autosave.
                    storage.save()
                }
            }
        } message: { pair in
            Self.notDuplicateMessage(pair.poem1, pair.poem2)
        }
    }

    /// The message for the alert confirming a pair isn't a duplicate. There's no undo, so it says what will happen.
    static func notDuplicateMessage(_ poem1: Poem, _ poem2: Poem) -> Text {
        Text("“\(poem1.title)” and “\(poem2.title)” won't be listed as similar poems again.")
    }

    struct Pair: Identifiable {
        let id: String
        let poem1: Poem
        let poem2: Poem
    }

    /// Everything the pairs depend on. Use as a task id, so the pairs are found again whenever
    /// a poem's text or subjects, the poems, the book's poems, the threshold, the subject weight,
    /// or the pairs marked as not duplicates change.
    struct Request: Equatable {
        let poems: [PoemSimilarity.PoemText]
        /// Every poem in the book. Their average is subtracted before comparing, so the voice and themes
        /// common to the whole book don't make every pair look similar. They also show how rare each subject is.
        let bookPoems: [PoemSimilarity.PoemText]
        let threshold: Double
        let subjectWeight: Double
        /// The ids of the pairs among the poems marked as not duplicates, which are left out.
        let distinctPairIDs: Set<String>

        init(poems: [Poem], bookPoems: [Poem], threshold: Double, subjectWeight: Double) {
            // Sorted by UUID, so the order poems are fetched in doesn't matter.
            self.poems = Self.sortedTexts(poems)
            self.bookPoems = Self.sortedTexts(bookPoems)
            self.threshold = threshold
            self.subjectWeight = subjectWeight
            self.distinctPairIDs = Set(poems.flatMap { poem in
                poem.distinctPoemUUIDs.map { PoemPair(poem.uuid, $0, similarity: 0).id }
            })
        }

        private static func sortedTexts(_ poems: [Poem]) -> [PoemSimilarity.PoemText] {
            poems.map(\.similarityText).sorted { $0.uuid.uuidString < $1.uuid.uuidString }
        }
    }

    /// The pairs of similar poems, most similar first, leaving out those marked as not duplicates.
    static func pairs(in poems: [Poem], for request: Request) async -> [Pair] {
        let found = await PoemSimilarity.shared.similarPoemPairs(poems: request.poems, threshold: Float(request.threshold), book: request.bookPoems, subjectWeight: Float(request.subjectWeight))
        let poemsByUUID = Dictionary(poems.map { ($0.uuid, $0) }, uniquingKeysWith: { first, _ in first })
        return found.compactMap { pair in
            guard !request.distinctPairIDs.contains(pair.id) else { return nil }
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
            pairs = await PoemPairsList.pairs(in: poems, for: .init(poems: poems, bookPoems: poems, threshold: 0.0, subjectWeight: PoemSimilarity.defaultSubjectWeight))
        }
        .navigationDestination(for: Path.self) { path in
            DestinationView(path: path)
        }
        .environment(navigation)
    }
}
#endif
