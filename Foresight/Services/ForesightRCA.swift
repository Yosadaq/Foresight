
//
// ForesightRCA.swift
// Foresight
//
// Vercel-backed manufacturing intelligence
// and guided root cause analysis.
//
// No Supabase SDK or user login required.
//

import Foundation
import SwiftUI

// MARK: - BOM Component

struct RCABOMComponent: Decodable, Identifiable {

    let partNumber: String
    let revision: String
    let quantityPer: Double
    let unit: String

    var id: String {
        "\(partNumber)-\(revision)"
    }
}

// MARK: - Manufacturing Specifications

struct RCAPartHealth: Decodable, Identifiable {

    let partNumber: String
    let name: String
    let partType: String
    let unitOfMeasure: String
    let manufacturer: String?
    let inventoryLocations: [RCAInventoryLocation]?
    let stockQuantityKnown: Bool?

    let revision: String?
    let materialForm: String?
    let materialCode: String?
    let materialName: String?
    let metalType: String?
    let galvanized: Bool?
    let corrosionResistance: String?

    let gaugeLabel: String?
    let thicknessMM: Double?
    let perforated: Bool?
    let openAreaFraction: Double?
    let netWeightKG: Double?
    let scrapFactor: Double?

    let routingRevision: String?
    let toolingRevision: String?
    let revisionApproved: Bool?

    let stockQuantity: Double
    let bomComponentCount: Int
    let bomComponents: [RCABOMComponent]
    let demoData: Bool

    var id: String { partNumber }

    enum CodingKeys: String, CodingKey {
        case partNumber = "part_number"
        case name
        case partType = "part_type"
        case unitOfMeasure = "unit_of_measure"
        case manufacturer
        case revision
        case materialForm = "material_form"
        case materialCode = "material_code"
        case materialName = "material_name"
        case inventoryLocations = "inventory_locations"
        case stockQuantityKnown = "stock_quantity_known"
        case metalType = "metal_type"
        case galvanized
        case corrosionResistance = "corrosion_resistance"
        case gaugeLabel = "gauge_label"
        case thicknessMM = "thickness_mm"
        case perforated
        case openAreaFraction = "open_area_fraction"
        case netWeightKG = "net_weight_kg"
        case scrapFactor = "scrap_factor"
        case routingRevision = "routing_revision"
        case toolingRevision = "tooling_revision"
        case revisionApproved = "revision_approved"
        case stockQuantity = "stock_quantity"
        case bomComponentCount = "bom_component_count"
        case bomComponents = "bom_components"
        case demoData = "demo_data"
    }
}

// MARK: - Diagnostics

enum RCASeverity: String, Codable {
    case information
    case warning
    case critical
}

struct RCAFinding: Identifiable, Codable {

    let id: String
    let severity: RCASeverity
    let title: String
    let explanation: String
    let recommendation: String
}

enum RCADiagnosticEngine {

    static func analyze(
        _ part: RCAPartHealth,
        countedQuantity: Double?,
        selectedLocation: String?
    ) -> [RCAFinding] {

        var findings: [RCAFinding] = []

        func flag(
            _ id: String,
            _ severity: RCASeverity,
            _ title: String,
            _ detail: String,
            _ action: String
        ) {
            findings.append(
                RCAFinding(
                    id: id,
                    severity: severity,
                    title: title,
                    explanation: detail,
                    recommendation: action
                )
            )
        }

        // Engineering revision

        if part.revision == nil {

            flag(
                "revision_missing",
                .critical,
                "Engineering revision missing",
                "No engineering revision is recorded.",
                "Compare the part against its approved drawing."
            )

        } else if part.revisionApproved != true {

            flag(
                "revision_unapproved",
                .warning,
                "Revision requires verification",
                "The database revision is not marked approved.",
                "Check the released drawing and manufacturing order."
            )
        }

        // Unit of measure

        let supportedUnits: Set<String> = [
            "EA", "PCS", "FT", "IN",
            "LB", "KG", "M", "MM",
            "SHEET", "BLANK"
        ]

        if !supportedUnits.contains(
            part.unitOfMeasure.uppercased()
        ) {

            flag(
                "unit",
                .warning,
                "Unit of measure needs review",
                "The stored unit is not in the recognized demo list.",
                "Verify the unit and any required conversions."
            )
        }

        // Materials

        let form = (
            part.materialForm ?? ""
        ).lowercased()

        let isMaterialComponent = [
            "sheet",
            "formed_sheet",
            "stamped_sheet",
            "wire",
            "extrusion"
        ].contains(form)

        if isMaterialComponent &&
            part.materialCode == nil {

            flag(
                "material",
                .critical,
                "Material specification missing",
                "No material code is linked to this component.",
                "Verify metal type, grade and approved coating."
            )
        }

        // Thickness and gauge

        if form.contains("sheet") {

            if part.thicknessMM == nil {

                flag(
                    "thickness",
                    .critical,
                    "Thickness not recorded",
                    "The component has no thickness specification.",
                    "Measure the material and compare it with the drawing."
                )
            }

            if part.gaugeLabel == nil {

                flag(
                    "gauge",
                    .warning,
                    "Gauge not recorded",
                    "No nominal gauge is recorded.",
                    "Verify material gauge and thickness."
                )
            }
        }

        // Perforation

        if part.perforated == true &&
            part.openAreaFraction == nil {

            flag(
                "perforation",
                .warning,
                "Perforation requires verification",
                "Open-area percentage is unavailable.",
                "Verify perforation geometry and material yield."
            )
        }

        // Scrap factor

        if isMaterialComponent &&
            part.scrapFactor == nil {

            flag(
                "scrap",
                .warning,
                "Scrap factor missing",
                "No standard scrap allowance is recorded.",
                "Review nesting, tooling and actual production scrap."
            )
        }

        // Weight

        if isMaterialComponent &&
            (part.netWeightKG ?? 0) <= 0 {

            flag(
                "weight",
                .warning,
                "Standard weight missing",
                "No usable net weight is recorded.",
                "Compare physical weight with the approved standard."
            )
        }

        // BOM

        let isAssembly = [
            "ASSEMBLY",
            "SUBASSEMBLY"
        ].contains(part.partType.uppercased())

        if isAssembly &&
            part.bomComponents.isEmpty {

            flag(
                "bom",
                .critical,
                "Assembly has no BOM",
                "No child components are linked to this revision.",
                "Verify the parent-child BOM relationships."
            )
        }

        // Inventory

        if part.stockQuantity < 0 {

            flag(
                "negative_stock",
                .critical,
                "Negative inventory detected",
                "The system quantity is below zero.",
                "Investigate transactions and perform a verified count."
            )
        }

        // Never compare one bin against a facility total.

        if let location = selectedLocation,
           !location.isEmpty {

            flag(
                "location_scope",
                .information,
                "Location count requires a location balance",
                "The loaded stock quantity covers all demo locations.",
                "Retrieve the balance for \(location) before calculating variance."
            )

        } else if let count = countedQuantity {

            let variance = count - part.stockQuantity

            if abs(variance) > 0.000001 {

                flag(
                    "inventory_variance",
                    .critical,
                    "Inventory does not match",
                    "System: \(part.stockQuantity.formatted()). Physical: \(count.formatted()). Variance: \(variance.formatted()).",
                    "Recount and review transfers, scrap, production and material issues."
                )
            }
        }

        if findings.isEmpty {

            flag(
                "no_flags",
                .information,
                "No automatic warnings",
                "The available records passed basic checks.",
                "Continue physical verification before closing the investigation."
            )
        }

        return findings
    }
}

// MARK: - Guided Investigation

struct RCAReviewStep: Identifiable, Codable {

    let id: String
    let title: String
    let question: String

    var verified = false
    var issueFound = false
    var evidence = ""
}

enum RCAWorkflow {

    static func steps() -> [RCAReviewStep] {

        [
            RCAReviewStep(
                id: "identity",
                title: "Part Identification",
                question: "Does the scanned part match the part number, description and physical geometry?"
            ),
            RCAReviewStep(
                id: "location",
                title: "Inventory Location",
                question: "Is the part stored in the correct manufacturing area or bin?"
            ),
            RCAReviewStep(
                id: "count",
                title: "Physical Count",
                question: "Has the quantity been counted and verified?"
            ),
            RCAReviewStep(
                id: "unit",
                title: "Unit of Measure",
                question: "Is inventory recorded in the correct units and conversion?"
            ),
            RCAReviewStep(
                id: "material",
                title: "Material",
                question: "Does the physical material match the specified metal grade and coating?"
            ),
            RCAReviewStep(
                id: "gauge",
                title: "Gauge and Thickness",
                question: "Do the dimensions, thickness and perforation match engineering requirements?"
            ),
            RCAReviewStep(
                id: "revision",
                title: "Engineering Revision",
                question: "Does the part revision match the released drawing and manufacturing order?"
            ),
            RCAReviewStep(
                id: "weight",
                title: "Standard Weight",
                question: "Does the measured component weight match the approved standard?"
            ),
            RCAReviewStep(
                id: "scrap",
                title: "Scrap Factor",
                question: "Does actual material loss match the expected scrap factor?"
            ),
            RCAReviewStep(
                id: "bom",
                title: "Bill of Materials",
                question: "Are the correct components and quantities used in the parent assembly?"
            ),
            RCAReviewStep(
                id: "mo",
                title: "Manufacturing Order",
                question: "Was the correct BOM revision and routing used for the manufacturing order?"
            ),
            RCAReviewStep(
                id: "transactions",
                title: "Inventory Transactions",
                question: "Are production, transfer, scrap and material issue transactions complete?"
            ),
            RCAReviewStep(
                id: "prevention",
                title: "Corrective Action",
                question: "What evidence supports the root cause and prevents recurrence?"
            )
        ]
    }
}

// MARK: - Investigation Record

struct RCAInvestigation: Encodable {

    let id: UUID
    let partNumber: String
    let locationID: String?
    let expectedQuantity: Double
    let countedQuantity: Double?
    let status: String
    let findings: [RCAReviewStep]
    let suspectedCause: String?
    let confirmedCause: String?
    let correctiveAction: String?
    let verificationNotes: String?

    enum CodingKeys: String, CodingKey {
        case id
        case partNumber = "part_number"
        case locationID = "location_id"
        case expectedQuantity = "expected_quantity"
        case countedQuantity = "counted_quantity"
        case status
        case findings
        case suspectedCause = "suspected_cause"
        case confirmedCause = "confirmed_cause"
        case correctiveAction = "corrective_action"
        case verificationNotes = "verification_notes"
    }
}

// MARK: - Repository Interface

protocol ForesightRCARepository {

    func loadPart(
        number: String
    ) async throws -> RCAPartHealth

    func saveInvestigation(
        _ investigation: RCAInvestigation
    ) async throws
}

// MARK: - Errors

enum RCAError: LocalizedError {

    case partNotFound(String)
    case server(Int)

    var errorDescription: String? {

        switch self {

        case .partNotFound(let number):
            return "No RCA record found for \(number)."

        case .server(let status):
            return "RCA API returned HTTP \(status)."
        }
    }
}

// MARK: - Vercel Repository

struct VercelRCARepository: ForesightRCARepository {

    private let endpoint =
        "https://foresight-omega.vercel.app/api/rca/part"

    func loadPart(
        number: String
    ) async throws -> RCAPartHealth {

        let normalized = number
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .uppercased()

        guard !normalized.isEmpty,
              normalized.count <= 80 else {
            throw RCAError.partNotFound(normalized)
        }

        guard var urlParts = URLComponents(
            string: endpoint
        ) else {
            throw URLError(.badURL)
        }

        urlParts.queryItems = [
            URLQueryItem(
                name: "number",
                value: normalized
            )
        ]

        guard let url = urlParts.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue(
            "application/json",
            forHTTPHeaderField: "Accept"
        )

        let (data, response) =
            try await URLSession.shared.data(
                for: request
            )

        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if http.statusCode == 404 {
            throw RCAError.partNotFound(normalized)
        }

        guard (200...299).contains(http.statusCode) else {
            throw RCAError.server(http.statusCode)
        }

        return try JSONDecoder().decode(
            RCAPartHealth.self,
            from: data
        )
    }

    func saveInvestigation(
        _ investigation: RCAInvestigation
    ) async throws {

        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let folder = base.appendingPathComponent(
            "ForesightRCA",
            isDirectory: true
        )

        try FileManager.default.createDirectory(
            at: folder,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let file = folder.appendingPathComponent(
            investigation.id.uuidString + ".json"
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys
        ]

        let data = try encoder.encode(investigation)

        try data.write(
            to: file,
            options: .atomic
        )
    }
}

// MARK: - Interactive RCA Screen

struct InventoryRCAGuideView: View {

    let partNumber: String
    let database: any ForesightRCARepository

    @Environment(\.dismiss)
    private var dismiss

    @State private var part: RCAPartHealth?
    @State private var isLoading = true
    @State private var isSaving = false

    @State private var errorMessage: String?
    @State private var saved = false

    @State private var physicalCountText = ""
    @State private var selectedLocation = ""

    @State private var steps = RCAWorkflow.steps()

    @State private var investigationID = UUID()

    @State private var suspectedCause = ""
    @State private var confirmedCause = ""
    @State private var correctiveAction = ""
    @State private var verificationNotes = ""

    private var physicalCount: Double? {

        let text = physicalCountText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !text.isEmpty,
              let value = Double(text),
              value.isFinite,
              value >= 0 else {
            return nil
        }

        return value
    }

    private var reviewedCount: Int {
        steps.filter { $0.verified }.count
    }

    private var findings: [RCAFinding] {

        guard let part else {
            return []
        }

        return RCADiagnosticEngine.analyze(
            part,
            countedQuantity: physicalCount,
            selectedLocation: selectedLocation.isEmpty
                ? nil
                : selectedLocation
        )
    }

    var body: some View {

        ScrollView {

            VStack(
                alignment: .leading,
                spacing: 18
            ) {

                if isLoading {

                    ProgressView("Loading RCA data...")
                        .frame(maxWidth: .infinity)

                } else if let part {

                    partSummary(part)

                    inventoryVerification(part)

                    diagnosticFindings

                    investigationChecklist

                    rootCauseReport

                    saveButton

                } else {

                    ContentUnavailableView(
                        "RCA Data Unavailable",
                        systemImage: "exclamationmark.triangle",
                        description: Text(
                            errorMessage ??
                            "Unable to load manufacturing data."
                        )
                    )
                }
            }
            .padding()
        }
        .background(
            Color(uiColor: .systemGroupedBackground)
        )
        .navigationTitle("Root Cause Analysis")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {

            ToolbarItem(placement: .topBarTrailing) {

                Button("Done") {
                    dismiss()
                }
            }
        }
        .task(id: partNumber) {
            await loadPart()
        }
    }

    // MARK: - Part Summary

    private func partSummary(
        _ part: RCAPartHealth
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 12
        ) {

            Label(
                "Manufacturing Intelligence",
                systemImage: "brain.head.profile"
            )
            .font(.headline)

            Text(part.partNumber)
                .font(.title2.bold())

            Text(part.name)
                .font(.subheadline)

            if part.demoData {

                Label(
                    "Demo engineering data",
                    systemImage: "info.circle"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            }

            Divider()

            detail("Revision", part.revision ?? "Unknown")
            detail("Material", part.materialName ?? "Unknown")
            detail("Unit", part.unitOfMeasure)
            detail("Gauge", part.gaugeLabel ?? "Unknown")

            detail(
                "Thickness",
                part.thicknessMM.map {
                    "\($0.formatted()) mm"
                } ?? "Unknown"
            )

            detail(
                "Net Weight",
                part.netWeightKG.map {
                    "\($0.formatted()) kg"
                } ?? "Unknown"
            )

            detail(
                "Scrap Factor",
                part.scrapFactor.map {
                    String(format: "%.1f%%", $0 * 100)
                } ?? "Not specified"
            )

            detail(
                "Direct BOM Components",
                "\(part.bomComponentCount)"
            )

            if !part.bomComponents.isEmpty {

                Divider()

                Text("Bill of Materials")
                    .font(.headline)

                
                ForEach(part.bomComponents) { child in

                    VStack(alignment: .leading, spacing: 4) {

                        Text(child.partNumber)
                            .font(.subheadline.bold())

                        Text(
                            "Rev \(child.revision) • "
                            + "\(child.quantityPer.formatted()) "
                            + child.unit
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

            }
        }
        .rcaPanel()
    }

    // MARK: - Inventory Verification

    private func inventoryVerification(
        _ part: RCAPartHealth
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 12
        ) {

            Label(
                "Inventory Verification",
                systemImage: "shippingbox"
            )
            .font(.headline)

            detail(
                "System Quantity",
                "\(part.stockQuantity.formatted()) \(part.unitOfMeasure)"
            )

            TextField(
                "Enter physical count",
                text: $physicalCountText
            )
            .keyboardType(.decimalPad)
            .textFieldStyle(.roundedBorder)

            TextField(
                "Location (leave blank for facility total)",
                text: $selectedLocation
            )
            .textInputAutocapitalization(.characters)
            .textFieldStyle(.roundedBorder)

            if !selectedLocation.isEmpty {

                Label(
                    "This location cannot be compared with the facility total. A location-specific system balance is required.",
                    systemImage: "info.circle"
                )
                .font(.caption)
                .foregroundStyle(.orange)

            } else if let count = physicalCount {

                let difference =
                    count - part.stockQuantity

                detail(
                    "Variance",
                    difference.formatted()
                )

                Label(
                    abs(difference) < 0.000001
                    ? "Quantity matches"
                    : "Inventory discrepancy detected",
                    systemImage:
                        abs(difference) < 0.000001
                        ? "checkmark.circle.fill"
                        : "exclamationmark.triangle.fill"
                )
                .foregroundStyle(
                    abs(difference) < 0.000001
                    ? Color.green
                    : Color.orange
                )
            }
        }
        .rcaPanel()
    }

    // MARK: - Diagnostic Findings

    private var diagnosticFindings: some View {

        VStack(
            alignment: .leading,
            spacing: 12
        ) {

            Label(
                "Foresight Findings",
                systemImage: "waveform.path.ecg"
            )
            .font(.headline)

            ForEach(findings) { finding in

                VStack(
                    alignment: .leading,
                    spacing: 6
                ) {

                    Label(
                        finding.title,
                        systemImage:
                            finding.severity == .critical
                            ? "exclamationmark.triangle.fill"
                            : "info.circle.fill"
                    )
                    .font(.subheadline.bold())
                    .foregroundStyle(
                        finding.severity == .critical
                        ? Color.red
                        : Color.orange
                    )

                    Text(finding.explanation)
                        .font(.subheadline)

                    Text(finding.recommendation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()
            }
        }
        .rcaPanel()
    }

    // MARK: - Guided Checklist

    private var investigationChecklist: some View {

        VStack(
            alignment: .leading,
            spacing: 14
        ) {

            Label(
                "Guided Investigation",
                systemImage: "checklist"
            )
            .font(.headline)

            Text(
                "\(reviewedCount) of \(steps.count) steps reviewed"
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            ProgressView(
                value: Double(reviewedCount),
                total: Double(max(steps.count, 1))
            )

            ForEach(steps.indices, id: \.self) { index in

                VStack(
                    alignment: .leading,
                    spacing: 10
                ) {

                    Text(
                        "\(index + 1). \(steps[index].title)"
                    )
                    .font(.subheadline.bold())

                    Text(steps[index].question)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    TextField(
                        "Evidence or observations",
                        text: $steps[index].evidence,
                        axis: .vertical
                    )
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)

                    Toggle(
                        "Potential issue found",
                        isOn: $steps[index].issueFound
                    )

                    Toggle(
                        "Verification completed",
                        isOn: $steps[index].verified
                    )
                }

                Divider()
            }
        }
        .rcaPanel()
    }

    // MARK: - Root Cause Report

    private var rootCauseReport: some View {

        VStack(
            alignment: .leading,
            spacing: 12
        ) {

            Label(
                "Root Cause Report",
                systemImage: "doc.text"
            )
            .font(.headline)

            reportField(
                "Suspected Cause",
                text: $suspectedCause
            )

            reportField(
                "Confirmed Cause",
                text: $confirmedCause
            )

            reportField(
                "Corrective Action",
                text: $correctiveAction
            )

            reportField(
                "Verification Notes",
                text: $verificationNotes
            )

            Text(
                "Findings require human verification. Saving a report does not alter inventory, engineering specifications or manufacturing orders."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .rcaPanel()
    }

    // MARK: - Save

    private var saveButton: some View {

        VStack(spacing: 10) {

            Button {

                Task {
                    await saveReport()
                }

            } label: {

                HStack {

                    Spacer()

                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    }

                    Text(
                        isSaving
                        ? "Saving..."
                        : "Save RCA Investigation"
                    )
                    .fontWeight(.semibold)

                    Spacer()
                }
                .padding()
                .foregroundStyle(.white)
                .background(
                    Color.indigo,
                    in: RoundedRectangle(
                        cornerRadius: 14
                    )
                )
            }
            .disabled(isSaving)

            if saved {

                Label(
                    "Investigation saved locally",
                    systemImage: "checkmark.circle.fill"
                )
                .foregroundStyle(.green)
            }

            if let errorMessage {

                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Networking

    @MainActor
    private func loadPart() async {

        isLoading = true
        errorMessage = nil
        part = nil

        defer {
            isLoading = false
        }

        do {

            part = try await database.loadPart(
                number: partNumber
            )

        } catch {

            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Local Save

    @MainActor
    private func saveReport() async {

        guard let part else {
            return
        }

        isSaving = true
        errorMessage = nil
        saved = false

        defer {
            isSaving = false
        }

        let completed = steps.allSatisfy {
            $0.verified
        }

        let report = RCAInvestigation(
            id: investigationID,
            partNumber: part.partNumber,
            locationID: selectedLocation.isEmpty
                ? nil
                : selectedLocation,
            expectedQuantity: part.stockQuantity,
            countedQuantity: physicalCount,
            status: completed
                ? "pending_approval"
                : "investigating",
            findings: steps,
            suspectedCause: suspectedCause.isEmpty
                ? nil
                : suspectedCause,
            confirmedCause: confirmedCause.isEmpty
                ? nil
                : confirmedCause,
            correctiveAction: correctiveAction.isEmpty
                ? nil
                : correctiveAction,
            verificationNotes: verificationNotes.isEmpty
                ? nil
                : verificationNotes
        )

        do {

            try await database.saveInvestigation(
                report
            )

            saved = true

        } catch {

            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Helpers

    private func detail(
        _ name: String,
        _ value: String
    ) -> some View {

        HStack(alignment: .top) {

            Text(name)
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            Text(value)
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    private func reportField(
        _ title: String,
        text: Binding<String>
    ) -> some View {

        VStack(alignment: .leading, spacing: 6) {

            Text(title)
                .font(.subheadline.bold())

            TextField(
                title,
                text: text,
                axis: .vertical
            )
            .lineLimit(2...5)
            .textFieldStyle(.roundedBorder)
        }
    }
}

// MARK: - Shared Card Styling

private struct RCAPanelModifier: ViewModifier {

    func body(content: Content) -> some View {

        content
            .padding(16)
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .background(
                Color(uiColor: .secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 18)
            )
    }
}

private extension View {

    func rcaPanel() -> some View {
        modifier(RCAPanelModifier())
    }
}
