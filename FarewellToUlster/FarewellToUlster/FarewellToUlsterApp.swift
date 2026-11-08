//
//  FarewellToUlsterApp.swift
//  FarewellToUlster
//
//  Created by Michael Scott on 13/05/2026.
//

import SwiftUI
import SwiftData

@main
struct FarewellToUlsterApp: App {
    @State private var storage: Storage? = nil
    @State private var navigation = Navigation()
    @State private var message: String? = nil
    @State private var isLoadingFromGitHub = false

    var body: some Scene {
        WindowGroup {
            if let storage {
                ContentView()
                    .environment(navigation)
                    .environment(storage)
                    .modelContainer(storage.container)
            } else if let message {
                VStack(spacing: 16) {
                    Text(message)
                    Button("Retry") {
                        self.message = nil
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else {
                ProgressView(isLoadingFromGitHub ? "Loading book from GitHub…" : "Loading...")
                    .task { await createStorage() }
            }
        }
    }

    /// Creates the storage, loading the book from GitHub if there isn't one yet.
    /// The storage is only shown once it holds a book. Retry clears the message, which brings back the
    /// ProgressView and runs this again.
    private func createStorage() async {
        do {
            let storage = try Storage()
            if try !storage.hasBook() {
                isLoadingFromGitHub = true
                defer { isLoadingFromGitHub = false }
                let client = GitHubClient.site
                let data = try await client.fileContent(path: GitHubClient.bookPath)
                try storage.loadData(gitHubFile: data, path: GitHubClient.bookPath)
            }
            self.storage = storage
        } catch {
            message = "Failed to load the book: \(error.localizedDescription)"
        }
    }
}
