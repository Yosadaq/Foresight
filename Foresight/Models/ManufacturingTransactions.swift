
//
//  ManufacturingTransactions.swift
//  Foresight
//
//  Created on 10/31/26.
//

import SwiftUI
import Foundation
import Combine
import Speech
import AVFoundation

enum ManufacturingAction:
    String,
    CaseIterable,
    Identifiable,
    Codable {

    case production = "Report Production"
    case transfer = "Transfer Pieces"
    case scrap = "Report Scrap"
    case manufacturingOrder = "Report to MO"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .production:
            return "checkmark.seal.fill"
        case .transfer:
            return "arrow.left.arrow.right"
        case .scrap:
            return "trash.fill"
        case .manufacturingOrder:
            return "doc.text.fill"
        }
    }

    var color: Color {
        switch self {
        case .production:
            return .green
        case .transfer:
            return .blue
        case .scrap:
            return .red
        case .manufacturingOrder:
            return .orange
        }
    }

    var explanation: String {
        switch self {
        case .production:
            return "Record completed pieces and their receiving location."

        case .transfer:
            return "Move pieces between manufacturing locations or rework areas."

        case .scrap:
            return "Record rejected pieces and their scrap reason."

        case .manufacturingOrder:
            return "Issue existing inventory to a manufacturing order."
        }
    }
}

struct ManufacturingTransactionDraft: Codable {

    var action: ManufacturingAction
    var partID: String

    var quantity: Int = 0

    var fromLocationID: String = ""
    var toLocationID: String = ""

    var manufacturingOrderID: String = ""
    var operationID: String = ""

    var lotID: String = ""
    var reasonCode: String = ""
    var notes: String = ""

    var scannedEvidenceID: String? = nil

    var idempotencyKey: UUID = UUID()
}

struct ManufacturingTransactionReceipt: Decodable {

    let transactionID: String
    let newBalance: Int?
}

protocol ManufacturingTransactionService {

    func submit(
        _ draft: ManufacturingTransactionDraft
    ) async throws -> ManufacturingTransactionReceipt
}

struct VoiceFormSuggestions: Decodable {

    var quantity: Int?

    var fromLocationID: String?
    var toLocationID: String?

    var manufacturingOrderID: String?
    var operationID: String?

    var lotID: String?
    var reasonCode: String?
    var notes: String?
}

protocol ManufacturingVoiceFormAgent {

    func suggestFields(
        transcript: String,
        action: ManufacturingAction,
        partID: String
    ) async throws -> VoiceFormSuggestions
}

struct ManufacturingActionsView: View {

    let part: ManufacturingPart
    let stockQuantity: Int?

    let service: any ManufacturingTransactionService

    var voiceAgent:
        (any ManufacturingVoiceFormAgent)? = nil

    @State private var chosenAction:
        ManufacturingAction?

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 16
        ) {

            stockSection

            actionGrid
        }
        .sheet(item: $chosenAction) { action in

            NavigationStack {

                ManufacturingTransactionForm(
                    part: part,
                    action: action,
                    service: service,
                    stockQuantity: stockQuantity,
                    voiceAgent: voiceAgent
                )
            }
        }
    }

    private var stockSection: some View {

        VStack(
            alignment: .leading,
            spacing: 12
        ) {

            HStack {

                Label(
                    "Stock Quantity",
                    systemImage: "square.stack.3d.up.fill"
                )
                .font(.headline)

                Spacer()

                Text("Database")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {

                Text("Total")
                    .foregroundStyle(.secondary)

                Spacer()

                Text(
                    stockQuantity?.formatted()
                    ?? "Not available"
                )
                .font(.title2.bold())
                .foregroundStyle(
                    (stockQuantity ?? 0) < 0
                    ? Color.red
                    : Color.primary
                )
            }

            if let stockQuantity,
               stockQuantity < 0 {

                Label(
                    "Negative inventory balance. Investigation required.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.footnote)
                .foregroundStyle(.orange)
            }
        }
        .padding()
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 18)
        )
    }

    private var actionGrid: some View {

        LazyVGrid(
            columns: columns,
            spacing: 12
        ) {

            ForEach(
                ManufacturingAction.allCases
            ) { action in

                Button {

                    chosenAction = action

                } label: {

                    VStack(
                        alignment: .leading,
                        spacing: 12
                    ) {

                        Image(
                            systemName: action.symbol
                        )
                        .font(.title2)

                        Spacer(minLength: 8)

                        Text(action.rawValue)
                            .font(.headline)
                            .multilineTextAlignment(.leading)

                        Text(action.explanation)
                            .font(.caption)
                            .multilineTextAlignment(.leading)
                            .lineLimit(3)
                    }
                    .frame(
                        maxWidth: .infinity,
                        minHeight: 152,
                        alignment: .leading
                    )
                    .padding()
                    .foregroundStyle(.white)
                    .background(
                        action.color,
                        in: RoundedRectangle(
                            cornerRadius: 18
                        )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct ManufacturingTransactionForm: View {

    let part: ManufacturingPart
    let action: ManufacturingAction

    let service:
        any ManufacturingTransactionService

    let stockQuantity: Int?

    var voiceAgent:
        (any ManufacturingVoiceFormAgent)? = nil

    @Environment(\.dismiss)
    private var dismiss

    // MARK: Form State

    @State private var quantityText = ""

    @State private var from = ""
    @State private var to = ""

    @State private var mo = ""
    @State private var operation = ""

    @State private var lot = ""
    @State private var reason = ""
    @State private var notes = ""

    // One UUID per logical transaction.
    @State private var transactionKey = UUID()

    // Frozen after first submission attempt.
    @State private var submittedDraft:
        ManufacturingTransactionDraft?

    @State private var hasAttemptedSubmission = false

    @State private var busy = false
    @State private var processingVoice = false

    @State private var showConfirm = false
    @State private var errorMessage: String?

    @State private var receipt:
        ManufacturingTransactionReceipt?

    @State private var suggestions:
        VoiceFormSuggestions?

    @StateObject private var voice =
        ManufacturingVoiceGuide()

    // MARK: Computed Values

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    private var quantity: Int? {

        guard let value = Int(
            trimmed(quantityText)
        ), value > 0 else {
            return nil
        }

        return value
    }

    private var fieldsLocked: Bool {
        hasAttemptedSubmission
        || busy
        || receipt != nil
    }

    private var valid: Bool {

        guard quantity != nil else {
            return false
        }

        switch action {

        case .production:

            return !trimmed(to).isEmpty
                && !trimmed(mo).isEmpty

        case .transfer:

            let source = trimmed(from)
            let destination = trimmed(to)

            return !source.isEmpty
                && !destination.isEmpty
                && source.caseInsensitiveCompare(
                    destination
                ) != .orderedSame
                && !trimmed(reason).isEmpty

        case .scrap:

            return !trimmed(from).isEmpty
                && !trimmed(reason).isEmpty

        case .manufacturingOrder:

            return !trimmed(from).isEmpty
                && !trimmed(mo).isEmpty
                && !trimmed(operation).isEmpty
        }
    }

    // MARK: Stable Transaction Draft

    private var draft: ManufacturingTransactionDraft {

        ManufacturingTransactionDraft(
            action: action,
            partID: part.id,
            quantity: quantity ?? 0,
            fromLocationID: trimmed(from),
            toLocationID: trimmed(to),
            manufacturingOrderID: trimmed(mo),
            operationID: trimmed(operation),
            lotID: trimmed(lot),
            reasonCode: trimmed(reason),
            notes: trimmed(notes),
            scannedEvidenceID: nil,
            idempotencyKey: transactionKey
        )
    }

    private var currentPrompt: String {
        voice.prompt(
            for: action,
            draft: submittedDraft ?? draft
        )
    }

    // MARK: Main View

    var body: some View {

        Form {

            partSection

            transactionSection

            voiceSection

            reviewSection
        }
        .navigationTitle(action.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {

            ToolbarItem(
                placement: .topBarTrailing
            ) {

                Button("Done") {
                    dismiss()
                }
                .disabled(busy)
            }
        }
        .confirmationDialog(
            "Confirm \(action.rawValue)",
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {

            Button(
                "Post \(quantity ?? 0) pieces"
            ) {

                Task {
                    await submit()
                }
            }

            Button(
                "Cancel",
                role: .cancel
            ) {}

        } message: {

            Text(
                "Confirm the selected part, quantity, locations and manufacturing order before posting."
            )
        }
        .onDisappear {

            voice.stop()
            voice.stopSpeaking()
        }
    }

    // MARK: Part Information

    private var partSection: some View {

        Section("Part Details") {

            LabeledContent(
                "Part Number",
                value: part.id
            )

            Text(part.description)
                .font(.subheadline)

            LabeledContent(
                "Stock",
                value: stockQuantity.map {
                    "\($0.formatted()) pieces"
                } ?? "Not available"
            )

            LabeledContent(
                "Data Source",
                value: "Database"
            )

            if let stockQuantity,
               stockQuantity < 0 {

                Label(
                    "Existing negative inventory balance.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.footnote)
                .foregroundStyle(.orange)
            }
        }
    }

    // MARK: Transaction Fields

    private var transactionSection: some View {

        Section("Transaction Details") {

            Text(action.explanation)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Group {

                TextField(
                    "Quantity (pieces)",
                    text: $quantityText
                )
                .keyboardType(.numberPad)

                if action != .production {

                    TextField(
                        "From Location",
                        text: $from
                    )
                    .textInputAutocapitalization(
                        .characters
                    )
                }

                if action == .production
                    || action == .transfer {

                    TextField(
                        "To Location",
                        text: $to
                    )
                    .textInputAutocapitalization(
                        .characters
                    )
                }

                if action == .production
                    || action == .manufacturingOrder {

                    TextField(
                        "Manufacturing Order",
                        text: $mo
                    )
                }

                if action == .manufacturingOrder {

                    TextField(
                        "Operation ID",
                        text: $operation
                    )
                }

                if action == .transfer
                    || action == .scrap {

                    TextField(
                        "Reason Code",
                        text: $reason
                    )
                }

                TextField(
                    "Lot / Batch (Optional)",
                    text: $lot
                )

                TextField(
                    "Notes",
                    text: $notes,
                    axis: .vertical
                )
                .lineLimit(2...5)
            }
            .disabled(fieldsLocked)

            if fieldsLocked {

                Label(
                    "Fields are locked to preserve this transaction's original submission.",
                    systemImage: "lock.fill"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Voice Section

    private var voiceSection: some View {

        Section("Voice AI Assistant") {

            Label(
                currentPrompt,
                systemImage: "waveform"
            )
            .font(.subheadline)

            HStack(spacing: 18) {

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
                            ? "Stop"
                            : "Dictate",
                        systemImage: voice.isListening
                            ? "stop.circle.fill"
                            : "mic.fill"
                    )
                }
                .disabled(fieldsLocked)

                Spacer()

                Button {

                    voice.speak(currentPrompt)

                } label: {

                    Label(
                        "Listen",
                        systemImage: "speaker.wave.2.fill"
                    )
                }
            }

            if voice.isListening {

                Label(
                    "Listening...",
                    systemImage: "waveform"
                )
                .foregroundStyle(.blue)
            }

            if !voice.transcript.isEmpty {

                VStack(
                    alignment: .leading,
                    spacing: 8
                ) {

                    Text("Transcript")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    Text(voice.transcript)
                        .font(.subheadline)
                }

                if let voiceAgent {

                    Button {

                        Task {
                            await extractVoiceFields(
                                using: voiceAgent
                            )
                        }

                    } label: {

                        Label(
                            processingVoice
                                ? "Processing..."
                                : "Extract Fields with AI",
                            systemImage: "sparkles"
                        )
                    }
                    .disabled(
                        fieldsLocked
                        || processingVoice
                        || voice.isListening
                    )

                } else {

                    Button("Use Transcript as Notes") {

                        notes = voice.transcript
                    }
                    .disabled(fieldsLocked)
                }
            }

            if let suggestions {

                VStack(
                    alignment: .leading,
                    spacing: 10
                ) {

                    Text("AI Suggestions")
                        .font(.headline)

                    Text(
                        suggestionSummary(suggestions)
                    )
                    .font(.footnote)

                    Button("Apply Suggestions") {

                        apply(suggestions)
                    }
                    .disabled(fieldsLocked)
                }
            }

            Text(
                "AI suggestions must be reviewed before submission. Voice input cannot directly post inventory."
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            if let voiceError = voice.errorMessage {

                Text(voiceError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }
    
    private var reviewSection: some View {

        Section("Review & Verification") {

            LabeledContent(
                "Transaction",
                value: action.rawValue
            )
            
            LabeledContent(
                "Quantity",
                value: "\(quantity ?? 0) pieces"
            )

            Text(
                "Request ID: \(transactionKey.uuidString)"
            )
            .font(.caption2)
            .foregroundStyle(.secondary)
            .textSelection(.enabled)

            if let stockQuantity,
               stockQuantity < 0 {

                Label(
                    "Imported stock is negative. This transaction does not automatically reconcile the balance.",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.footnote)
                .foregroundStyle(.orange)
            }

            if let receipt {

                Label(
                    "Transaction Posted",
                    systemImage: "checkmark.circle.fill"
                )
                .foregroundStyle(.green)

                LabeledContent(
                    "Transaction ID",
                    value: receipt.transactionID
                )

                if let balance = receipt.newBalance {

                    LabeledContent(
                        "Updated Balance",
                        value: balance.formatted()
                    )
                }
            }

            if let errorMessage {

                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            if hasAttemptedSubmission
                && receipt == nil {

                Label(
                    "Submission status has not been confirmed. Retry only with the same request ID.",
                    systemImage: "exclamationmark.circle"
                )
                .font(.footnote)
                .foregroundStyle(.orange)
            }

            Button {

                if hasAttemptedSubmission {

                    Task {
                        await submit()
                    }

                } else {

                    showConfirm = true
                }

            } label: {

                HStack {

                    Spacer()

                    if busy {

                        ProgressView()
                    }

                    Text(
                        busy
                        ? "Submitting..."
                        : hasAttemptedSubmission
                            ? "Retry Submission"
                            : "Review & Submit"
                    )
                    .fontWeight(.semibold)

                    Spacer()
                }
            }
            .disabled(
                busy
                || receipt != nil
                || (!hasAttemptedSubmission && !valid)
            )
        }
    }

    // MARK: AI Extraction

    @MainActor
    private func extractVoiceFields(
        using agent: any ManufacturingVoiceFormAgent
    ) async {

        guard !fieldsLocked,
              !processingVoice else {
            return
        }

        processingVoice = true
        errorMessage = nil

        defer {
            processingVoice = false
        }

        do {

            suggestions = try await agent.suggestFields(
                transcript: voice.transcript,
                action: action,
                partID: part.id
            )

        } catch {

            errorMessage =
                "AI extraction failed: \(error.localizedDescription)"
        }
    }

    // MARK: Suggestions

    private func suggestionSummary(
        _ proposed: VoiceFormSuggestions
    ) -> String {

        let values: [String?] = [

            proposed.quantity.map {
                "Quantity: \($0)"
            },

            proposed.fromLocationID.map {
                "From: \($0)"
            },

            proposed.toLocationID.map {
                "To: \($0)"
            },

            proposed.manufacturingOrderID.map {
                "MO: \($0)"
            },

            proposed.operationID.map {
                "Operation: \($0)"
            },

            proposed.reasonCode.map {
                "Reason: \($0)"
            }
        ]

        let result = values.compactMap { $0 }

        return result.isEmpty
            ? "No recognized fields."
            : result.joined(separator: "\n")
    }

    private func apply(
        _ proposed: VoiceFormSuggestions
    ) {

        guard !fieldsLocked else {
            return
        }

        if let value = proposed.quantity,
           value > 0 {

            quantityText = String(value)
        }

        if let value = proposed.fromLocationID {
            from = value
        }

        if let value = proposed.toLocationID {
            to = value
        }

        if let value = proposed.manufacturingOrderID {
            mo = value
        }

        if let value = proposed.operationID {
            operation = value
        }

        if let value = proposed.lotID {
            lot = value
        }

        if let value = proposed.reasonCode {
            reason = value
        }

        if let value = proposed.notes {
            notes = value
        }

        suggestions = nil
    }

    // MARK: Transaction Submission

    @MainActor
    private func submit() async {

        guard !busy,
              receipt == nil else {
            return
        }

        // Only validate when creating the first submission.
        // Retries must reuse the original payload.
        if submittedDraft == nil {

            guard valid else {
                errorMessage =
                    "Complete all required transaction fields."
                return
            }

            submittedDraft = draft
        }

        guard let transaction = submittedDraft else {
            return
        }

        hasAttemptedSubmission = true
        busy = true
        errorMessage = nil

        voice.stop()

        defer {
            busy = false
        }

        do {

            let result = try await service.submit(
                transaction
            )

            receipt = result

        } catch {

            errorMessage = """
            Submission could not be confirmed.

            The original transaction may already have reached the server.

            Retry only with the same request ID. Do not create another transaction until the original status is verified.

            \(error.localizedDescription)
            """
        }
    }
}

@MainActor
final class ManufacturingVoiceGuide:
    NSObject,
    ObservableObject,
    SFSpeechRecognizerDelegate {

    @Published var transcript = ""
    @Published var isListening = false
    @Published var errorMessage: String?

    private let recognizer =
        SFSpeechRecognizer(
            locale: Locale(identifier: "en_US")
        )

    private let engine = AVAudioEngine()
    private let synthesizer =
        AVSpeechSynthesizer()

    private var request:
        SFSpeechAudioBufferRecognitionRequest?

    private var recognitionTask:
        SFSpeechRecognitionTask?

    private var hasInstalledTap = false
    private var speechSessionID = UUID()

    // MARK: Dynamic Questions

    func prompt(
        for action: ManufacturingAction,
        draft: ManufacturingTransactionDraft
    ) -> String {

        if draft.quantity <= 0 {

            return "How many pieces are you recording?"
        }

        switch action {

        case .production:

            if draft.manufacturingOrderID.isEmpty {
                return "Which manufacturing order produced these parts?"
            }

            if draft.toLocationID.isEmpty {
                return "Which location received the completed parts?"
            }

        case .transfer:

            if draft.fromLocationID.isEmpty {
                return "Which area are the pieces leaving?"
            }

            if draft.toLocationID.isEmpty {
                return "Where are the pieces going?"
            }

            if draft.reasonCode.isEmpty {
                return "What is the reason for this transfer?"
            }

        case .scrap:

            if draft.fromLocationID.isEmpty {
                return "Where was the scrap generated?"
            }

            if draft.reasonCode.isEmpty {
                return "What caused these pieces to be scrapped?"
            }

        case .manufacturingOrder:

            if draft.manufacturingOrderID.isEmpty {
                return "Which manufacturing order needs these pieces?"
            }

            if draft.operationID.isEmpty {
                return "Which manufacturing operation?"
            }

            if draft.fromLocationID.isEmpty {
                return "Which inventory location are the pieces coming from?"
            }
        }

        return "All required fields are filled. Please verify the transaction."
    }

    // MARK: - Natural Voice Selection

    private var preferredVoice: AVSpeechSynthesisVoice? {

        let voices = AVSpeechSynthesisVoice.speechVoices()
            .filter {
                $0.language.lowercased()
                    .hasPrefix("en-us")
            }

        // Prefer the highest-quality system voice installed
        // on the user's device.
        return voices.first {
            $0.quality == .premium
        }
        ?? voices.first {
            $0.quality == .enhanced
        }
        ?? AVSpeechSynthesisVoice(language: "en-US")
    }

    // MARK: - Natural Speech

    func speak(_ message: String) {

        stopSpeaking()

        let utterance = AVSpeechUtterance(
            string: message
        )

        utterance.voice = preferredVoice

        utterance.rate = 0.51
        utterance.pitchMultiplier = 1.03
        utterance.volume = 1.0

        utterance.preUtteranceDelay = 0.08
        utterance.postUtteranceDelay = 0.12

        synthesizer.speak(utterance)
    }

    // MARK: - Clear Previous Voice Answer

    func clearTranscript() {

        stop()

        transcript = ""
        errorMessage = nil
    }


    func stopSpeaking() {

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(
                at: .immediate
            )
        }
    }

    // MARK: Start Recognition

    func start() async {

        stop()
        stopSpeaking()

        transcript = ""
        errorMessage = nil

        let authorization =
            await withCheckedContinuation {
                continuation in

                SFSpeechRecognizer.requestAuthorization {
                    status in

                    continuation.resume(
                        returning: status
                    )
                }
            }

        guard authorization == .authorized else {

            errorMessage =
                "Speech recognition permission denied."

            return
        }

        let micAllowed =
            await withCheckedContinuation {
                continuation in

                AVAudioApplication.requestRecordPermission {
                    allowed in

                    continuation.resume(
                        returning: allowed
                    )
                }
            }

        guard micAllowed else {

            errorMessage =
                "Microphone permission denied."

            return
        }

        guard let recognizer,
              recognizer.isAvailable else {

            errorMessage =
                "Speech recognition is currently unavailable."

            return
        }

        let sessionID = UUID()
        speechSessionID = sessionID

        do {

            let audioSession =
                AVAudioSession.sharedInstance()

            try audioSession.setCategory(
                .playAndRecord,
                mode: .default,
                options: [
                    .defaultToSpeaker,
                    .allowBluetooth
                ]
            )

            try audioSession.setActive(true)

            let newRequest =
                SFSpeechAudioBufferRecognitionRequest()

            newRequest.shouldReportPartialResults = true

            request = newRequest

            let input = engine.inputNode

            let format = input.outputFormat(
                forBus: 0
            )

            input.installTap(
                onBus: 0,
                bufferSize: 1024,
                format: format
            ) { buffer, _ in

                newRequest.append(buffer)
            }

            hasInstalledTap = true

            engine.prepare()

            recognitionTask =
                recognizer.recognitionTask(
                    with: newRequest
                ) { [weak self] result, error in

                    Task { @MainActor in

                        guard let self,
                              self.speechSessionID == sessionID else {
                            return
                        }

                        if let result {

                            self.transcript =
                                result.bestTranscription.formattedString
                        }

                        if let error {

                            self.errorMessage =
                                error.localizedDescription

                            self.stop()

                        } else if result?.isFinal == true {

                            self.stop()
                        }
                    }
                }

            try engine.start()

            isListening = true

        } catch {

            errorMessage =
                "Unable to start microphone: \(error.localizedDescription)"

            stop()
        }
    }

    // MARK: Stop Recognition

    func stop() {

        // Ignore callbacks from an earlier recognition task.
        speechSessionID = UUID()

        if engine.isRunning {
            engine.stop()
        }

        if hasInstalledTap {

            engine.inputNode.removeTap(
                onBus: 0
            )

            hasInstalledTap = false
        }

        request?.endAudio()
        recognitionTask?.cancel()

        request = nil
        recognitionTask = nil

        isListening = false
    }
}
