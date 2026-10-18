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
        let fetchDescriptor = FetchDescriptor<T>()
        if let last = try container.mainContext.fetch(fetchDescriptor).sorted(by: { $0.fileOrder < $1.fileOrder }).last {
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
        }
    }
}
