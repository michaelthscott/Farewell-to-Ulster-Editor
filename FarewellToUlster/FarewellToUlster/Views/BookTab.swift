//
//  BookTab.swift
//  FarewellToUlster
//
//  Created by Michael Scott on 13/05/2026.
//

import Foundation
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

//TODO: If there is no book then we could import a book. This would replace inserting a default book when setting up the container.

/// Display and edit the book title and author. Export the book as JSON and PDF.
struct BookTab: View {
    @Environment(Navigation.self) private var navigation
    @Environment(Storage.self) private var storage
    @State private var export: Export?
    @State private var isCommittingUpdate: Bool = false
    @State private var showGitHubSettings: Bool = false
    @State private var outcome: CommitOutcome?

    /// A rendered file waiting to be saved, with the type and name to save it under.
    private struct Export {
        let document: Document
        let contentType: UTType
        let fileName: String
    }

    /// Drives the file exporter, clearing the export when the exporter is dismissed.
    private var showExporter: Binding<Bool> {
        Binding(
            get: { export != nil },
            set: { if !$0 { export = nil } }
        )
    }

    /// Drives the outcome alert, clearing the outcome when the alert is dismissed.
    private var showOutcome: Binding<Bool> {
        Binding(
            get: { outcome != nil },
            set: { if !$0 { outcome = nil } }
        )
    }

    /// The version and build number, e.g. "Version 1.1.0 (523)". Set by the release script; debug builds show 1.0 (1).
    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "Version \(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            BookView()
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button(action: {
                                Task {
                                    isCommittingUpdate = true
                                    await commitUpdate()
                                    isCommittingUpdate = false
                                }
                            }) {
                                Label("Commit update", systemImage: "square.and.arrow.down")
                            }
                            Button(action: {
                                Task {
                                    await exportPDF()
                                }
                            }) {
                                Label("Export PDF", systemImage: "square.and.arrow.up")
                            }
                            Button(action: {
                                showGitHubSettings = true
                            }) {
                                Label("GitHub Token", systemImage: "key")
                            }
                            Divider()
                            Text(appVersion)
                        } label: {
                            Label("Export", systemImage: "ellipsis.circle")
                        }
                    }
                }
                .overlay {
                    if isCommittingUpdate {
                        Color.black.opacity(0.3).ignoresSafeArea()
                        ProgressView("Committing update …")
                            .padding(24)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
                .alert(outcome?.title ?? "", isPresented: showOutcome, presenting: outcome) { _ in
                    Button("OK", role: .cancel) { }
                } message: { outcome in
                    Text(outcome.message)
                }
                .sheet(isPresented: $showGitHubSettings) {
                    NavigationStack {
                        GitHubSettingsView()
                            .navigationTitle("GitHub")
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button("Done") { showGitHubSettings = false }
                                }
                            }
                    }
                }
                .fileExporter(isPresented: showExporter, document: export?.document, contentType: export?.contentType ?? .pdf, defaultFilename: export?.fileName) { result in
                    switch result {
                    case .success(let url):
                        print("Saved to \(url)")
                    case .failure(let error):
                        print(error.localizedDescription)
                    }
                }
        }
    }
    
    private func commitUpdate() async {
        var outcome = CommitOutcome()
        defer { self.outcome = outcome }

        guard let jsonFile = JSONFile(storage: storage) else {
            outcome.record(target: "JSON file", message: "Could not build the JSON file.")
            return
        }

        let data = jsonFile.document.data

        // The canonical copy lives with the site. The app's bundled copy is only a
        // first-launch seed, refreshed from here by scripts/refresh-seed.sh.
        let localFile = LocalFile(path: "_data/Farewell-to-Ulster.json", content: data)
        
        var localFiles: [LocalFile] = [localFile]
        let client = GitHubClient(owner: "michaelthscott", repo: "Farewell-to-Ulster", branch: "main")
        do {
            let sha = try await client.batchCommit(files: localFiles, message: "Editor update for JSON file")
            outcome.record(target: "JSON file", commitSHA: sha)
        } catch {
            outcome.record(target: "JSON file", error: error)
            // A dead token fails every remaining commit identically, so stop here.
            if outcome.needsToken { return }
        }

        for era in storage.eras {
            // An era with no poems has nothing to write, but still counts towards the
            // total so the summary matches the number of eras in the book.
            guard let poems = era.poems else {
                outcome.record(target: era.title, commitSHA: nil)
                continue
            }
            let eraInfo: MDInfo = .era(title: era.title, number: era.fileOrder)
            localFiles = []
            let sortedPoems = poems.vectorSorted()
            let neighbours = sortedPoems.neighbours
            var mdPoems = [MDPoem]()
            for cursor in neighbours {
                let mdPoem = MDPoem(eraInfo: eraInfo,
                                    info: cursor.currentInfo,
                                    previousInfo: cursor.previousInfo,
                                    nextInfo: cursor.nextInfo,
                                    text: cursor.currentText)
                mdPoems.append(mdPoem)
            }
            let mdEra = MDEra(info: eraInfo, text: era.text, poems: mdPoems)
            localFiles.append(LocalFile(path: mdEra.path, content: mdEra.data))
            for mdPoem in mdEra.poems {
                localFiles.append(LocalFile(path: mdPoem.path, content: mdPoem.data))
            }
            do {
                let sha = try await client.batchCommit(files: localFiles, message: "Editor update for era: \(mdEra.info.title)")
                outcome.record(target: mdEra.info.title, commitSHA: sha)
            } catch {
                outcome.record(target: mdEra.info.title, error: error)
                if outcome.needsToken { return }
            }
        }
    }

    private func exportPDF() async {
        guard let book = storage.book else { return }
        let renderer = PDFRenderer()
        let data: Data = await renderer.render(pages: Pages(storage: storage).pages)
        export = Export(document: Document(data: data),
                        contentType: .pdf,
                        fileName: book.title.replacingOccurrences(of: " ", with: "-") + ".pdf")
    }
}

#if DEBUG
#Preview(traits: .sampleData) {
    @Previewable @State var navigation = Navigation()
    BookTab()
        .environment(navigation)
}
#endif
