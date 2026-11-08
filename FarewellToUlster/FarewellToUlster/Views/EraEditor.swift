//
//  EraEditor.swift
//  FarewellToUlster
//
//  Created by Michael Scott on 13/05/2026.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Display and edit an era.
struct EraEditor: View {
    @Environment(Navigation.self) private var navigation
    let era: Era
    @State private var editedTitle = ""
    @State private var editedText = ""
    @State private var selectedPeriod: DateInterval = .init()
    @AppStorage(PoemSimilarity.thresholdKey) private var threshold = PoemSimilarity.defaultThreshold
    @AppStorage(PoemSimilarity.subjectWeightKey) private var subjectWeight = PoemSimilarity.defaultSubjectWeight
    // The similar poems section is hidden while there are none.
    @State private var similarPairs: [PoemPairsList.Pair] = []
    // Every poem in the book, whose average is subtracted when finding similar poems.
    @Query private var bookPoems: [Poem]

    var body: some View {
        Form {
            Section("Title") {
                TitleField(title: $editedTitle)
            }
            PeriodPicker(period: $selectedPeriod)
            TextSection(title: "Text", autocapitalization: .never, text: $editedText)
            if !similarPairs.isEmpty {
                PoemPairsList(pairs: similarPairs)
            }
        }
        .task(id: similarityRequest) {
            let pairs = await PoemPairsList.pairs(in: era.poems ?? [], for: similarityRequest)
            guard !Task.isCancelled else { return }
            similarPairs = pairs
        }
        .navigationTitle(Text("Edit Era"))
        .navigationBarBackButtonHidden(needsSave)
        .toolbar {
            EditorCancel(needsSave: needsSave)
            EditorSave(needsSave: needsSave) {
                era.title = editedTitle
                era.period = selectedPeriod
                era.text = editedText
            }
            EditorDelete(item: era)
        }
        .onAppear {
            navigation.selectedEra = era
            editedTitle = era.title
            selectedPeriod = era.period
            editedText  = era.text
        }
    }
    
    var needsSave: Bool {
        era.title != editedTitle || era.period != selectedPeriod || era.text != editedText
    }

    private var similarityRequest: PoemPairsList.Request {
        PoemPairsList.Request(poems: era.poems ?? [], bookPoems: bookPoems, threshold: PoemSimilarity.practicalThreshold(threshold), subjectWeight: subjectWeight)
    }
    
}

#if DEBUG
#Preview(traits: .sampleData) {
    @Previewable @State var navigation = Navigation()
    @Previewable @Environment(Storage.self) var storage
    NavigationStack {
        EraEditor(era: try! storage.fetchEras().first!)
            .navigationDestination(for: Path.self) { path in
                DestinationView(path: path)
            }
            .environment(navigation)
    }
}
#endif
