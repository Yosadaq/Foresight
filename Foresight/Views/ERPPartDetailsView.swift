
//
//  ERPPartDetailsView.swift
//  Foresight
//
//  Manufacturing Inventory Details
//  Database-backed engineering data + RCA
//

import SwiftUI

struct ERPPartDetailsView: View {

    let lookup: ManufacturingLookup

    var transactionService:
        (any ManufacturingTransactionService)? = nil

    var voiceAgent:
        (any ManufacturingVoiceFormAgent)? = nil

    // Supply the Supabase repository from the parent view.
    var rcaRepository:
        (any ForesightRCARepository)? = nil

    @State private var selectedManufacturingAction:
        ManufacturingAction?

    @State private var selectedRCA: RCARoute?

    @State private var engineeringPart: RCAPartHealth?
    @State private var isLoadingEngineering = false
    @State private var engineeringError: String?
    
    // MARK: - Color Theme

    private let navy = Color(
        red: 0.08,
        green: 0.12,
        blue: 0.21
    )

    private let primaryText = Color(
        red: 0.08,
        green: 0.12,
        blue: 0.21
    )

    private let secondaryText = Color(
        red: 0.35,
        green: 0.39,
        blue: 0.47
    )

    private let backgroundColor = Color(
        red: 0.95,
        green: 0.96,
        blue: 0.98
    )

    private let stockBackground = Color(
        red: 0.91,
        green: 0.93,
        blue: 0.96
    )

    private let productionGreen = Color(
        red: 0.18,
        green: 0.61,
        blue: 0.32
    )

    private let transferBlue = Color(
        red: 0.09,
        green: 0.45,
        blue: 0.89
    )

    private let scrapRed = Color(
        red: 0.84,
        green: 0.20,
        blue: 0.24
    )

    private let orderOrange = Color(
        red: 0.94,
        green: 0.46,
        blue: 0.13
    )

    private var selectedPartNumber: String {
        lookup.part.partNumber
    }

    // MARK: - Main View

    var body: some View {

        ScrollView {

            VStack(spacing: 18) {

                overviewCard

                stockCard

                actionsGrid

                informationCard

                rcaCard
            }
            .padding(16)
        }
        .background(
            backgroundColor.ignoresSafeArea()
        )
        .navigationTitle("Part Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(
            navy,
            for: .navigationBar
        )
        .toolbarBackground(
            .visible,
            for: .navigationBar
        )
        .toolbarColorScheme(
            .dark,
            for: .navigationBar
        )

        // Load engineering specifications for this ERP part.

        .task(id: selectedPartNumber) {
            await loadEngineeringData()
        }

        // Manufacturing transaction sheets.

        .sheet(
            item: $selectedManufacturingAction
        ) { action in

            transactionSheet(for: action)
        }

        // RCA investigation sheet.

        
        .sheet(item: $selectedRCA) { route in

            NavigationStack {

                if let repository = rcaRepository {

                    VoiceRCAInvestigationView(
                        partNumber: route.partNumber,
                        repository: repository
                    )

                } else {

                    ContentUnavailableView(
                        "RCA Unavailable",
                        systemImage: "exclamationmark.triangle",
                        description: Text(
                            "The manufacturing intelligence service is not connected."
                        )
                    )
                }
            }
            .preferredColorScheme(.light)
        }
    }

    // MARK: - Overview

    private var overviewCard: some View {

        VStack(
            alignment: .leading,
            spacing: 18
        ) {

            HStack(
                alignment: .top,
                spacing: 16
            ) {

                Image(
                    systemName: "shippingbox.fill"
                )
                .font(.system(size: 40))
                .foregroundStyle(navy)
                .frame(
                    width: 92,
                    height: 105
                )
                .background(
                    stockBackground,
                    in: RoundedRectangle(
                        cornerRadius: 14
                    )
                )

                VStack(
                    alignment: .leading,
                    spacing: 8
                ) {

                    Text(selectedPartNumber)
                        .font(
                            .system(
                                size: 25,
                                weight: .bold
                            )
                        )
                        .foregroundStyle(primaryText)

                    Text(
                        lookup.part.description
                        ?? "Unknown Manufacturing Part"
                    )
                    .font(.headline)
                    .foregroundStyle(primaryText)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )

                    if let description2 =
                        lookup.part.description2,
                       !description2.isEmpty {

                        Text(description2)
                            .font(.subheadline)
                            .foregroundStyle(
                                secondaryText
                            )
                    }
                }

                Spacer(minLength: 0)
            }

            Divider()

            detailRow(
                "Part Type",
                lookup.part.partType ?? "Unknown"
            )

            detailRow(
                "Type Code",
                lookup.part.typeCode ?? "N/A"
            )

            detailRow(
                "Data Source",
                lookup.source
            )
        }
        .padding(18)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .background(
            .white,
            in: RoundedRectangle(
                cornerRadius: 20
            )
        )
    }

    // MARK: - Stock Quantity

    private var stockCard: some View {

        VStack(
            alignment: .leading,
            spacing: 16
        ) {

            HStack(spacing: 10) {

                Image(
                    systemName: "square.stack.3d.up.fill"
                )
                .foregroundStyle(navy)

                Text("Stock Quantity")
                    .font(.headline)
                    .foregroundStyle(primaryText)

                Spacer()

                Text("ERP Import")
                    .font(.caption)
                    .foregroundStyle(secondaryText)
            }

            ScrollView(.horizontal) {

                HStack(spacing: 10) {

                    ForEach(lookup.inventory) { item in

                        stockCell(
                            title: item.area ?? "N/A",
                            quantity: item.balance,
                            highlighted: false
                        )
                    }

                    stockCell(
                        title: "Total",
                        quantity: lookup.totalBalance,
                        highlighted: true
                    )
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)

            if lookup.totalBalance < 0 {

                Label(
                    "Negative inventory balance detected. Review transaction history and verify the physical count.",
                    systemImage:
                        "exclamationmark.triangle.fill"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            }
        }
        .padding(16)
        .background(
            stockBackground,
            in: RoundedRectangle(
                cornerRadius: 20
            )
        )
    }

    private func stockCell(
        title: String,
        quantity: Double,
        highlighted: Bool
    ) -> some View {

        VStack(spacing: 9) {

            Text(title)
                .font(.caption.bold())
                .foregroundStyle(secondaryText)

            Text(quantity.formatted())
                .font(.title3.bold())
                .foregroundStyle(
                    quantity < 0
                    ? Color.red
                    : primaryText
                )
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(
            width: 100,
            height: 80
        )
        .background(
            highlighted
            ? Color(
                red: 0.82,
                green: 0.89,
                blue: 0.99
            )
            : Color.white,
            in: RoundedRectangle(
                cornerRadius: 12
            )
        )
    }

    // MARK: - Manufacturing Actions

    private var actionsGrid: some View {

        LazyVGrid(
            columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ],
            spacing: 12
        ) {

            actionTile(
                title: "Report Production",
                subtitle: "Add completed pieces",
                icon: "building.2.fill",
                color: productionGreen,
                action: .production
            )

            actionTile(
                title: "Transfer Pieces",
                subtitle: "Move to another area",
                icon: "arrow.left.arrow.right",
                color: transferBlue,
                action: .transfer
            )

            actionTile(
                title: "Report Scrap",
                subtitle: "Record scrap pieces",
                icon: "trash.fill",
                color: scrapRed,
                action: .scrap
            )

            actionTile(
                title: "Report to MO",
                subtitle: "Manufacturing order",
                icon: "doc.text.fill",
                color: orderOrange,
                action: .manufacturingOrder
            )
        }
    }

    private func actionTile(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        action: ManufacturingAction
    ) -> some View {

        Button {

            selectedManufacturingAction = action

        } label: {

            VStack(
                alignment: .leading,
                spacing: 12
            ) {

                Image(systemName: icon)
                    .font(.title2)

                Spacer(minLength: 8)

                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.subheadline)
                    .opacity(0.9)
            }
            .foregroundStyle(.white)
            .frame(
                maxWidth: .infinity,
                minHeight: 120,
                alignment: .leading
            )
            .padding(16)
            .background(
                color,
                in: RoundedRectangle(
                    cornerRadius: 18
                )
            )
            .contentShape(
                RoundedRectangle(
                    cornerRadius: 18
                )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Transaction Sheet

    private func transactionSheet(
        for action: ManufacturingAction
    ) -> some View {

        NavigationStack {

            Form {

                Section("Part") {

                    LabeledContent(
                        "Part Number",
                        value: selectedPartNumber
                    )

                    LabeledContent(
                        "Action",
                        value: action.rawValue
                    )
                }

                Section("Transaction") {

                    Text(action.explanation)
                        .foregroundStyle(.secondary)

                    if transactionService == nil {

                        Label(
                            "Transaction posting is not yet connected. No inventory will be changed.",
                            systemImage:
                                "exclamationmark.triangle"
                        )
                        .foregroundStyle(.orange)
                    }

                    Text(
                        "ERP transaction data must be mapped to the verified part before enabling submissions."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(action.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {

                ToolbarItem(
                    placement: .topBarTrailing
                ) {

                    Button("Done") {
                        selectedManufacturingAction = nil
                    }
                }
            }
        }
    }

    // MARK: - Manufacturing Information

    private var informationCard: some View {

        VStack(
            alignment: .leading,
            spacing: 16
        ) {

            HStack {

                Text("Manufacturing Information")
                    .font(.title3.bold())
                    .foregroundStyle(primaryText)

                Spacer()

                if isLoadingEngineering {

                    ProgressView()
                }
            }

            if let engineeringPart {

                if engineeringPart.demoData {

                    Label(
                        "Demo engineering specifications",
                        systemImage: "info.circle"
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                }

                detailRow(
                    "Material",
                    engineeringPart.materialName
                    ?? "Not specified"
                )

                detailRow(
                    "Revision",
                    engineeringPart.revision
                    ?? "Not specified"
                )

                detailRow(
                    "Unit",
                    engineeringPart.unitOfMeasure
                )

                detailRow(
                    "Gauge",
                    engineeringPart.gaugeLabel
                    ?? "Not specified"
                )

                detailRow(
                    "Thickness",
                    engineeringPart.thicknessMM.map {
                        "\($0.formatted()) mm"
                    } ?? "Not specified"
                )

                detailRow(
                    "Unit Weight",
                    engineeringPart.netWeightKG.map {
                        "\($0.formatted()) kg"
                    } ?? "Not specified"
                )

                detailRow(
                    "Scrap Factor",
                    engineeringPart.scrapFactor.map {
                        String(
                            format: "%.1f%%",
                            $0 * 100
                        )
                    } ?? "Not specified"
                )

                detailRow(
                    "BOM Relationships",
                    "\(engineeringPart.bomComponentCount) direct components"
                )

                if !engineeringPart.bomComponents.isEmpty {

                    Divider()

                    Text("Bill of Materials")
                        .font(.headline)

                    
                    ForEach(engineeringPart.bomComponents) { component in

                        if let repository = rcaRepository {

                            NavigationLink {

                                EngineeringBOMTreeView(
                                    partNumber: component.partNumber,
                                    repository: repository,
                                    visited: [selectedPartNumber]
                                )

                            } label: {

                                VStack(
                                    alignment: .leading,
                                    spacing: 5
                                ) {

                                    Text(component.partNumber)
                                        .font(.subheadline.bold())

                                    HStack {

                                        Text(
                                            "Revision: "
                                            + (component.revision.isEmpty
                                               ? "Unknown"
                                               : component.revision)
                                        )

                                        Spacer()

                                        Text(
                                            "\(component.quantityPer.formatted()) "
                                            + component.unit
                                        )
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 6)
                            }
                            .tint(navy)
                        }
                    }

                }

                automaticHealthFindings(engineeringPart)

            } else {

                Text(
                    engineeringError
                    ?? "No linked engineering specifications are available for this ERP part."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Text(
                    "Inventory is sourced from the ERP import. Material, revision, and BOM data are shown only when a matching reference record exists."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .background(
            .white,
            in: RoundedRectangle(
                cornerRadius: 20
            )
        )
    }

    // MARK: - Automatic Health Warnings

    private func automaticHealthFindings(
        _ part: RCAPartHealth
    ) -> some View {

        let findings = RCADiagnosticEngine.analyze(
            part,
            countedQuantity: nil,
            selectedLocation: nil
        )
        .filter {
            $0.severity != .information
        }

        return VStack(
            alignment: .leading,
            spacing: 10
        ) {

            Divider()

            Label(
                "Automated Specification Review",
                systemImage: "waveform.path.ecg"
            )
            .font(.headline)

            if findings.isEmpty {

                Label(
                    "No automatic specification issues detected. Physical verification is still required.",
                    systemImage: "checkmark.circle"
                )
                .font(.subheadline)
                .foregroundStyle(.green)

            } else {

                ForEach(findings) { finding in

                    VStack(
                        alignment: .leading,
                        spacing: 5
                    ) {

                        Label(
                            finding.title,
                            systemImage:
                                "exclamationmark.triangle.fill"
                        )
                        .font(.subheadline.bold())
                        .foregroundStyle(
                            finding.severity == .critical
                            ? Color.red
                            : Color.orange
                        )

                        Text(finding.recommendation)
                            .font(.caption)
                            .foregroundStyle(
                                secondaryText
                            )
                    }
                    .padding(10)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .background(
                        stockBackground,
                        in: RoundedRectangle(
                            cornerRadius: 12
                        )
                    )
                }
            }
        }
    }

    // MARK: - Root Cause Analysis

    private var rcaCard: some View {

        VStack(
            alignment: .leading,
            spacing: 14
        ) {

            Label(
                "Foresight AI Root Cause Analysis",
                systemImage: "brain.head.profile"
            )
            .font(.title3.bold())
            .foregroundStyle(primaryText)

            Text(
                "Investigate inventory discrepancies using "
                + "an interactive AI voice assistant. "
                + "Foresight reviews material specifications, "
                + "revision, scrap, weight, BOM, "
                + "manufacturing orders and substitutions."
            )
            .font(.subheadline)
            .foregroundStyle(secondaryText)

            if engineeringPart == nil {

                Label(
                    isLoadingEngineering
                    ? "Loading manufacturing specifications..."
                    : "Engineering information may be incomplete. "
                      + "Foresight will identify missing data during analysis.",
                    systemImage: "info.circle"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            }

            Button {

                selectedRCA = RCARoute(
                    partNumber: selectedPartNumber
                )

            } label: {

                HStack(spacing: 12) {

                    Image(systemName: "mic.fill")
                        .font(.title3)

                    Text("Analyze This Part")
                        .font(.headline)

                    Spacer()

                    Image(systemName: "chevron.right")
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .foregroundStyle(.white)
                .background(
                    navy,
                    in: RoundedRectangle(cornerRadius: 14)
                )
            }
            .buttonStyle(.plain)
            .disabled(rcaRepository == nil)

            Text(
                "Voice-guided investigation with an "
                + "AI-generated root cause report "
                + "and corrective action recommendations."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .background(
            Color.white,
            in: RoundedRectangle(cornerRadius: 20)
        )
    }

    // MARK: - Load Engineering Data

    @MainActor
    private func loadEngineeringData() async {

        engineeringPart = nil
        engineeringError = nil

        guard let repository = rcaRepository else {

            engineeringError =
                "RCA database connection not configured."

            return
        }

        isLoadingEngineering = true

        defer {
            isLoadingEngineering = false
        }

        do {

            engineeringPart = try await repository.loadPart(
                number: selectedPartNumber
            )

        } catch RCAError.partNotFound {

            engineeringError =
                "No matching engineering record for this ERP part."

        } catch {

            engineeringError =
                "Unable to load engineering data: \(error.localizedDescription)"
        }
    }

    // MARK: - Detail Row

    private func detailRow(
        _ title: String,
        _ value: String
    ) -> some View {

        HStack(
            alignment: .firstTextBaseline,
            spacing: 12
        ) {

            Text(title)
                .foregroundStyle(secondaryText)

            Spacer(minLength: 8)

            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(primaryText)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}

// MARK: - RCA Navigation Route

private struct RCARoute: Identifiable {

    let id = UUID()
    let partNumber: String
}
