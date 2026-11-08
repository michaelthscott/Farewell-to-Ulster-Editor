//
//  SettingsView.swift
//  FarewellToUlster
//
//  Created by Michael Scott on 08/11/2026.
//

import SwiftUI

/// App settings, reached from the Book tab menu.
struct SettingsView: View {
    @AppStorage(PoemSimilarity.thresholdKey) private var threshold = PoemSimilarity.defaultThreshold
    @AppStorage(PoemSimilarity.subjectWeightKey) private var subjectWeight = PoemSimilarity.defaultSubjectWeight
    // Assume it's available until checked, so the warning doesn't flash up.
    @State private var isSimilarityAvailable = true

    var body: some View {
        Form {
            Section {
                LabeledContent("Threshold", value: threshold.formatted(.number.precision(.fractionLength(2))))
                Slider(value: $threshold, in: PoemSimilarity.thresholdRange, step: 0.01) {
                    Text("Threshold")
                }
                LabeledContent("Subject weight", value: subjectWeight.formatted(.number.precision(.fractionLength(2))))
                Slider(value: $subjectWeight, in: PoemSimilarity.subjectWeightRange, step: 0.05) {
                    Text("Subject weight")
                }
            } header: {
                Text("Similar Poems")
            } footer: {
                if isSimilarityAvailable {
                    Text("Pairs of poems in an era at least this similar are listed on the era's page. Raise the threshold to list fewer pairs. Subjects a pair shares raise its score, rare subjects most; set the weight to 0 to ignore subjects.")
                } else {
                    Label("This device doesn't have the English sentence embedding, so no similar poems can be found.", systemImage: "exclamationmark.triangle")
                }
            }
            Section {
                NavigationLink("GitHub Token") {
                    GitHubSettingsView()
                        .navigationTitle("GitHub")
                }
            }
        }
        .onAppear {
            // Bring an older setting from the wider range into the slider's range.
            threshold = PoemSimilarity.practicalThreshold(threshold)
        }
        .task {
            isSimilarityAvailable = await PoemSimilarity.shared.isAvailable
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .navigationTitle("Settings")
    }
}
