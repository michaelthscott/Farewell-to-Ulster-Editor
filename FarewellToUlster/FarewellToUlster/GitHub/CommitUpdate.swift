//
//  CommitUpdate.swift
//  FarewellToUlster
//
//  Created by Michael Scott on 18/11/2026.
//

import Foundation
import Observation

/// Commits the book to the site, and holds the progress and outcome so any tab can show them.
@MainActor
@Observable
final class CommitUpdate {
    private(set) var isCommitting: Bool = false
    var outcome: CommitOutcome?

    func commit(storage: Storage) async {
        guard !isCommitting else { return }
        isCommitting = true
        var outcome = CommitOutcome()
        defer {
            // Only a complete update clears the uncommitted changes, so a failed commit is still flagged.
            if outcome.failures.isEmpty {
                storage.hasUncommittedChanges = false
            }
            self.outcome = outcome
            isCommitting = false
        }

        // Fetch everything before committing anything, so a failed fetch stops the update
        // rather than committing a book with parts missing.
        let jsonFile: JSONFile
        let eras: [Era]
        do {
            jsonFile = try JSONFile(storage: storage)
            eras = try storage.fetchEras()
        } catch {
            outcome.record(target: "JSON file", message: "Could not build the JSON file: \(error.localizedDescription)")
            return
        }

        let data = jsonFile.document.data

        // The only copy of the book lives with the site. The app loads it from there when there is no book.
        let localFile = LocalFile(path: GitHubClient.bookPath, content: data)

        var localFiles: [LocalFile] = [localFile]
        let client = GitHubClient.site
        do {
            let sha = try await client.batchCommit(files: localFiles, message: "Editor update for JSON file")
            outcome.record(target: "JSON file", commitSHA: sha)
        } catch {
            outcome.record(target: "JSON file", error: error)
            // A dead token fails every remaining commit identically, so stop here.
            if outcome.needsToken { return }
        }

        for era in eras {
            // An era with no poems has nothing to write, but still counts towards the
            // total so the summary matches the number of eras in the book.
            guard let poems = era.poems else {
                outcome.record(target: era.title, commitSHA: nil)
                continue
            }
            let eraInfo: MDInfo = .era(title: era.title, number: era.fileOrder)
            localFiles = []
            let sortedPoems = poems.vectorSorted()
            let neighbours = sortedPoems.neighbours
            var mdPoems = [MDPoem]()
            for cursor in neighbours {
                let mdPoem = MDPoem(eraInfo: eraInfo,
                                    info: cursor.currentInfo,
                                    previousInfo: cursor.previousInfo,
                                    nextInfo: cursor.nextInfo,
                                    text: cursor.currentText)
                mdPoems.append(mdPoem)
            }
            let mdEra = MDEra(info: eraInfo, text: era.text, poems: mdPoems)
            localFiles.append(LocalFile(path: mdEra.path, content: mdEra.data))
            for mdPoem in mdEra.poems {
                localFiles.append(LocalFile(path: mdPoem.path, content: mdPoem.data))
            }
            do {
                let sha = try await client.batchCommit(files: localFiles, message: "Editor update for era: \(mdEra.info.title)")
                outcome.record(target: mdEra.info.title, commitSHA: sha)
            } catch {
                outcome.record(target: mdEra.info.title, error: error)
                if outcome.needsToken { return }
            }
        }
    }
}
