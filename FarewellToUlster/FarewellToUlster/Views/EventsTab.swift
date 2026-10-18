//
//  EventsTab.swift
//  FarewellToUlster
//
//  Created by Michael Scott on 13/05/2026.
//

import SwiftUI
import SwiftData

/// Display the events. If an era is selected then only the events within that era will be displayed.
struct EventsTab: View {
    @Environment(Navigation.self) private var navigation
    @Environment(Storage.self) private var storage
    @Query private var events: [Event]
    @Query private var eras: [Era]
    @State private var searchText = ""

    /// A list section: the events within an era, or the events outside every era when `era` is nil.
    struct EventSection: Identifiable {
        let era: Era?
        let events: [Event]
        var id: PersistentIdentifier? { era?.persistentModelID }
    }

    var body: some View {
        @Bindable var navigation = navigation
        NavigationStack(path: $navigation.eventsPath) {
            List {
                ForEach(eventSections) { section in
                    Section(section.era?.title ?? "Other") {
                        ForEach(section.events) { event in
                            eventRow(event)
                        }
                    }
                }
            }
            .overlay {
                if !searchText.isEmpty && selectedEvents.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .navigationDestination(for: Path.self) { path in
                DestinationView(path: path)
            }
            .navigationTitle("Events")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackgroundVisibility(.visible, for: .tabBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: addEvent) {
                        Label("Add event", systemImage: "plus")
                    }
                }
            }
        }
        .searchable(text: $searchText)
    }

    private func eventRow(_ event: Event) -> some View {
        NavigationLink(value: Path.event(event)) {
            Label {
                Text(event.title)
                    .font(.headline)
                Text(event.period.periodDescription)
                    .font(.subheadline)
            } icon: {
                Image(systemName: "checkmark")
                    .opacity(navigation.selectedEvent == event ? 1.0 : 0.0)
                    .onTapGesture {
                        if navigation.selectedEvent == event {
                            navigation.selectedEvent = nil
                        } else {
                            navigation.selectedEvent = event
                            navigation.eventsPath.append(Path.event(event))
                        }
                    }
            }
            .badge(event.poemsCount)
        }
    }

    /// The selected events grouped by the era containing their start. An event is placed in the
    /// first era that contains it, so overlapping eras never list it twice. Events outside every
    /// era are collected into a final section with no era. Empty sections are omitted.
    var eventSections: [EventSection] {
        let sectionEras = navigation.selectedEra.map { [$0] } ?? eras.sorted()
        var remaining = selectedEvents
        var sections: [EventSection] = []
        for era in sectionEras {
            let eraEvents = remaining.filter { era.period.contains($0.period.start) }
            guard !eraEvents.isEmpty else { continue }
            sections.append(EventSection(era: era, events: eraEvents))
            remaining.removeAll { era.period.contains($0.period.start) }
        }
        if !remaining.isEmpty {
            sections.append(EventSection(era: nil, events: remaining))
        }
        return sections
    }

    var selectedEvents: [Event] {
        guard !searchText.isEmpty else { return filteredEvents }
        return filteredEvents.filter { era in
            era.title.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var filteredEvents: [Event] {
        // Sorted in memory, so the order matches Event's Comparable conformance.
        let sortedEvents = events.sorted()
        guard let selectedEra = navigation.selectedEra else { return sortedEvents }
        return sortedEvents.filter { event in
            selectedEra.period.contains(event.period.start)
        }
    }
    
    private func addEvent() {
        withAnimation {
            let newEvent = Event()
            if storage.add(newEvent) {
                navigation.eventsPath.append(Path.event(newEvent))
            }
        }
    }
}

#if DEBUG
#Preview(traits: .sampleData) {
    @Previewable @State var navigation = Navigation()
    EventsTab()
        .environment(navigation)
}
#endif
