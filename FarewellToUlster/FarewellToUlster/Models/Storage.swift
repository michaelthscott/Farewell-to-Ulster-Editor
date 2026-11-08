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
    case invalidGitHubFile(path: String, underlying: any Error)
    case noBook

    var description: String {
        switch self {
        case .noModelContainer(let underlying):
            return "Could not create the model container: \(underlying)"
        case .missingAsset(let name):
            return "Could not find the asset \(name)"
        case .invalidAsset(let name, let underlying):
            return "Could not decode the asset \(name): \(underlying)"
        case .invalidGitHubFile(let path, let underlying):
            return "Could not decode \(path) from GitHub: \(underlying)"
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
    /// The most recent error from add(_:). ContentView shows it in an alert and then clears it.
    var addError: (any Error)?
    /// References in the JSON that didn't match any era, event or subject, and so were left out when the book was loaded.
    /// ContentView shows them in an alert and then clears them.
    var loadWarnings: [String] = []
    /// True when changes have been saved since the last update was committed to GitHub without failures. ContentView badges the Book tab while it's set.
    /// Kept in UserDefaults so it survives a relaunch, except for in-memory storage, so tests and previews don't share it.
    var hasUncommittedChanges: Bool {
        didSet { defaults?.set(hasUncommittedChanges, forKey: Self.uncommittedChangesKey) }
    }
    private let defaults: UserDefaults?
    private static let uncommittedChangesKey = "hasUncommittedChanges"

    /// Creates the storage without loading a book. The app loads one from GitHub if hasBook is false.
    init(isStoredInMemoryOnly: Bool = false) throws {
        defaults = isStoredInMemoryOnly ? nil : UserDefaults.standard
        hasUncommittedChanges = defaults?.bool(forKey: Self.uncommittedChangesKey) ?? false
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
    }

    /// Creates the storage and loads the book from an asset if there isn't one yet. Used by previews and tests.
    convenience init(isStoredInMemoryOnly: Bool = false, assetName: String, bundle: Bundle = Bundle.main) throws {
        try self.init(isStoredInMemoryOnly: isStoredInMemoryOnly)
        // Errors are passed on as they are, so the message shows what actually went wrong.
        try loadData(assetName: assetName, bundle: bundle)
    }

    /// True when the storage already holds a book, so nothing needs to be loaded.
    func hasBook() throws -> Bool {
        try container.mainContext.fetchCount(FetchDescriptor<Book>()) > 0
    }

    func loadData(assetName: String, bundle: Bundle = Bundle.main) throws {
        guard try !hasBook() else { return }
        guard let asset = NSDataAsset(name: assetName, bundle: bundle) else { throw StorageError.missingAsset(name: assetName) }
        let jsonBook: JSONBook
        do {
            jsonBook = try JSONDecoder().decode(JSONBook.self, from: asset.data)
        } catch {
            throw StorageError.invalidAsset(name: assetName, underlying: error)
        }
        try insert(jsonBook)
    }

    /// Loads the book from the JSON committed to GitHub, if there isn't one yet.
    /// Saves directly rather than through save(), so a freshly loaded book isn't flagged as having uncommitted changes.
    func loadData(gitHubFile data: Data, path: String) throws {
        guard try !hasBook() else { return }
        let jsonBook: JSONBook
        do {
            jsonBook = try JSONDecoder().decode(JSONBook.self, from: data)
        } catch {
            throw StorageError.invalidGitHubFile(path: path, underlying: error)
        }
        try insert(jsonBook)
        hasUncommittedChanges = false
    }

    /// Inserts a decoded book with its eras, events, subjects and poems, links the poems, and saves.
    private func insert(_ jsonBook: JSONBook) throws {
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
            hasUncommittedChanges = true
        } catch {
            saveError = error
        }
    }
}
