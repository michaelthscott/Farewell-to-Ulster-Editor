//
//  PoemsTab.swift
//  FarewellToUlster
//
//  Created by Michael Scott on 13/05/2026.
//

import SwiftUI
import SwiftData

/// Displays the poems. If an era, evemt of subject is selected then the list will be filtered to match the selection. The poems can be searched by status or text.
struct PoemsTab: View {
    @Environment(Navigation.self) private var navigation
    @Environment(Storage.self) private var storage
    @State private var searchText = ""
    @State private var allTokens: [PoemSearchToken] = PoemSearchToken.allCases
    @State private var currentTokens: [PoemSearchToken] = []
    @State private var addFailed: Bool = false
    @State private var addError: String = ""

    var body: some View {
        @Bindable var navigation = navigation
        NavigationStack(path: $navigation.poemsPath) {
            PoemsList(poems: selectedPoems)
            .searchable(text: $searchText, tokens: $currentTokens, suggestedTokens: $allTokens) { token in
                PoemSearchTokenView(token: token)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackgroundVisibility(.visible, for: .tabBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: addPoem) {
                        Label("Add poem", systemImage: "plus")
                    }
                    .alert("Add failed: \(addError)", isPresented: $addFailed) {
                        Button("Ok", role: .cancel) {
                            addFailed = false
                            addError = ""
                        }
                    }
                }
            }
        }
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled(true)
    }
    
    var title: String {
        if let era = navigation.selectedEra {
            return "Poems: \(era.title)"
        } else if let event = navigation.selectedEvent {
            return "Poems: \(event.title)"
        } else if let subject = navigation.selectedSubject {
            return "Poems: \(subject.title)"
        }
        return "Poems"
    }
    
    private func filteredPoems(token: PoemSearchToken?) -> [Poem] {
        let poems = storage.poems
        guard let token else { return poems }
        return token.filter(poems)
    }
    
    var selectedPoems: [Poem] {
        if !searchText.isEmpty {
            return filteredPoems(token: currentTokens.first).filter { poem in
                poem.text.localizedCaseInsensitiveContains(searchText) || poem.title.localizedCaseInsensitiveContains(searchText)
            }.sorted()
        }
        if let selectedEvent = navigation.selectedEvent {
            return filteredPoems(token: currentTokens.first).filter { poem in
                guard let events = poem.events else { return false }
                return events.contains(selectedEvent)
            }.sorted()
        }
        if let selectedEra = navigation.selectedEra {
            return filteredPoems(token: currentTokens.first).filter { poem in
                poem.era == selectedEra
            }.sorted()
        }
        if let selectedSubject = navigation.selectedSubject {
            return filteredPoems(token: currentTokens.first).filter { poem in
                guard let subjects = poem.subjects else { return false }
                return subjects.contains(selectedSubject)
            }.sorted()
        }
        return filteredPoems(token: currentTokens.first).sorted()
    }
    
    private func addPoem() {
        withAnimation {
            let newPoem = Poem()
            newPoem.status = .undevelopedIdea
            do {
                try storage.insertOrdered(newPoem)
                navigation.poemsPath.append(Path.poem(newPoem))
            } catch let error as FileOrderedError {
                // If the model is new and in an unsaved state, the context simply discards it.
                storage.delete(newPoem)
                addFailed = true
                addError = error.description
            } catch {
                storage.delete(newPoem)
                addFailed = true
                addError = "Unknown"
            }
        }
    }
}

#if DEBUG
#Preview(traits: .sampleData) {
    @Previewable @State var navigation = Navigation()
    return PoemsTab()
        .environment(navigation)
}
#endif
