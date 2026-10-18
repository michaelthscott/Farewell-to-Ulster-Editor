//
//  ErasTab.swift
//  FarewellToUlster
//
//  Created by Michael Scott on 13/05/2026.
//

import SwiftUI
import SwiftData

/// Display the eras. One era can be selected.
struct ErasTab: View {
    @Environment(Navigation.self) private var navigation
    @Environment(Storage.self) private var storage
    @Query private var eras: [Era]
    @State private var searchText = ""

    var body: some View {
        @Bindable var navigation = navigation
        NavigationStack(path: $navigation.erasPath) {
            List {
                ForEach(selectedEras) { era in
                    NavigationLink(value: Path.era(era)) {
                        Label {
                            Text(era.title)
                                .font(.headline)
                            Text(era.period.periodDescription)
                                .font(.subheadline)
                        } icon: {
                            Image(systemName: "checkmark")
                                .opacity(navigation.selectedEra == era ? 1.0 : 0.0)
                                .onTapGesture {
                                    if navigation.selectedEra == era {
                                        navigation.selectedEra = nil
                                    } else {
                                        navigation.selectedEra = era
                                        navigation.erasPath.append(Path.era(era))
                                    }
                                }
                        }
                        .badge(era.poemsCount)
                    }
                }
            }
            .overlay {
                if !searchText.isEmpty && selectedEras.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .navigationDestination(for: Path.self) { path in
                DestinationView(path: path)
            }
            .navigationTitle("Eras")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackgroundVisibility(.visible, for: .tabBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: addEra) {
                        Label("Add era", systemImage: "plus")
                    }
                }
            }
        }
        .searchable(text: $searchText)
    }
    
    var selectedEras: [Era] {
        // Sorted in memory, so the order matches Era's Comparable conformance.
        let sortedEras = eras.sorted()
        guard !searchText.isEmpty else { return sortedEras }
        return sortedEras.filter { era in
            era.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func addEra() {
        withAnimation {
            let newEra = Era()
            if storage.add(newEra) {
                navigation.erasPath.append(Path.era(newEra))
            }
        }
    }
}

#if DEBUG
#Preview(traits: .sampleData) {
    @Previewable @State var navigation = Navigation()
    ErasTab()
        .environment(navigation)
}
#endif
