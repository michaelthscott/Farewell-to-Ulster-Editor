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
    @State private var showSettings: Bool = false
    @State private var exportError: String?

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

    /// Drives the PDF export error alert, clearing the error when the alert is dismissed.
    private var showExportError: Binding<Bool> {
        Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
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
                                    await exportPDF()
                                }
                            }) {
                                Label("Export PDF", systemImage: "square.and.arrow.up")
                            }
                            Button(action: {
                                showSettings = true
                            }) {
                                Label("Settings", systemImage: "gear")
                            }
                            Divider()
                            Text(appVersion)
                        } label: {
                            Label("Export", systemImage: "ellipsis.circle")
                        }
                    }
                }
                .alert("PDF export failed", isPresented: showExportError, presenting: exportError) { _ in
                    Button("OK", role: .cancel) { }
                } message: { message in
                    Text(message)
                }
                .sheet(isPresented: $showSettings) {
                    NavigationStack {
                        SettingsView()
                            .navigationTitle("Settings")
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button("Done") { showSettings = false }
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
    
    private func exportPDF() async {
        let book: Book
        let pages: [Page]
        do {
            book = try storage.fetchBook()
            pages = try Pages(storage: storage).allPages()
        } catch {
            exportError = error.localizedDescription
            return
        }
        let renderer = PDFRenderer()
        let data: Data = await renderer.render(pages: pages)
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
