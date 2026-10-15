//
//  Storage.swift
//  FarewellToUlster
//
//  Created by Michael Scott on 13/05/2026.
//

import Foundation
import SwiftData
import UIKit

/// An error that can be encountered while creating the storage. Each case keeps the underlying error, if any, so the failure can be diagnosed.
enum StorageError: Error, CustomStringConvertible {
    case noModelContainer(underlying: Error)
    case missingAsset(name: String)
    case invalidAsset(name: String, underlying: Error)

    var description: String {
        switch self {
        case .noModelContainer(let underlying):
            return "Could not create the model container: \(underlying)"
        case .missingAsset(let name):
            return "Could not find the asset \(name)"
        case .invalidAsset(let name, let underlying):
            return "Could not decode the asset \(name): \(underlying)"
        }
    }
}

/// SwiftData storage that is initialised from JSON data.
@Observable final class Storage {
    let container: ModelContainer
    /// The most recent error from save(). ContentView shows it in an alert and then clears it.
    var saveError: Error?
    
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
        
        let book = jsonBook.book
        container.mainContext.insert(book)
        
        for jsonEra in jsonBook.eras {
            let era = jsonEra.era
            container.mainContext.insert(era)
        }
        
        for jsonEvent in jsonBook.events {
            let event = jsonEvent.event
            container.mainContext.insert(event)
        }
        
        for jsonSubject in jsonBook.subjects {
            let subject = jsonSubject.subject
            container.mainContext.insert(subject)
        }
        
        for jsonPoem in jsonBook.poems {
            let poem = jsonPoem.poem
            if let eraUUID = jsonPoem.eraUUID {
                let fetchDescriptor = FetchDescriptor<Era>(predicate: #Predicate{ era in
                    era.uuid == eraUUID
                })
                poem.era = try? container.mainContext.fetch(fetchDescriptor).first
            }
            if let eventUUIDs = jsonPoem.eventUUIDs, !eventUUIDs.isEmpty {
                var events: [Event] = []
                for eventUUID in eventUUIDs {
                    let fetchDescriptor = FetchDescriptor<Event>(predicate: #Predicate{ event in
                        event.uuid == eventUUID
                    })
                    if let event = try? container.mainContext.fetch(fetchDescriptor).first {
                        if !events.contains(event) {
                            events.append(event)
                        }
                    }
                }
                poem.events = events
            }
            if let subjectUUIDs = jsonPoem.subjectUUIDs, !subjectUUIDs.isEmpty {
                var subjects: [Subject] = []
                for subjectUUID in subjectUUIDs {
                    let fetchDescriptor = FetchDescriptor<Subject>(predicate: #Predicate{ subject in
                        subject.uuid == subjectUUID
                    })
                    if let subject = try? container.mainContext.fetch(fetchDescriptor).first {
                        if !subjects.contains(subject) {
                            subjects.append(subject)
                        }
                    }
                }
                poem.subjects = subjects
            }
            container.mainContext.insert(poem)
        }
    }
    
    var subjects: [Subject] {
        let descriptor = FetchDescriptor<Subject>()
        guard let subjects = try? container.mainContext.fetch(descriptor) else { return [Subject]() }
        return subjects.sorted()
    }
    
    var eras: [Era] {
        let descriptor = FetchDescriptor<Era>()
        guard let eras = try? container.mainContext.fetch(descriptor) else { return [Era]() }
        return eras.sorted()
    }
    
    var events: [Event] {
        let descriptor = FetchDescriptor<Event>()
        guard let events = try? container.mainContext.fetch(descriptor) else { return [Event]() }
        return events.sorted()
    }
    
    var poems: [Poem] {
        let descriptor = FetchDescriptor<Poem>()
        guard let poems = try? container.mainContext.fetch(descriptor) else { return [Poem]() }
        return poems.sorted()
    }
    
    var book: Book? {
        let descriptor = FetchDescriptor<Book>()
        let books = try? container.mainContext.fetch(descriptor)
        return books?.first
    }
}

// EditorDelete calls delete(item) in the delete button's action.
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
