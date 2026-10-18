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
    @Query private var poems: [Poem]
    @State private var searchText = ""
    @State private var currentTokens: [PoemSearchToken] = []

    var body: some View {
        @Bindable var navigation = navigation
        // Computed once, because searching the poems' text is slow enough to avoid doing twice.
        let shownPoems = selectedPoems
        NavigationStack(path: $navigation.poemsPath) {
            PoemsList(poems: shownPoems)
            .overlay {
                if shownPoems.isEmpty {
                    if !searchText.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                    } else if let token = currentTokens.first {
                        // ContentUnavailableView.search would show empty quotes, as there is no search text.
                        ContentUnavailableView("No Results for “\(token.rawValue)”", systemImage: "magnifyingglass", description: Text("No poems match this token."))
                    }
                }
            }
            .searchable(text: $searchText, tokens: $currentTokens) { token in
                Text(token.rawValue)
            }
            .searchSuggestions {
                // Only one token is used for filtering, so stop suggesting once one is chosen.
                if searchText.isEmpty && currentTokens.isEmpty {
                    tokenSection("Status", tokens: PoemSearchToken.statusCases)
                    tokenSection("Category", tokens: PoemSearchToken.categoryCases)
                    tokenSection("Other", tokens: PoemSearchToken.otherCases)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackgroundVisibility(.visible, for: .tabBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: addPoem) {
                        Label("Add poem", systemImage: "plus")
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
    
    // Not sorted here, because selectedPoems sorts the poems after filtering them.
    private func filteredPoems(token: PoemSearchToken?) -> [Poem] {
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
    
    private func tokenSection(_ title: String, tokens: [PoemSearchToken]) -> some View {
        Section {
            // The title is a row rather than a section header, because headers stay
            // pinned at the top after their rows have scrolled away.
            // Without a search completion the row can't be tapped.
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.primary)
                .padding(.top)
                .listRowSeparator(.hidden)
            ForEach(tokens) { token in
                Text(token.rawValue)
                    .searchCompletion(token)
            }
        }
    }
    
    private func addPoem() {
        withAnimation {
            let newPoem = Poem()
            newPoem.status = .undevelopedIdea
            if storage.add(newPoem) {
                navigation.poemsPath.append(Path.poem(newPoem))
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
