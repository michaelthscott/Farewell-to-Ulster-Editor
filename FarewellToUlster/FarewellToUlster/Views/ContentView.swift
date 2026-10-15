//
//  ContentView.swift
//  FarewellToUlster
//
//  Created by Michael Scott on 13/05/2026.
//

import SwiftUI
import SwiftData

/// Display and select eras, events and subjects, to filter the poems.
struct ContentView: View {
    @Environment(Navigation.self) private var navigation
    @Environment(Storage.self) private var storage

    var body: some View {
        @Bindable var navigation = navigation
        TabView(selection: $navigation.selectedTab) {
            Tab("Book", systemImage: "book", value: TabValue.book) {
                BookTab()
            }
            Tab("Eras", systemImage: "calendar", value: TabValue.eras) {
                ErasTab()
            }
            .badge(
                navigation.selectedEra != nil ? Text("✓") : nil
            )
            Tab("Events", systemImage: "clock", value: TabValue.events) {
                EventsTab()
            }
            .badge(
                navigation.selectedEvent != nil ? Text("✓") : nil
            )
            Tab("Subjects", systemImage: "list.bullet", value: TabValue.subjects) {
                SubjectsTab()
            }
            .badge(
                navigation.selectedSubject != nil ? Text("✓") : nil
            )
            Tab("Poems", systemImage: "book.pages", value: TabValue.poems) {
                PoemsTab()
            }
        }
        .alert("Save failed: \(storage.saveError?.localizedDescription ?? "")", isPresented: saveFailed) {
            Button("Ok", role: .cancel) {
                storage.saveError = nil
            }
        }
    }

    /// Presents the alert while Storage holds a save error, and clears the error when the alert is dismissed.
    private var saveFailed: Binding<Bool> {
        Binding(
            get: { storage.saveError != nil },
            set: { if !$0 { storage.saveError = nil } }
        )
    }
}

#if DEBUG
#Preview(traits: .sampleData) {
    @Previewable @State var navigation = Navigation()
    ContentView()
        .environment(navigation)
}
#endif
