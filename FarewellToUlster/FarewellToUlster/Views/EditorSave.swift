//
//  EditorSave.swift
//  FarewellToUlster
//
//  Created by Michael Scott on 13/05/2026.
//

import SwiftUI

/// Save button for an editor.
struct EditorSave: ToolbarContent {
    @Environment(\.dismiss) private var dismiss
    @Environment(Storage.self) private var storage
    let needsSave: Bool
    let save: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button("Save") {
                withAnimation {
                    save()
                    // Write the edits now, rather than leaving them to autosave.
                    storage.save()
                }
            }
            .buttonStyle(.glassProminent)
            .disabled(!needsSave)
        }
    }
}

#if DEBUG
#Preview("Needs save", traits: .sampleData) {
    NavigationStack {
        Form {
            Text("ABC")
        }
        .toolbar {
            EditorSave(needsSave: true) {
                print("Saving edited values")
            }
        }
    }
}

#Preview("Doesn't need save", traits: .sampleData) {
    NavigationStack {
        Form {
            Text("ABC")
        }
        .toolbar {
            EditorSave(needsSave: false) {
                print("Saving edited values")
            }
        }
    }
}
#endif
