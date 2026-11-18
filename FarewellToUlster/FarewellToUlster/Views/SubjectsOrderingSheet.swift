//
//  SubjectsOrderingSheet.swift
//  FarewellToUlster
//
//  Created by Michael Scott on 13/05/2026.
//

import SwiftUI
import SwiftData

struct SubjectsOrderingSheet: View {
    @Environment(Storage.self) private var storage
    @Query private var allSubjects: [Subject]
    @Environment(\.dismiss) private var dismiss
    @State private var subjects: [Subject] = []
    @State private var initialSortedSubjects: [Subject] = []

    var body: some View {
        NavigationStack {
            List($subjects, editActions: .move) { $subject in
                Text(subject.title)
            }
            .listStyle(.plain)
            // Always in edit mode, so the subjects can be dragged straight away.
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Subject Order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        _subjects.wrappedValue = initialSortedSubjects
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", role: .confirm) {
                        for index in subjects.indices {
                            subjects[index].sortIndex = index
                        }
                        storage.save()
                        dismiss()
                    }
                }
            }
        }
        .onAppear() {
            // Sorting by title first keeps subjects with the same sortIndex in title order.
            initialSortedSubjects = allSubjects.sorted().sorted(using: [SortDescriptor(\.sortIndex)])
            subjects = initialSortedSubjects
        }
    }
}

#if DEBUG
#Preview(traits: .sampleData) {
    SubjectsOrderingSheet()
}
#endif
