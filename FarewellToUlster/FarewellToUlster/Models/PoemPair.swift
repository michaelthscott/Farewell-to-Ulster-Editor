//
//  PoemPair.swift
//  FarewellToUlster
//
//  Created by Michael Scott on 04/06/2026.
//

import Foundation

/// Two similar poems, identified by UUID. The UUIDs are stored in order, so the pair is the same whichever poem comes first.
nonisolated struct PoemPair: Sendable {
    let uuid1: UUID
    let uuid2: UUID
    let similarity: Float

    init(_ first: UUID, _ second: UUID, similarity: Float) {
        if first.uuidString <= second.uuidString {
            uuid1 = first
            uuid2 = second
        } else {
            uuid1 = second
            uuid2 = first
        }
        self.similarity = similarity
    }
}

nonisolated extension PoemPair: Identifiable {
    var id: String {
        uuid1.uuidString + uuid2.uuidString
    }
}

nonisolated extension PoemPair: Hashable {
    static func == (lhs: PoemPair, rhs: PoemPair) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
