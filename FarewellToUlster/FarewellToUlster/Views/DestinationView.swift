//
//  DestinationView.swift
//  FarewellToUlster
//
//  Created by Michael Scott on 13/05/2026.
//

import SwiftUI
import SwiftData

/// Used to specify the navigation path.
enum Path: Hashable {
    case poem(Poem)
    case era(Era)
    case event(Event)
    case subject(Subject)
    case poemPair(Poem, Poem)
}

/// Used to specify the navigation destination.
struct DestinationView: View {
    let path: Path
    
    var body: some View {
        switch path {
        case .poem(let poem):
            PoemEditor(poem: poem)
        case .era(let era):
            EraEditor(era: era)
        case .event(let event):
            EventEditor(event: event)
        case .subject(let subject):
            SubjectEditor(subject: subject)
        case .poemPair(let poem1, let poem2):
            PoemPairView(poem1: poem1, poem2: poem2)
        }
    }
}

#if DEBUG
#Preview(traits: .sampleData) {
    @Previewable @State var navigation = Navigation()
    @Previewable @Environment(Storage.self) var storage
    DestinationView(path: .poem(try! storage.fetchPoems().first!))
        .environment(navigation)
}
#endif
