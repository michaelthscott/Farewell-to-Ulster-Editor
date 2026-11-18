//
//  CommitAccessory.swift
//  FarewellToUlster
//
//  Created by Michael Scott on 18/11/2026.
//

import SwiftUI

/// The tab bar accessory that flags uncommitted changes and commits them, or shows a commit in progress.
struct CommitAccessory: View {
    @Environment(Storage.self) private var storage
    @Environment(CommitUpdate.self) private var commitUpdate
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    var body: some View {
        HStack {
            if commitUpdate.isCommitting {
                ProgressView()
                Text("Committing update…")
            } else {
                // Inline, beside a minimised tab bar, there is only room for the button.
                if placement != .inline {
                    Label("Uncommitted changes", systemImage: "exclamationmark.circle")
                }
                Spacer()
                Button("Commit") {
                    Task {
                        await commitUpdate.commit(storage: storage)
                    }
                }
                .bold()
                if placement == .inline {
                    Spacer()
                }
            }
        }
        .padding(.horizontal)
    }
}

#if DEBUG
#Preview(traits: .sampleData) {
    TabView {
        Tab("Book", systemImage: "book") {
            Text("Book")
        }
        Tab("Poems", systemImage: "book.pages") {
            Text("Poems")
        }
    }
    .tabViewBottomAccessory {
        CommitAccessory()
    }
    .environment(CommitUpdate())
}
#endif
