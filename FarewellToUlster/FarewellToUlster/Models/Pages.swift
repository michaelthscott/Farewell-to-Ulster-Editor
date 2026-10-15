//
//  Pages.swift
//  FarewellToUlster
//
//  Created by Michael Scott on 07/08/2026.
//

import Foundation

struct Pages {
    let storage: Storage
    
    // These throw rather than returning no pages, so a failed fetch can't be mistaken for an empty book.
    func pages(for era: Era) throws -> [Page] {
        let book = try storage.fetchBook()
        var pages: [Page] = []
        var pageNumber: Int = 1
        pages.append(Page(type: .era(book, era), number: pageNumber))
        guard let poems = era.poems else { return pages }
        for poem in poems.vectorSorted() {
            pageNumber += 1
            pages.append(Page(type: .poem(book, era, poem), number: pageNumber))
        }
        return pages
    }
    
    func allPages() throws -> [Page] {
        let book = try storage.fetchBook()
        var pages: [Page] = []
        var pageNumber: Int = 1
        pages.append(Page(type: .book(book), number: pageNumber))
        for era in try storage.fetchEras() {
            pageNumber += 1
            pages.append(Page(type: .era(book, era), number: pageNumber))
            guard let poems = era.poems else { continue }
            for poem in poems.vectorSorted() {
                pageNumber += 1
                pages.append(Page(type: .poem(book, era, poem), number: pageNumber))
            }
        }
        return pages
    }

}
