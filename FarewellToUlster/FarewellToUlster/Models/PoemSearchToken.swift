//
//  PoemSearchToken.swift
//  FarewellToUlster
//
//  Created by Michael Scott on 13/05/2026.
//

import Foundation

/// The various tokens that can be used to filter a list of poems.
enum PoemSearchToken {
    internal static let duplicateTitleString = "duplicate title"
    internal static let firstLineTitleString = "first line title"
    internal static let uncategorisedString = "uncategorised"
    internal static let noSubjectsString = "no subjects"

    case category(PoemCategory)
    case status(PoemStatus)
    case uncategorised
    case noSubjects
    case duplicateTitle
    case firstLineTitle
}

extension PoemSearchToken: CaseIterable {
    static var statusCases: [PoemSearchToken] {
        PoemStatus.allCases.map { .status($0) }
    }

    static var categoryCases: [PoemSearchToken] {
        PoemCategory.allCases.map { .category($0) }
    }

    static var otherCases: [PoemSearchToken] {
        [.uncategorised, .noSubjects, .duplicateTitle, .firstLineTitle]
    }

    static var allCases: [PoemSearchToken] {
        statusCases + categoryCases + otherCases
    }
}

extension PoemSearchToken: RawRepresentable {
    typealias RawValue = String
    
    init?(rawValue: String) {
        switch rawValue {
        case Self.uncategorisedString:
            self = .uncategorised
        case Self.noSubjectsString:
            self = .noSubjects
        case Self.duplicateTitleString:
            self = .duplicateTitle
        case Self.firstLineTitleString:
            self = .firstLineTitle
        case PoemStatus(rawValue: rawValue)?.rawValue:
            guard let status = PoemStatus(rawValue: rawValue) else { return nil }
            self = .status(status)
        case PoemCategory(rawValue: rawValue)?.rawValue:
            guard let category = PoemCategory(rawValue: rawValue) else { return nil }
            self = .category(category)
        default:
            return nil
        }
    }
    
    var rawValue: String {
        switch self {
        case .status(let status):
            return status.rawValue
        case .category(let category):
            return category.rawValue
        case .uncategorised:
            return Self.uncategorisedString
        case .noSubjects:
            return Self.noSubjectsString
        case .duplicateTitle:
            return Self.duplicateTitleString
        case .firstLineTitle:
            return Self.firstLineTitleString
        }
    }
}

extension PoemSearchToken: Identifiable {
    var id: String {
        rawValue
    }
}

extension PoemSearchToken: CustomStringConvertible {
    var description: String {
        rawValue
    }
}

extension PoemSearchToken: Equatable {}

extension PoemSearchToken {
    /// Return the poems that match this token, keeping their order.
    func filter(_ poems: [Poem]) -> [Poem] {
        switch self {
        case .status(let status):
            return poems.filter { $0.status == status }
        case .category(let category):
            return poems.filter { $0.category == category }
        case .uncategorised:
            return poems.filter { !$0.isCategorised }
        case .noSubjects:
            return poems.filter { $0.subjects?.isEmpty ?? true }
        case .duplicateTitle:
            // Count the titles once, rather than rescanning the poems for each one.
            let titleCounts = Dictionary(poems.map { ($0.title, 1) }, uniquingKeysWith: +)
            return poems.filter { titleCounts[$0.title, default: 0] > 1 }
        case .firstLineTitle:
            return poems.filter { $0.titleIsFirstLine }
        }
    }
}
