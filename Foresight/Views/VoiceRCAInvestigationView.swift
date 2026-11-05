
//
// VoiceRCAInvestigationView.swift
// Foresight
//

import SwiftUI
import Foundation

// MARK: - Saved Report Models

struct RCAAIReport: Codable {

    let summary: String

    let possibleCauses: String
    let nextVerification: String
    let correctiveAction: String
    let preventiveAction: String
    let effectivenessCheck: String

    let countSummary: String?
    let completedChecks: String?
    let outstandingChecks: String?

    let managementEmailSubject: String?
    let managementEmailBody: String?
}

struct RCAReportResponse: Decodable {
    let success: Bool
    let model: String
    let report: RCAAIReport
}

struct RCAInterviewAnswer: Codable, Identifiable {
    let id: String
    let question: String
    let answer: String
}

struct SavedVoiceRCA: Codable, Identifiable {

    let id: UUID

    let partNumber: String
    let partName: String?

    let createdAt: Date
    let answers: [RCAInterviewAnswer]

    let report: RCAAIReport
    let model: String

    // Inventory snapshot at the time
    // the investigation was generated.
    let inventoryLocations: [RCAInventoryLocation]?
    let erpTotalBalance: Double?
}

enum VoiceRCAStorage {

    static func directory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let folder = base.appendingPathComponent(
            "ForesightVoiceRCA",
            isDirectory: true
        )

        try FileManager.default.createDirectory(
            at: folder,
            withIntermediateDirectories: true
        )

        return folder
    }

    static func save(_ report: SavedVoiceRCA) throws {
        let file = try directory()
            .appendingPathComponent(
                report.id.uuidString + ".json"
            )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys
        ]

        try encoder.encode(report)
            .write(to: file, options: .atomic)
    }

    static func loadAll() throws -> [SavedVoiceRCA] {
        let files = try FileManager.default
            .contentsOfDirectory(
                at: directory(),
                includingPropertiesForKeys: nil
            )
            .filter { $0.pathExtension == "json" }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try files.compactMap { file in
            try decoder.decode(
                SavedVoiceRCA.self,
                from: Data(contentsOf: file)
            )
        }
        .sorted { $0.createdAt > $1.createdAt }
    }
}

// MARK: - AI Service

struct RCAReportAIService {

    private let endpoint =
        "https://foresight-omega.vercel.app/api/rca/analyze"

    func generate(
        part: RCAPartHealth,
        answers: [RCAInterviewAnswer]
    ) async throws -> RCAReportResponse {

        guard let url = URL(string: endpoint) else {
            throw URLError(.badURL)
        }

        // Only fields grounded in the loaded database
        // are included as structured engineering data.

        let engineering: [String: Any] = [
            "revision": part.revision as Any? ?? NSNull(),
            "material": part.materialName as Any? ?? NSNull(),
            "materialCode": part.materialCode as Any? ?? NSNull(),
            "unit": part.unitOfMeasure,
            "gauge": part.gaugeLabel as Any? ?? NSNull(),
            "thicknessMM": part.thicknessMM as Any? ?? NSNull(),
            "netWeightKG": part.netWeightKG as Any? ?? NSNull(),
            "scrapFactor": part.scrapFactor as Any? ?? NSNull(),
            
            "stockQuantityKnown":
                part.stockQuantityKnown ?? true,

            "inventoryLocations":
                part.inventoryLocations?.map {
                    [
                        "location": $0.location,
                        "quantity": $0.quantity
                    ] as [String: Any]
                } ?? [],

            "inventoryQuantity": part.stockQuantity,
            "isDemoData": part.demoData,
            "bom": part.bomComponents.map {
                [
                    "partNumber": $0.partNumber,
                    "revision": $0.revision,
                    "quantityPer": "\($0.quantityPer)",
                    "unit": $0.unit
                ]
            }
        ]

        let payload: [String: Any] = [
            "partNumber": part.partNumber,
            "partDescription": part.name,
            "engineering": engineering,
            "answers": answers.map {
                [
                    "id": $0.id,
                    "question": $0.question,
                    "answer": $0.answer
                ]
            }
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 130
        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )

        request.httpBody = try JSONSerialization.data(
            withJSONObject: payload
        )

        let (data, response) =
            try await URLSession.shared.data(
                for: request
            )

        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode)
        else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(
            RCAReportResponse.self,
            from: data
        )
    }
}

// MARK: - Voice Investigation

struct VoiceRCAInvestigationView: View {

    let partNumber: String
    let repository: any ForesightRCARepository

    @Environment(\.dismiss)
    private var dismiss

    @StateObject private var voice =
        ManufacturingVoiceGuide()

    @State private var part: RCAPartHealth?
    @State private var loading = true
    @State private var generating = false
    @State private var errorMessage: String?

    @State private var questionIndex = 0
    @State private var answerText = ""
    @State private var answers: [RCAInterviewAnswer] = []

    @State private var generatedReport: SavedVoiceRCA?

    private let questions: [(id: String, text: String)] = [
        (
            "identity",
            "Does the physical part match the number and description shown in the database?"
        ),
        (
            "location",
            "Where did you find the part, and is that its assigned inventory location?"
        ),
        (
            "count",
            "What quantity did you physically count? State whether this covers one location or the entire facility."
        ),
        (
            "unit",
            "Is the part counted in the correct unit, such as pieces, feet, sheets, or pounds?"
        ),
        (
            "material",
            "Does the actual material match the expected grade and type?"
        ),
        (
            "coil",
            "Was the correct coil or raw material used? Was there a material substitution?"
        ),
        (
            "thickness",
            "Does the material gauge, thickness, and physical size match the drawing?"
        ),
        (
            "weight",
            "Does the physical part weight agree with the standard weight?"
        ),
        (
            "revision",
            "Is the correct engineering revision being manufactured?"
        ),
        (
            "scrap",
            "Is there unusual scrap, waste, or unreported rejected material?"
        ),
        (
            "bom",
            "Are the correct parent and child components being consumed in the bill of materials?"
        ),
        (
            "mo",
            "What manufacturing order and operation were used? Does the order specify the right material and revision?"
        ),
        (
            "transactions",
            "Were all production completions, transfers, scrap, and material issues recorded correctly?"
        ),
        (
            "other",
            "Is there any other evidence that might explain the discrepancy?"
        )
    ]

    private var isFinished: Bool {
        questionIndex >= questions.count
    }

    var body: some View {

        ScrollView {

            VStack(
                alignment: .leading,
                spacing: 18
            ) {

                if loading {

                    ProgressView("Loading part intelligence...")

                } else if let generatedReport {

                    reportPanel(generatedReport)

                } else if let part {

                    partPanel(part)

                    if !isFinished {
                        interviewPanel
                    } else {
                        finishPanel
                    }

                } else {

                    ContentUnavailableView(
                        "Unable to Start Investigation",
                        systemImage: "exclamationmark.triangle",
                        description: Text(
                            errorMessage ?? "Part data unavailable"
                        )
                    )
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding(16)
        }
        .background(
            Color(uiColor: .systemGroupedBackground)
        )
        .navigationTitle("AI Root Cause Analysis")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .task(id: partNumber) {
            await loadPart()
        }
        .onDisappear {
            voice.stop()
            voice.stopSpeaking()
        }
    }

    private func partPanel(
        _ part: RCAPartHealth
    ) -> some View {

        VStack(alignment: .leading, spacing: 8) {

            Label(
                "Foresight Manufacturing Intelligence",
                systemImage: "brain.head.profile"
            )
            .font(.headline)

            Text(part.partNumber)
                .font(.title2.bold())

            Text(part.name)
                .foregroundStyle(.secondary)

            Text(
                "Revision: \(part.revision ?? "Unverified")"
                + " • Material: \(part.materialName ?? "Unverified")"
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            RCAInventoryAreaGrid(
                locations: part.inventoryLocations ?? [],
                totalBalance:
                    part.stockQuantityKnown == false
                    ? nil
                    : part.stockQuantity
            )
            .font(.subheadline.bold())

            if part.demoData {
                Text("Demo engineering record")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            .white,
            in: RoundedRectangle(cornerRadius: 18)
        )
    }

   
    private var interviewPanel: some View {

        let current = questions[questionIndex]

        return VStack(
            alignment: .leading,
            spacing: 16
        ) {

            // MARK: - Question Progress

            Text(
                "Question \(questionIndex + 1) of \(questions.count)"
            )
            .font(.caption.bold())
            .foregroundStyle(.secondary)

            ProgressView(
                value: Double(questionIndex),
                total: Double(questions.count)
            )
            .tint(.indigo)

            // MARK: - AI Voice Assistant

            Label(
                "Foresight AI Voice",
                systemImage: "waveform"
            )
            .font(.headline)
            .foregroundStyle(.indigo)

            Text(current.text)
                .font(.title3.bold())
                .foregroundStyle(.primary)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )

            // MARK: - Hear Question

            Button {

                voice.speak(current.text)

            } label: {

                Label(
                    "Hear Question",
                    systemImage: "speaker.wave.2.fill"
                )
            }
            .buttonStyle(.bordered)

            // MARK: - Voice Recording

            HStack(spacing: 12) {

                Button {

                    if voice.isListening {

                        voice.stop()

                    } else {

                        Task {
                            await voice.start()
                        }
                    }

                } label: {

                    Label(
                        voice.isListening
                        ? "Stop Listening"
                        : "Answer by Voice",
                        systemImage: voice.isListening
                        ? "stop.circle.fill"
                        : "mic.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)

                if voice.isListening {

                    ProgressView()
                        .tint(.indigo)
                }
            }

            // MARK: - Live Speech Transcription

            if !voice.transcript.isEmpty {

                VStack(
                    alignment: .leading,
                    spacing: 10
                ) {

                    Text("Recognized Speech")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    Text(voice.transcript)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )

                    Button {

                        let spokenAnswer = voice.transcript
                            .trimmingCharacters(
                                in: .whitespacesAndNewlines
                            )

                        guard !spokenAnswer.isEmpty else {
                            return
                        }

                        // Transfer speech to the answer field.
                        answerText = spokenAnswer

                        // Remove the duplicate transcription.
                        voice.clearTranscript()

                    } label: {

                        Label(
                            "Use Spoken Answer",
                            systemImage: "checkmark.circle.fill"
                        )
                        .font(.subheadline.bold())
                    }
                    .disabled(voice.isListening)
                }
                .padding(12)
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .background(
                    Color.indigo.opacity(0.06),
                    in: RoundedRectangle(
                        cornerRadius: 12
                    )
                )
            }

            // MARK: - Answer Field

            VStack(
                alignment: .leading,
                spacing: 8
            ) {

                Text("Your Answer")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)

                TextField(
                    "Speak your answer or type here...",
                    text: $answerText,
                    axis: .vertical
                )
                .lineLimit(2...5)
                .textFieldStyle(.roundedBorder)
                .foregroundStyle(.primary)
            }

            // MARK: - Voice Error

            if let error = voice.errorMessage {

                Label(
                    error,
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption)
                .foregroundStyle(.red)
            }

            // MARK: - Question Navigation
            // Only ONE Previous / Next group.

            HStack(spacing: 12) {

                // Previous Question

                if questionIndex > 0 {

                    Button {

                        voice.clearTranscript()

                        questionIndex -= 1

                        // Restore saved response for this question.
                        answerText = answers.first {
                            $0.id == questions[questionIndex].id
                        }?.answer ?? ""

                        voice.speak(
                            questions[questionIndex].text
                        )

                    } label: {

                        Label(
                            "Previous",
                            systemImage: "chevron.left"
                        )
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                // Next Question / Finish Interview

                Button {

                    recordAnswer()

                } label: {

                    HStack(spacing: 8) {

                        Text(
                            questionIndex == questions.count - 1
                            ? "Finish Interview"
                            : "Next Question"
                        )

                        Image(
                            systemName:
                                questionIndex == questions.count - 1
                                ? "checkmark.circle.fill"
                                : "chevron.right"
                        )
                    }
                    .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .disabled(
                    answerText
                        .trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )
                        .isEmpty
                )
            }
            .padding(.top, 6)
        }
        .padding(18)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .background(
            Color.white,
            in: RoundedRectangle(
                cornerRadius: 18
            )
        )
        .environment(\.colorScheme, .light)
    }

    private var finishPanel: some View {

        VStack(alignment: .leading, spacing: 14) {

            Label(
                "Investigation Complete",
                systemImage: "checkmark.circle.fill"
            )
            .font(.title3.bold())
            .foregroundStyle(.green)

            Text(
                "\(answers.count) observations recorded."
            )

            Text(
                "Meta AI will examine the engineering specifications, inventory balance, material usage, BOM relationships, manufacturing order observations, and your answers."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Button {

                Task {
                    await generateReport()
                }

            } label: {

                HStack {

                    if generating {
                        ProgressView()
                    }

                    Text(
                        generating
                        ? "Analyzing Evidence..."
                        : "Generate AI Root Cause Report"
                    )
                    .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
            .disabled(generating)
        }
        .padding()
        .background(
            .white,
            in: RoundedRectangle(cornerRadius: 18)
        )
    }

    private func reportPanel(
        _ saved: SavedVoiceRCA
    ) -> some View {

        RCAReportPresentationView(
            saved: saved
        )
        .environment(
            \.colorScheme,
            .light
        )
    }

    private func reportSection(
        _ title: String,
        _ content: String
    ) -> some View {

        VStack(alignment: .leading, spacing: 6) {

            Text(title)
                .font(.headline)

            Text(content)
                .font(.subheadline)
                .textSelection(.enabled)
        }
    }


    private func recordAnswer() {

        guard !isFinished else {
            return
        }

        let question = questions[questionIndex]

        let cleanedAnswer = answerText
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !cleanedAnswer.isEmpty else {
            return
        }

        let answer = RCAInterviewAnswer(
            id: question.id,
            question: question.text,
            answer: cleanedAnswer
        )

        // Preserve answers already recorded.
        answers.removeAll {
            $0.id == question.id
        }

        answers.append(answer)

        // Clear ALL previous question input.
        voice.clearTranscript()
        answerText = ""

        questionIndex += 1

        // Restore the previously saved response
        // if the employee is revisiting a question.
        if !isFinished {

            answerText = answers.first {
                $0.id == questions[questionIndex].id
            }?.answer ?? ""
        }

        guard !isFinished else {

            voice.speak(
                "That covers the investigation. "
                + "I have your observations. "
                + "Let's review what we found and "
                + "prepare the report."
            )

            return
        }

        // Introduce the next question naturally.
        let next = questions[questionIndex]

        let introduction: String

        switch next.id {

        case "location":
            introduction =
                "Good. Now let's check where the inventory was found. "

        case "count":
            introduction =
                "Next, I want to verify the actual quantity. "

        case "material":
            introduction =
                "Let's take a closer look at the material itself. "

        case "coil":
            introduction =
                "Now I want to check something that can cause inventory problems. "

        case "scrap":
            introduction =
                "Let's talk about rejected material and scrap. "

        case "bom":
            introduction =
                "I'd like to review how the parts were consumed during production. "

        case "mo":
            introduction =
                "Now let's check the manufacturing order. "

        case "transactions":
            introduction =
                "We're almost finished. Let's review the inventory postings. "

        case "other":
            introduction =
                "One last thing before I put the report together. "

        default:
            introduction = "All right. "
        }

        voice.speak(
            introduction + next.text
        )
    }


    @MainActor
    private func loadPart() async {

        loading = true
        errorMessage = nil

        defer {
            loading = false
        }

        do {
            part = try await repository.loadPart(
                number: partNumber
            )

            voice.speak(
                "Welcome to Foresight root cause analysis. "
                + "Let's verify your manufacturing part."
            )

        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func generateReport() async {

        guard let part, !generating else {
            return
        }

        generating = true
        errorMessage = nil

        defer {
            generating = false
        }

        do {

            let result = try await RCAReportAIService()
                .generate(
                    part: part,
                    answers: answers
                )
            
            let saved = SavedVoiceRCA(
                id: UUID(),
                partNumber: part.partNumber,
                partName: part.name,
                createdAt: Date(),
                answers: answers,
                report: result.report,
                model: result.model,
                inventoryLocations: part.inventoryLocations,
                erpTotalBalance:
                    part.stockQuantityKnown == false
                    ? nil
                    : part.stockQuantity
            )

            try VoiceRCAStorage.save(saved)

            generatedReport = saved

            voice.speak(
                "The root cause report has been generated "
                + "and saved. "
                + result.report.summary
            )

        
        } catch {

            if let urlError = error as? URLError,
               urlError.code == .timedOut {

                errorMessage =
                    "The investigation took longer than expected. " +
                    "Your answers are still available. " +
                    "Please try generating the report again."

            } else {

                errorMessage =
                    "Unable to generate your report: " +
                    error.localizedDescription
            }
        }
    }
}
//
//  VoiceRCAInvestigationView.swift
//  Foresight
//
//  Created by Yosadaq Esparza on 11/4/26.
//

