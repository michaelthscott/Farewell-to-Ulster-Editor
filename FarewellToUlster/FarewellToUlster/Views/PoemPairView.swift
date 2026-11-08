//
//  PoemPairView.swift
//  FarewellToUlster
//
//  Created by Michael Scott on 12/06/2026.
//

import SwiftUI

/// Two similar poems, each linking to its editor, to be merged or differentiated.
struct PoemPairView: View {
    let poem1: Poem
    let poem2: Poem

    var body: some View {
        List {
            ForEach([poem1, poem2]) { poem in
                NavigationLink(poem.title, value: Path.poem(poem))
            }
        }
        .navigationTitle("Similar Poems")
    }
}

#if DEBUG
#Preview(traits: .sampleData) {
    @Previewable @State var navigation = Navigation()
    @Previewable @Environment(Storage.self) var storage
    let poems = try! storage.fetchPoems()
    NavigationStack {
        PoemPairView(poem1: poems[0], poem2: poems[1])
            .navigationDestination(for: Path.self) { path in
                DestinationView(path: path)
            }
            .environment(navigation)
    }
}
#endif
