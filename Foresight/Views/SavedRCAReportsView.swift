
//
// SavedRCAReportsView.swift
// Foresight
//

import SwiftUI

struct SavedRCAReportsView: View {

    @State private var reports: [SavedVoiceRCA] = []
    @State private var errorMessage: String?

    var body: some View {

        List {

            if reports.isEmpty {

                ContentUnavailableView(
                    "No Saved Investigations",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text(
                        errorMessage
                        ?? "Generate an AI root cause report to see it here."
                    )
                )

            } else {

                ForEach(reports) { report in

                    NavigationLink {

                        SavedRCAReportDetailsView(
                            report: report
                        )

                    } label: {

                        VStack(
                            alignment: .leading,
                            spacing: 7
                        ) {

                            Text(report.partNumber)
                                .font(.headline)

                            Text(
                                report.report.summary
                            )
                            .font(.subheadline)
                            .lineLimit(2)
                            .foregroundStyle(.secondary)

                            Text(
                                report.createdAt.formatted(
                                    date: .abbreviated,
                                    time: .shortened
                                )
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 5)
                    }
                }
            }
        }
        .navigationTitle("RCA Reports")
        .onAppear {
            reload()
        }
        .refreshable {
            reload()
        }
    }

    private func reload() {

        do {
            reports = try VoiceRCAStorage.loadAll()
            errorMessage = nil

        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct SavedRCAReportDetailsView: View {

    let report: SavedVoiceRCA


    
    var body: some View {

        ScrollView {

            RCAReportPresentationView(
                saved: report
            )
            .padding(16)
        }
        .background(
            Color(
                red: 0.95,
                green: 0.96,
                blue: 0.98
            )
            .ignoresSafeArea()
        )
        .navigationTitle("Investigation Report")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.light)
    }

}
