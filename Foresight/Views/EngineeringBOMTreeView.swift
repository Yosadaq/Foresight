
//
// EngineeringBOMTreeView.swift
// Foresight
//

import SwiftUI

struct EngineeringBOMTreeView: View {

    let partNumber: String
    let repository: any ForesightRCARepository

    var visited: Set<String> = []
    var depth: Int = 0

    @State private var part: RCAPartHealth?
    @State private var loading = true
    @State private var errorMessage: String?

    var body: some View {

        List {

            if loading {

                ProgressView(
                    "Loading assembly relationships..."
                )

            } else if let part {

                Section("Selected Component") {

                    LabeledContent(
                        "Part Number",
                        value: part.partNumber
                    )

                    LabeledContent(
                        "Description",
                        value: part.name
                    )

                    LabeledContent(
                        "Revision",
                        value: part.revision ?? "Unverified"
                    )

                    LabeledContent(
                        "Material",
                        value: part.materialName ?? "Unverified"
                    )

                    LabeledContent(
                        "Unit",
                        value: part.unitOfMeasure
                    )

                    LabeledContent(
                        "Scrap Factor",
                        value: part.scrapFactor.map {
                            String(format: "%.1f%%", $0 * 100)
                        } ?? "Unverified"
                    )
                }

                Section("Bill of Materials") {

                    if part.bomComponents.isEmpty {

                        Text(
                            "No further child components are recorded."
                        )
                        .foregroundStyle(.secondary)

                    } else {

                        ForEach(part.bomComponents) { child in

                            let alreadyVisited =
                                visited.contains(
                                    child.partNumber
                                )
                                || child.partNumber == partNumber

                            let depthLimitReached = depth >= 12

                            if alreadyVisited
                                || depthLimitReached {

                                componentRow(child)

                                Label(
                                    alreadyVisited
                                    ? "Circular BOM reference detected"
                                    : "Hierarchy depth limit reached",
                                    systemImage:
                                        "exclamationmark.triangle"
                                )
                                .font(.caption)
                                .foregroundStyle(.orange)

                            } else {

                                NavigationLink {

                                    EngineeringBOMTreeView(
                                        partNumber: child.partNumber,
                                        repository: repository,
                                        visited: visited.union([
                                            partNumber
                                        ]),
                                        depth: depth + 1
                                    )

                                } label: {

                                    componentRow(child)
                                }
                            }
                        }
                    }
                }

            } else {

                ContentUnavailableView(
                    "Component Data Unavailable",
                    systemImage: "shippingbox",
                    description: Text(
                        errorMessage
                        ?? "No engineering record found."
                    )
                )
            }
        }
        .navigationTitle("BOM Breakdown")
        .task(id: partNumber) {
            await load()
        }
    }

    private func componentRow(
        _ child: RCABOMComponent
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 7
        ) {

            Label(
                child.partNumber,
                systemImage: "shippingbox.fill"
            )
            .font(.headline)

            HStack {

                Text(
                    "Rev \(child.revision.isEmpty ? "Unknown" : child.revision)"
                )

                Spacer()

                Text(
                    "\(child.quantityPer.formatted()) \(child.unit) / parent"
                )
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }

    @MainActor
    private func load() async {

        loading = true
        errorMessage = nil

        defer {
            loading = false
        }

        do {

            part = try await repository.loadPart(
                number: partNumber
            )

        } catch {

            errorMessage = error.localizedDescription
        }
    }
}
