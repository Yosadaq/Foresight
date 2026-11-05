//
//  ScanResultsView.swift
//  Foresight
//
//  Created by Yosadaq Esparza on 10/27/26.
//


import SwiftUI

struct ScanResultsView: View {

    let result: ManufacturingScanResponse

    @State private var chosenMatches: [Int: String] = [:]
    @State private var confirmedCounts: [Int: Int] = [:]
    @State private var manualNumbers: [Int: String] = [:]
    @State private var loadedPart: ManufacturingLookup?
    @State private var showPartDetails = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let api = ManufacturingAPIService()

    private let navy = Color(
        red: 0.08,
        green: 0.12,
        blue: 0.21
    )

    private let muted = Color(
        red: 0.34,
        green: 0.39,
        blue: 0.47
    )

    private var confirmedTotal: Int {
        confirmedCounts.values.reduce(0, +)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                summaryCard

                if result.items.isEmpty {
                    Text("No identifiable parts detected.")
                        .foregroundStyle(muted)
                        .padding()
                }

                ForEach(result.items) { item in
                    itemCard(item)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding()
        }
        .background(
            Color(red: 0.95, green: 0.96, blue: 0.98)
                .ignoresSafeArea()
        )
        .navigationTitle("Scan Results")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(navy, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showPartDetails) {
            if let loadedPart {
                NavigationStack {
                    
                    ERPPartDetailsView(
                        lookup: loadedPart,
                        rcaRepository: VercelRCARepository()
                    )
                        .toolbar {
                            ToolbarItem(
                                placement: .topBarTrailing
                            ) {
                                Button("Done") {
                                    showPartDetails = false
                                }
                            }
                        }
                }
                .preferredColorScheme(.light)
            }
        }
        .preferredColorScheme(.light)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Manufacturing Scan")
                .font(.title2.bold())

            Text(
                "\(result.items.count) distinct object types detected"
            )
            .foregroundStyle(muted)

            if let total = result.totalVisibleCount {
                Text("\(total) objects reported by AI")
                    .font(.title3.bold())
            } else {
                Text("Some quantities could not be estimated")
                    .foregroundStyle(.orange)
            }

            Text(
                "Confirmed manually: \(confirmedTotal) pieces"
            )
            .font(.subheadline.bold())

            Label(
                "AI counts are estimates until reviewed.",
                systemImage: "exclamationmark.triangle"
            )
            .font(.caption)
            .foregroundStyle(muted)

            Text("No inventory quantities have been changed.")
                .font(.caption)
                .foregroundStyle(muted)
        }
        .foregroundStyle(navy)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
    }

    private func itemCard(
        _ item: DetectedManufacturingItem
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.label)
                        .font(.headline)
                        .foregroundStyle(navy)

                    Text(item.description)
                        .font(.subheadline)
                        .foregroundStyle(muted)
                }

                Spacer(minLength: 8)

                Text(
                    item.visibleCount.map { "\($0)" }
                    ?? "?"
                )
                .font(.title.bold())
                .foregroundStyle(navy)
            }

            Text(
                item.countType == "exact_visible"
                ? "AI reports individually visible items"
                : "Estimated count — review required"
            )
            .font(.caption)
            .foregroundStyle(muted)

            if !item.notes.isEmpty {
                Text(item.notes)
                    .font(.caption)
                    .foregroundStyle(muted)
            }

            if !item.partNumber.isEmpty {
                detailRow(
                    "Detected number",
                    item.partNumber
                )
            }

            if !item.visibleText.isEmpty {
                detailRow(
                    "Visible text",
                    item.visibleText
                )
            }

            Divider()

            Text("Manufacturing database matches")
                .font(.subheadline.bold())
                .foregroundStyle(navy)

            if item.lookupError {
                Text("Database search was unavailable.")
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            if item.matches.isEmpty {
                Text("No catalog candidates found.")
                    .foregroundStyle(muted)
                    .font(.caption)
            }

            ForEach(item.matches) { match in
                Button {
                    chosenMatches[item.id] = match.partNumber
                } label: {
                    HStack(spacing: 10) {
                        Image(
                            systemName:
                                chosenMatches[item.id]
                                == match.partNumber
                                ? "largecircle.fill.circle"
                                : "circle"
                        )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(match.partNumber)
                                .fontWeight(.semibold)

                            Text(
                                match.description ?? "No description"
                            )
                            .font(.caption)

                            if let detail = match.description2 {
                                Text(detail)
                                    .font(.caption2)
                            }

                            Text(
                                match.isExact
                                ? "Exact part-number match"
                                : "Description candidate — verify"
                            )
                            .font(.caption2)
                        }

                        Spacer()
                    }
                    .foregroundStyle(navy)
                    .padding(10)
                    .background(
                        Color.gray.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                }
                .buttonStyle(.plain)
            }

            TextField(
                "Or enter a part number",
                text: Binding(
                    get: { manualNumbers[item.id] ?? "" },
                    set: { manualNumbers[item.id] = $0 }
                )
            )
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .textFieldStyle(.roundedBorder)

            HStack {
                Text("Confirm quantity")
                    .font(.subheadline)
                    .foregroundStyle(navy)

                Spacer()

                Stepper(
                    value: Binding(
                        get: {
                            confirmedCounts[item.id]
                            ?? item.visibleCount
                            ?? 0
                        },
                        set: {
                            confirmedCounts[item.id] = $0
                        }
                    ),
                    in: 0...100000
                ) {
                    Text(
                        "\(confirmedCounts[item.id] ?? item.visibleCount ?? 0)"
                    )
                    .fontWeight(.semibold)
                    .foregroundStyle(navy)
                }
                .fixedSize()
            }

            Button {
                let manual = (
                    manualNumbers[item.id] ?? ""
                ).trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

                let number = manual.isEmpty
                    ? chosenMatches[item.id]
                    : manual

                guard let number, !number.isEmpty else {
                    errorMessage = "Select or enter a part number."
                    return
                }

                Task {
                    await openPart(number)
                }
            } label: {
                HStack {
                    if isLoading {
                        ProgressView()
                    }

                    Text("View Verified Part Details")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .disabled(isLoading)
        }
        .padding(16)
        .background(
            Color.white,
            in: RoundedRectangle(cornerRadius: 18)
        )
    }

    private func detailRow(
        _ title: String,
        _ value: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(muted)

            Text(value)
                .font(.subheadline)
                .foregroundStyle(navy)
                .textSelection(.enabled)
        }
    }

    @MainActor
    private func openPart(_ number: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            loadedPart = try await api.findPart(
                number: number
            )
            showPartDetails = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
