//
//  Document.swift
//  FarewellToUlster
//
//  Created by Michael Scott on 13/05/2026.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Pre-rendered file contents (JSON or PDF) handed to `fileExporter`.
struct Document: FileDocument {
    static let readableContentTypes: [UTType] = []
    static let writableContentTypes: [UTType] = [.json, .pdf]

    let data: Data

    init(data: Data) {
        self.data = data
    }

    /// Required by `FileDocument`, but never called: the app only exports, so `readableContentTypes` is empty.
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
