//
//  JSONTests.swift
//  FarewellToUlsterTests
//
//  Created by Michael Scott on 13/05/2026.
//

import Foundation
import Testing
internal import UniformTypeIdentifiers
@testable import FarewellToUlster

@Suite("JSON Tests")
struct JSONTests {

    @Test("JSONBook")
    func testBook() throws {
        let book = JSONBook(title: "", author: "")
        #expect(book.title == "")
        #expect(book.author == "")
    }

    @Test("JSONEra")
    func testEra() throws {
        let uuid = UUID()
        let era = JSONEra(fileOrder: "", uuid: uuid, title: "", start: "", end: "", text: "")
        #expect(era.fileOrder == "")
        #expect(era.uuid == uuid)
        #expect(era.title == "")
        #expect(era.start == "")
        #expect(era.end == "")
        #expect(era.text == "")
    }
    
    @Test("JSONEvent")
    func testEvent() throws {
        let uuid = UUID()
        let event = JSONEvent(fileOrder: "", uuid: uuid, title: "", date: "")
        #expect(event.fileOrder == "")
        #expect(event.uuid == uuid)
        #expect(event.title == "")
        #expect(event.date == "")
    }
    
    @Test("JSONPoem")
    func testPoem() throws {
        let uuid = UUID()
        let poem = JSONPoem(fileOrder: "", uuid: uuid, title: "", text: "")
        #expect(poem.fileOrder == "")
        #expect(poem.uuid == uuid)
        #expect(poem.title == "")
        #expect(poem.text == "")
    }

    @Test("JSONPoem keeps the poems marked as not duplicates")
    func testPoemDistinctPoemUUIDs() throws {
        let distinct = [UUID(), UUID()]
        let poem = JSONPoem(fileOrder: "0001", uuid: UUID(), title: "", text: "", distinctPoemUUIDs: distinct)
        let decoded = try JSONDecoder().decode(JSONPoem.self, from: JSONEncoder().encode(poem))
        #expect(decoded.distinctPoemUUIDs == distinct)
        #expect(decoded.poem.distinctPoemUUIDs == distinct)
    }

    @Test("JSONPoem leaves out distinctPoemUUIDs when there are none")
    func testPoemNoDistinctPoemUUIDs() throws {
        let poem = JSONPoem(fileOrder: "0001", uuid: UUID(), title: "", text: "")
        let json = try #require(String(data: JSONEncoder().encode(poem), encoding: .utf8))
        #expect(!json.contains("distinctPoemUUIDs"))
        let decoded = try JSONDecoder().decode(JSONPoem.self, from: Data(json.utf8))
        #expect(decoded.distinctPoemUUIDs == nil)
        #expect(decoded.poem.distinctPoemUUIDs.isEmpty)
    }

    @Test("JSONSubject")
    func testSubject() throws {
        let uuid = UUID()
        let subject = JSONSubject(fileOrder: "", uuid: uuid, title: "", category: "", sortIndex: 0)
        #expect(subject.fileOrder == "")
        #expect(subject.uuid == uuid)
        #expect(subject.title == "")
        #expect(subject.category == "")
        #expect(subject.sortIndex == 0)
    }
    
    @Test("JSONFile")
    func testFile() throws {
        let book = Book(title: "", author: "")
        let file = JSONFile(book: book, eras: [], events: [], subjects: [], poems: [])
        let regex = /^\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}\.json$/
        #expect(file.fileName.wholeMatch(of: regex) != nil)
        #expect(file.contentType.description == "public.json")
        #expect(file.document.data.isEmpty == false)
    }
}
