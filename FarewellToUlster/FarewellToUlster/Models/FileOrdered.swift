//
//  FileOrdered.swift
//  FarewellToUlster
//
//  Created by Michael Scott on 13/05/2026.
//

import Foundation
import SwiftData

/// In order to make the minimum changes to the persistent JSON file, the models have a fileOrder property that does not change. When a new model is added it is given the next available value.
nonisolated protocol FileOrdered: PersistentModel {
    var fileOrder: String { get set }
}

/// An error that can be encountered while inserting a model. Fetch and save errors are passed on as they are, so the message shows what actually went wrong.
enum FileOrderedError: LocalizedError, CustomStringConvertible, Equatable {
    case alreadyExists
    case parseFailed(fileOrder: String)

    var description: String {
        switch self {
        case .alreadyExists: return "Already exists"
        case .parseFailed(let fileOrder): return "Could not parse the file order \"\(fileOrder)\""
        }
    }

    /// Used by localizedDescription, so alerts that show it give the same message.
    var errorDescription: String? {
        description
    }
}

extension Storage {
    /// Insert a new model with the next fileOrder after the existing ones, and save it.
    func insertOrdered<T: FileOrdered>(_ model: T) throws {
        let identifier = model.persistentModelID
        let existing: T? = container.mainContext.registeredModel(for: identifier)
        guard existing == nil else {
            throw FileOrderedError.alreadyExists
        }
        // Only the highest fileOrder is needed, so let the database sort and fetch just that one.
        var fetchDescriptor = FetchDescriptor<T>(sortBy: [SortDescriptor(\.fileOrder, order: .reverse)])
        fetchDescriptor.fetchLimit = 1
        if let last = try container.mainContext.fetch(fetchDescriptor).first {
            guard let number = Int(last.fileOrder) else {
                throw FileOrderedError.parseFailed(fileOrder: last.fileOrder)
            }
            model.fileOrder = String(format: "%04d", number + 1)
        } else {
            model.fileOrder = "0001"
        }
        container.mainContext.insert(model)
        if container.mainContext.hasChanges {
            try container.mainContext.save()
            hasUncommittedChanges = true
        }
    }

    /// Insert a new model, as the tabs' add buttons do. Returns whether it was added.
    /// On failure the model is discarded, and the error is kept in addError so ContentView can report it.
    func add<T: FileOrdered>(_ model: T) -> Bool {
        do {
            try insertOrdered(model)
            return true
        } catch {
            // If the model is new and in an unsaved state, the context simply discards it.
            delete(model)
            addError = error
            return false
        }
    }
}
