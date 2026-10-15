//
//  Storage.swift
//  FarewellToUlster
//
//  Created by Michael Scott on 13/05/2026.
//

import Foundation
import SwiftData
import UIKit

/// An error that can be encountered while creating or reading the storage. Each case keeps the underlying error, if any, so the failure can be diagnosed.
enum StorageError: LocalizedError, CustomStringConvertible {
    case noModelContainer(underlying: any Error)
    case missingAsset(name: String)
    case invalidAsset(name: String, underlying: any Error)
    case noBook

    var description: String {
        switch self {
        case .noModelContainer(let underlying):
            return "Could not create the model container: \(underlying)"
        case .missingAsset(let name):
            return "Could not find the asset \(name)"
        case .invalidAsset(let name, let underlying):
            return "Could not decode the asset \(name): \(underlying)"
        case .noBook:
            return "There is no book in the storage"
        }
    }

    /// Used by localizedDescription, so alerts that show it give the same message.
    var errorDescription: String? {
        description
    }
}

/// SwiftData storage that is initialised from JSON data.
@Observable final class Storage {
    let container: ModelContainer
    /// The most recent error from save(). ContentView shows it in an alert and then clears it.
    var saveError: (any Error)?
    /// References in the JSON that didn't match any era, event or subject, and so were left out when the book was loaded.
    /// ContentView shows them in an alert and then clears them.
    var loadWarnings: [String] = []
    
    init(isStoredInMemoryOnly: Bool = false, assetName: String = "Farewell-to-Ulster", bundle: Bundle = Bundle.main) throws {
        let schema = Schema([
            Book.self,
            Era.self,
            Event.self,
            Subject.self,
            Poem.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isStoredInMemoryOnly)
        do {
            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            throw StorageError.noModelContainer(underlying: error)
        }
        // Errors are passed on as they are, so the message shows what actually went wrong.
        try loadData(assetName: assetName, bundle: bundle)
    }
    
    func loadData(assetName: String, bundle: Bundle = Bundle.main) throws {
        let descriptor = FetchDescriptor<Book>()
        let booksCount = try container.mainContext.fetchCount(descriptor)
        guard booksCount == 0 else { return }
        guard let asset = NSDataAsset(name: assetName, bundle: bundle) else { throw StorageError.missingAsset(name: assetName) }
        let jsonBook: JSONBook
        do {
            jsonBook = try JSONDecoder().decode(JSONBook.self, from: asset.data)
        } catch {
            throw StorageError.invalidAsset(name: assetName, underlying: error)
        }
        
        let context = container.mainContext
        context.insert(jsonBook.book)

        let eras = jsonBook.eras.map(\.era)
        let events = jsonBook.events.map(\.event)
        let subjects = jsonBook.subjects.map(\.subject)
        for era in eras { context.insert(era) }
        for event in events { context.insert(event) }
        for subject in subjects { context.insert(subject) }

        // Look the models up by UUID, rather than fetching once per reference. If a UUID appears twice, the first model wins.
        let erasByUUID = Dictionary(eras.map { ($0.uuid, $0) }, uniquingKeysWith: { first, _ in first })
        let eventsByUUID = Dictionary(events.map { ($0.uuid, $0) }, uniquingKeysWith: { first, _ in first })
        let subjectsByUUID = Dictionary(subjects.map { ($0.uuid, $0) }, uniquingKeysWith: { first, _ in first })

        // A reference that doesn't match any model is left out of the poem, and reported in loadWarnings.
        var warnings: [String] = []
        func linked<Model>(_ uuids: [UUID], from models: [UUID: Model], kind: String, poem: String) -> [Model] {
            var linked: [Model] = []
            var seen = Set<UUID>()
            for uuid in uuids where seen.insert(uuid).inserted {
                if let model = models[uuid] {
                    linked.append(model)
                } else {
                    warnings.append("\(poem): \(kind) \(uuid.uuidString) not found")
                }
            }
            return linked
        }

        for jsonPoem in jsonBook.poems {
            let poem = jsonPoem.poem
            if let eraUUID = jsonPoem.eraUUID {
                poem.era = linked([eraUUID], from: erasByUUID, kind: "era", poem: poem.title).first
            }
            if let eventUUIDs = jsonPoem.eventUUIDs, !eventUUIDs.isEmpty {
                poem.events = linked(eventUUIDs, from: eventsByUUID, kind: "event", poem: poem.title)
            }
            if let subjectUUIDs = jsonPoem.subjectUUIDs, !subjectUUIDs.isEmpty {
                poem.subjects = linked(subjectUUIDs, from: subjectsByUUID, kind: "subject", poem: poem.title)
            }
            context.insert(poem)
        }
        loadWarnings = warnings

        // Save the loaded book now, rather than leaving it to autosave.
        try context.save()
    }
    
}

// Fetches for code that runs once per action, such as export. Views use @Query instead.
// These throw rather than returning an empty list, so a failed fetch can't be mistaken for an empty book.
extension Storage {
    func fetchBook() throws -> Book {
        guard let book = try container.mainContext.fetch(FetchDescriptor<Book>()).first else {
            throw StorageError.noBook
        }
        return book
    }

    func fetchEras() throws -> [Era] {
        try fetchSorted()
    }

    func fetchEvents() throws -> [Event] {
        try fetchSorted()
    }

    func fetchSubjects() throws -> [Subject] {
        try fetchSorted()
    }

    func fetchPoems() throws -> [Poem] {
        try fetchSorted()
    }

    /// Fetch every model of a type, sorted by its Comparable conformance.
    private func fetchSorted<Model: PersistentModel & Comparable>() throws -> [Model] {
        try container.mainContext.fetch(FetchDescriptor<Model>()).sorted()
    }
}

// Changes go through Storage, so that a failed save can be reported by ContentView.
extension Storage {
    func delete(_ model: any PersistentModel) {
        container.mainContext.delete(model)
    }

    /// Save any pending changes now, rather than waiting for autosave.
    /// A failure is kept in saveError, so it can be reported even if the calling view has been dismissed.
    func save() {
        guard container.mainContext.hasChanges else { return }
        do {
            try container.mainContext.save()
        } catch {
            saveError = error
        }
    }
}
