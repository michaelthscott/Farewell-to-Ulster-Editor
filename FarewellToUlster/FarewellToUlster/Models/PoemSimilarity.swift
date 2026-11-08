//
//  PoemSimilarity.swift
//  FarewellToUlster
//
//  Created by Michael Scott on 04/06/2026.
//

import Foundation
import NaturalLanguage
import Accelerate

/// Finds pairs of similar poems, so that repetition can be reviewed and reduced.
/// An actor, because an NLEmbedding isn't safe for concurrent use. Embeddings are cached,
/// so only new or edited poems are embedded again.
actor PoemSimilarity {
    /// The UserDefaults key and default for the similarity threshold setting.
    /// The threshold applies to similarities centred on the book's average poem: in the book, half of all pairs
    /// in an era score around 0, the top 1% from about 0.4, and the most similar pairs about 0.55–0.65.
    /// The key changed when centring was introduced, because the scale changed.
    static let thresholdKey = "centredSimilarityThreshold"
    static let defaultThreshold = 0.4
    /// The practical range for the threshold: from roughly the top 10% of pairs in an era to above the most similar pair.
    /// The upper bound is above the text maximum, because shared subjects add to a pair's score.
    static let thresholdRange = 0.25...0.9

    /// The threshold brought within the practical range, in case an older setting is outside it.
    nonisolated static func practicalThreshold(_ threshold: Double) -> Double {
        min(max(threshold, thresholdRange.lowerBound), thresholdRange.upperBound)
    }

    /// The UserDefaults key, default and range for how much shared subjects add to a pair's score.
    /// At 0.2, sharing a rare subject adds about 0.2, roughly the gap between the top 10% and top 1% of text scores.
    static let subjectWeightKey = "subjectWeight"
    static let defaultSubjectWeight = 0.2
    static let subjectWeightRange = 0.0...0.5

    static let shared = PoemSimilarity()

    /// A snapshot of a poem's text and subjects, which can be sent to the actor.
    nonisolated struct PoemText: Hashable, Sendable {
        let uuid: UUID
        let text: String
        let subjects: [UUID]

        init(uuid: UUID, text: String, subjects: [UUID] = []) {
            self.uuid = uuid
            self.text = text
            self.subjects = subjects
        }
    }

    /// How strongly the subjects two poems share suggest they repeat a memory, from 0 to 1.
    /// Each shared subject counts by its rarity in the book, ln(poems / poems with the subject),
    /// so sharing a rare subject counts far more than sharing one used throughout the book.
    /// The total is divided by the rarity of a subject used by just two poems, and capped at 1.
    /// It isn't divided by how many subjects the poems have, so two poems tagged only with a
    /// common subject don't score as if they were the same.
    nonisolated static func subjectBonus(shared: [UUID], frequencies: [UUID: Int], poemCount: Int) -> Float {
        guard poemCount > 2 else { return 0 }
        let total = shared.reduce(Float(0)) { sum, subject in
            let frequency = max(frequencies[subject] ?? 2, 2)
            return sum + log(Float(poemCount) / Float(frequency))
        }
        return min(1, total / log(Float(poemCount) / 2))
    }

    private struct CachedVector {
        let text: String
        let vector: [Float]
    }

    private var loadedEmbedding: NLEmbedding?
    private var cache: [UUID: CachedVector] = [:]
    /// The number of poems embedded so far, so tests can check the cache.
    private(set) var embeddedCount = 0

    /// The English sentence embedding. Loading is retried until it succeeds,
    /// because the first request can fail while the system is still making it available.
    private var embedding: NLEmbedding? {
        if loadedEmbedding == nil {
            loadedEmbedding = NLEmbedding.sentenceEmbedding(for: .english)
        }
        return loadedEmbedding
    }

    /// Whether the English sentence embedding is available. Without it, no similar poems are found.
    var isAvailable: Bool {
        embedding != nil
    }

    /// The pairs of poems whose similarity is at least the threshold, most similar first.
    /// With the book's poems, the average poem is subtracted from each poem before comparing,
    /// so what the poems all have in common doesn't count towards their similarity, and the
    /// subjects a pair shares add subjectWeight × subjectBonus to its similarity.
    func similarPoemPairs(poems: [PoemText], threshold: Float, book: [PoemText]? = nil, subjectWeight: Float = 0) -> [PoemPair] {
        var embedded = poems.compactMap { poem in
            vector(for: poem).map { (uuid: poem.uuid, vector: $0, subjects: Set(poem.subjects)) }
        }
        guard embedded.count >= 2 else { return [] }

        // How many of the book's poems have each subject, for weighting shared subjects by rarity.
        let bookPoems = book ?? poems
        var frequencies: [UUID: Int] = [:]
        for poem in bookPoems {
            for subject in Set(poem.subjects) {
                frequencies[subject, default: 0] += 1
            }
        }

        if let book {
            let backgroundVectors = book.compactMap { vector(for: $0) }
            if let first = backgroundVectors.first {
                // The average poem: the sum of the vectors divided by their number.
                var mean = [Float](repeating: 0, count: first.count)
                for vector in backgroundVectors {
                    vDSP_vadd(mean, 1, vector, 1, &mean, 1, vDSP_Length(mean.count))
                }
                var count = Float(backgroundVectors.count)
                vDSP_vsdiv(mean, 1, &count, &mean, 1, vDSP_Length(mean.count))
                // Subtract it, and normalise again so cosine similarity is still a dot product.
                embedded = embedded.map { e in
                    var centred = [Float](repeating: 0, count: e.vector.count)
                    vDSP_vsub(mean, 1, e.vector, 1, &centred, 1, vDSP_Length(centred.count))
                    return (e.uuid, Self.normalised(centred), e.subjects)
                }
            }
        }

        let n = embedded.count
        let dim = embedded[0].vector.count

        // Flatten into a single row-major [n x dim] buffer —
        // vDSP/BLAS-style routines operate on flat contiguous memory, not arrays of arrays.
        var flat = [Float](repeating: 0, count: n * dim)
        for (i, e) in embedded.enumerated() {
            flat.replaceSubrange(i * dim ..< (i + 1) * dim, with: e.vector)
        }

        // Compute every pairwise similarity at once: flat (n x dim) × flatᵀ (dim x n) → n x n.
        // vDSP_mmul expects the second operand pre-transposed in memory (no transpose
        // flag like BLAS has), so build that [dim x n] transpose of flat first.
        var flatTransposed = [Float](repeating: 0, count: n * dim)
        vDSP_mtrans(flat, 1, &flatTransposed, 1, vDSP_Length(dim), vDSP_Length(n))

        // Because the vectors are normalised, matrix[i * n + j] is the cosine similarity between poem i and poem j.
        var matrix = [Float](repeating: 0, count: n * n)
        vDSP_mmul(flat, 1, flatTransposed, 1, &matrix, 1, vDSP_Length(n), vDSP_Length(n), vDSP_Length(dim))

        var pairs: [PoemPair] = []
        // Only scan the upper triangle (i < j) — matrix is symmetric, diagonal is self-similarity == 1
        for i in 0..<n {
            for j in (i + 1)..<n {
                var similarity = matrix[i * n + j]
                if subjectWeight > 0 {
                    let shared = Array(embedded[i].subjects.intersection(embedded[j].subjects))
                    similarity += subjectWeight * Self.subjectBonus(shared: shared, frequencies: frequencies, poemCount: bookPoems.count)
                }
                if similarity >= threshold {
                    pairs.append(PoemPair(embedded[i].uuid, embedded[j].uuid, similarity: similarity))
                }
            }
        }
        // Break ties by id, so the order is stable.
        return pairs.sorted { ($0.similarity, $1.id) > ($1.similarity, $0.id) }
    }

    /// The poem's normalised embedding, from the cache if its text hasn't changed.
    private func vector(for poem: PoemText) -> [Float]? {
        if let cached = cache[poem.uuid], cached.text == poem.text {
            return cached.vector
        }
        guard let vec = embedding?.vector(for: poem.text) else { return nil }
        let floatVec = Self.normalised(vec.map { Float($0) })
        cache[poem.uuid] = CachedVector(text: poem.text, vector: floatVec)
        embeddedCount += 1
        return floatVec
    }

    /// The vector scaled to unit length, so that cosine similarity
    /// between any two poems reduces to a plain dot product.
    ///
    /// cosine(A, B) = (A · B) / (‖A‖ × ‖B‖)
    ///
    /// If ‖A‖ = ‖B‖ = 1, the denominator becomes 1 and this simplifies to:
    ///
    /// cosine(A, B) = A · B
    ///
    /// That's what lets the pairwise comparison become a single matrix
    /// multiply (vDSP_mmul only computes raw dot products).
    private static func normalised(_ vector: [Float]) -> [Float] {
        var result = vector
        var norm: Float = 0
        vDSP_svesq(vector, 1, &norm, vDSP_Length(vector.count))
        norm = sqrt(norm)
        if norm > 0 {
            var divisor = norm
            vDSP_vsdiv(vector, 1, &divisor, &result, 1, vDSP_Length(vector.count))
        }
        return result
    }
}

nonisolated extension Poem {
    /// The text and subjects compared for similarity. The title is left out: it is often the first line,
    /// and including it ranked poems sharing a line below poems that don't.
    var similarityText: PoemSimilarity.PoemText {
        PoemSimilarity.PoemText(uuid: uuid, text: text, subjects: (subjects ?? []).map(\.uuid).sorted { $0.uuidString < $1.uuidString })
    }
}
