
//
//  ContentView.swift
//  Foresight
//
//  Created by Yosadaq Esparza on 10/26/26.
//

import SwiftUI
import PhotosUI
import UIKit

struct ContentView: View {

    // MARK: - Camera & Photos

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var showCamera = false

    // MARK: - AI Scanning

    @State private var isAnalyzing = false
    @State private var analysisError: String?

    @State private var multiScanResult:
        ManufacturingScanResponse?

    @State private var showScanResults = false

    // MARK: - Manufacturing Database

    @State private var manualPartNumber = ""
    @State private var erpLookup: ManufacturingLookup?
    @State private var showingERPDetails = false
    @State private var isLoadingERP = false
    @State private var erpError: String?

    // MARK: - Services

    private let scanService = ManufacturingScanService()
    private let manufacturingAPI = ManufacturingAPIService()

    // MARK: - Theme

    private let navy = Color(
        red: 0.08,
        green: 0.12,
        blue: 0.21
    )

    private let cyan = Color(
        red: 0.18,
        green: 0.79,
        blue: 0.95
    )

    private let panelBackground = Color(
        red: 0.11,
        green: 0.13,
        blue: 0.17
    )

    // MARK: - Body

    var body: some View {

        NavigationStack {

            ScrollView {

                VStack(spacing: 22) {

                    header

                    imagePreview

                    // MARK: Camera Button

                    Button {

                        guard UIImagePickerController
                            .isSourceTypeAvailable(.camera)
                        else {
                            analysisError =
                                "Camera is unavailable on this device."
                            return
                        }

                        showCamera = true

                    } label: {

                        Label(
                            "Open Camera",
                            systemImage: "camera.fill"
                        )
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()

                    }
                    .buttonStyle(.borderedProminent)
                    .tint(cyan)
                    .disabled(isAnalyzing)

                    // MARK: Photo Library

                    PhotosPicker(
                        selection: $selectedPhoto,
                        matching: .images
                    ) {

                        Label(
                            "Choose Existing Photo",
                            systemImage: "photo.on.rectangle"
                        )
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()

                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    .disabled(isAnalyzing)

                    // MARK: Scan Button

                    if selectedImage != nil {

                        Button {

                            Task {
                                await analyzeSelectedImage()
                            }

                        } label: {

                            HStack(spacing: 12) {

                                if isAnalyzing {

                                    ProgressView()
                                        .tint(.black)

                                } else {

                                    Image(
                                        systemName: "viewfinder"
                                    )
                                }

                                Text(
                                    isAnalyzing
                                    ? "Identifying & Counting..."
                                    : "Scan, Identify & Count"
                                )
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()

                        }
                        .buttonStyle(.borderedProminent)
                        .tint(cyan)
                        .disabled(isAnalyzing)
                    }

                    // MARK: Scanning Status

                    if isAnalyzing {

                        VStack(spacing: 10) {

                            ProgressView()
                                .tint(cyan)

                            Text(
                                "Analyzing manufacturing parts..."
                            )
                            .font(.subheadline)

                            Text(
                                "Detecting parts, estimating quantities, "
                                + "and searching manufacturing records."
                            )
                            .font(.caption)
                            .foregroundStyle(.gray)
                            .multilineTextAlignment(.center)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity)
                        .background(
                            panelBackground,
                            in: RoundedRectangle(
                                cornerRadius: 16
                            )
                        )
                    }

                    // MARK: Scan Error

                    if let analysisError {

                        Label(
                            analysisError,
                            systemImage:
                                "exclamationmark.triangle.fill"
                        )
                        .font(.subheadline)
                        .foregroundStyle(
                            Color(red: 1, green: 0.4, blue: 0.4)
                        )
                        .frame(
                            maxWidth: .infinity,
                            alignment: .leading
                        )
                        .padding()
                        .background(
                            Color.red.opacity(0.12),
                            in: RoundedRectangle(
                                cornerRadius: 14
                            )
                        )
                    }

                    // MARK: Manufacturing Search

                    manualLookupCard
                    
                    
                    NavigationLink {

                        SavedRCAReportsView()

                    } label: {

                        Label(
                            "Saved Root Cause Reports",
                            systemImage: "doc.text.magnifyingglass"
                        )
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(16)
                    }
                    .buttonStyle(.bordered)
                    .tint(cyan)


                    // MARK: Footer

                    HStack(spacing: 6) {

                        Image(systemName: "checkmark.shield")

                        Text(
                            "AI findings require verification "
                            + "before inventory updates."
                        )
                    }
                    .font(.caption2)
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 20)
                }
                
                
                .padding(18)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .background(
                Color.black.ignoresSafeArea()
            )
            .foregroundStyle(.white)
            .toolbar(.hidden, for: .navigationBar)

            // MARK: Photo Selection

            .onChange(of: selectedPhoto) { _, photo in

                Task {

                    guard let photo else {
                        return
                    }

                    do {

                        guard let data =
                            try await photo.loadTransferable(
                                type: Data.self
                            ),
                            let image = UIImage(data: data)
                        else {
                            await MainActor.run {
                                analysisError =
                                    "Unable to load selected photo."
                            }
                            return
                        }

                        await MainActor.run {
                            resetScan()
                            selectedImage = image
                        }

                    } catch {

                        await MainActor.run {
                            analysisError =
                                error.localizedDescription
                        }
                    }
                }
            }

            // MARK: Camera Sheet

            .sheet(isPresented: $showCamera) {

                CameraView { image in

                    resetScan()

                    selectedImage = image
                }
            }

            // MARK: Scan Results Sheet

            .sheet(isPresented: $showScanResults) {

                if let multiScanResult {

                    NavigationStack {

                        ScanResultsView(
                            result: multiScanResult
                        )
                        .toolbar {

                            ToolbarItem(
                                placement: .topBarTrailing
                            ) {

                                Button("Done") {
                                    showScanResults = false
                                }
                            }
                        }
                    }
                    .preferredColorScheme(.light)
                }
            }

            // MARK: ERP Details Sheet

            .sheet(isPresented: $showingERPDetails) {

                if let erpLookup {

                    NavigationStack {

                        ERPPartDetailsView(
                            lookup: erpLookup,
                            rcaRepository: VercelRCARepository()
                        )
                        .toolbar {

                            ToolbarItem(
                                placement: .topBarTrailing
                            ) {

                                Button("Done") {
                                    showingERPDetails = false
                                }
                            }
                        }
                    }
                    .preferredColorScheme(.light)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var header: some View {

        VStack(spacing: 8) {

            Image(systemName: "viewfinder")
                .font(.system(size: 46))
                .foregroundStyle(cyan)

            Text("FORESIGHT")
                .font(
                    .system(
                        size: 32,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .tracking(4)

            Text("AI Manufacturing Intelligence")
                .font(.subheadline)
                .foregroundStyle(.gray)

            Text("Powered by Meta AI")
                .font(.caption)
                .foregroundStyle(cyan)
        }
        .padding(.top, 22)
    }

    // MARK: - Image Preview

    private var imagePreview: some View {

        ZStack {

            RoundedRectangle(
                cornerRadius: 22
            )
            .fill(panelBackground)

            if let selectedImage {

                Image(uiImage: selectedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: 310
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 22
                        )
                    )

            } else {

                VStack(spacing: 14) {

                    Image(
                        systemName: "camera.viewfinder"
                    )
                    .font(.system(size: 55))
                    .foregroundStyle(cyan)

                    Text(
                        "Scan Manufacturing Inventory"
                    )
                    .font(.headline)

                    Text(
                        "Capture one part or multiple parts "
                        + "in a single photograph."
                    )
                    .font(.caption)
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
        .frame(height: 310)
        .overlay {

            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    cyan.opacity(0.25),
                    lineWidth: 1
                )
        }
    }

    // MARK: - Manual Part Lookup

   
 
    private var manualLookupCard: some View {

        VStack(
            alignment: .leading,
            spacing: 16
        ) {

            // MARK: - Manufacturing Part Lookup

            Label(
                "Manufacturing Part Lookup",
                systemImage: "magnifyingglass"
            )
            .font(.headline)
            .foregroundStyle(.white)

            Text(
                "Search your manufacturing database "
                + "using a part number to view inventory, "
                + "engineering specifications, and "
                + "perform AI root cause analysis."
            )
            .font(.caption)
            .foregroundStyle(.gray)

            // MARK: - Part Number Input

            TextField(
                "Enter manufacturing part number",
                text: $manualPartNumber
            )
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .padding(14)
            .background(
                Color.white,
                in: RoundedRectangle(
                    cornerRadius: 12
                )
            )
            .foregroundStyle(navy)
            .submitLabel(.search)
            .onSubmit {
                Task {
                    await loadERPPart(
                        number: manualPartNumber
                    )
                }
            }

            // MARK: - Search Database Button

            Button {

                Task {
                    await loadERPPart(
                        number: manualPartNumber
                    )
                }

            } label: {

                HStack(spacing: 10) {

                    if isLoadingERP {

                        ProgressView()
                            .tint(cyan)

                    } else {

                        Image(
                            systemName: "externaldrive.fill"
                        )
                    }

                    Text(
                        isLoadingERP
                        ? "Searching Database..."
                        : "Search Manufacturing Database"
                    )
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()

            }
            .buttonStyle(.bordered)
            .tint(cyan)
            .disabled(
                isLoadingERP ||
                manualPartNumber
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    .isEmpty
            )

            // MARK: - Search Error

            if let erpError {

                Label(
                    erpError,
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption)
                .foregroundStyle(
                    Color(red: 1, green: 0.4, blue: 0.4)
                )
            }
        }
        .padding(18)
        .background(
            panelBackground,
            in: RoundedRectangle(
                cornerRadius: 18
            )
        )
    }


    // MARK: - Reset Previous Scan

    @MainActor
    private func resetScan() {

        analysisError = nil

        multiScanResult = nil

        showScanResults = false
    }

    // MARK: - Analyze Selected Image

    @MainActor
    private func analyzeSelectedImage() async {

        guard let image = selectedImage else {
            return
        }

        guard !isAnalyzing else {
            return
        }

        isAnalyzing = true

        analysisError = nil
        multiScanResult = nil

        defer {
            isAnalyzing = false
        }

        do {

            // Send the photograph to the
            // manufacturing multi-scan API.

            let result = try await scanService.analyze(
                image: image
            )

            // Preserve detected components and counts.

            multiScanResult = result

            // Present all detected manufacturing parts.

            showScanResults = true

        } catch {

            analysisError = error.localizedDescription
        }
    }

    // MARK: - Manufacturing Database Lookup

    @MainActor
    private func loadERPPart(
        number: String
    ) async {

        guard !isLoadingERP else {
            return
        }

        let normalized = number
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .uppercased()

        guard !normalized.isEmpty else {
            erpError = "Enter a valid part number."
            return
        }

        isLoadingERP = true
        erpError = nil

        defer {
            isLoadingERP = false
        }

        do {

            let result =
                try await manufacturingAPI.findPart(
                    number: normalized
                )

            erpLookup = result

            showingERPDetails = true

        } catch {

            erpError = error.localizedDescription
        }
    }
}
