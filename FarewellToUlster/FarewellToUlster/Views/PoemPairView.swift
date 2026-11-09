//
//  PoemPairView.swift
//  FarewellToUlster
//
//  Created by Michael Scott on 12/06/2026.
//

import SwiftUI

/// Two similar poems, each linking to its editor, to be merged or differentiated.
struct PoemPairView: View {
    @Environment(Storage.self) private var storage
    @Environment(\.dismiss) private var dismiss
    let poem1: Poem
    let poem2: Poem
    @State private var confirmNotDuplicate = false

    var body: some View {
        List {
            ForEach([poem1, poem2]) { poem in
                NavigationLink(poem.title, value: Path.poem(poem))
            }
            Section {
                Button("Not Duplicate") {
                    confirmNotDuplicate = true
                }
            }
        }
        .navigationTitle("Similar Poems")
        .alert("Not Duplicate?", isPresented: $confirmNotDuplicate) {
            Button("Cancel", role: .cancel) {}
            Button("Not Duplicate") {
                poem1.markDistinct(from: poem2)
                // Write the change now, rather than leaving it to autosave.
                storage.save()
                // Back to the era, where the pair is no longer listed.
                dismiss()
            }
        } message: {
            PoemPairsList.notDuplicateMessage(poem1, poem2)
        }
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
