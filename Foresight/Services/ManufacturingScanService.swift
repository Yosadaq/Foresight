
import Foundation
import UIKit

struct ScanMatch: Decodable, Identifiable {
    let partNumber: String
    let description: String?
    let description2: String?
    let partType: String?
    let matchMethod: String

    var id: String { partNumber }

    var isExact: Bool {
        matchMethod == "exact_number"
    }
}

struct DetectedManufacturingItem: Decodable, Identifiable {
    let id: Int
    let label: String
    let description: String
    let partNumber: String
    let visibleText: String
    let visibleCount: Int?
    let countType: String
    let needsReview: Bool
    let notes: String
    let matches: [ScanMatch]
    let lookupError: Bool
}

struct ManufacturingScanResponse: Decodable {
    let success: Bool
    let model: String
    let items: [DetectedManufacturingItem]
    let totalVisibleCount: Int?
    let requiresConfirmation: Bool
    let inventoryUpdated: Bool
}

enum ScanError: LocalizedError {
    case invalidImage
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Unable to prepare the photograph."
        case .invalidResponse:
            return "The AI response could not be decoded."
        case .server(let message):
            return message
        }
    }
}

private struct ScanPayload: Encodable {
    let image: String
}

private struct ScanAPIError: Decodable {
    let error: String?
}

struct ManufacturingScanService {
    private let endpoint =
        "https://foresight-omega.vercel.app/api/scan"

    func analyze(
        image: UIImage
    ) async throws -> ManufacturingScanResponse {

        let longestSide: CGFloat = 1600

        let scale = min(
            1,
            longestSide / max(
                image.size.width,
                image.size.height
            )
        )

        let size = CGSize(
            width: max(1, image.size.width * scale),
            height: max(1, image.size.height * scale)
        )

        let renderer = UIGraphicsImageRenderer(size: size)

        let resized = renderer.image { _ in
            image.draw(
                in: CGRect(origin: .zero, size: size)
            )
        }

        guard let jpeg = resized.jpegData(
            compressionQuality: 0.68
        ) else {
            throw ScanError.invalidImage
        }

        let imageString =
            "data:image/jpeg;base64,"
            + jpeg.base64EncodedString()

        guard let url = URL(string: endpoint) else {
            throw ScanError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )

        request.httpBody = try JSONEncoder().encode(
            ScanPayload(image: imageString)
        )

        let (data, response) =
            try await URLSession.shared.data(
                for: request
            )

        guard let http = response as? HTTPURLResponse else {
            throw ScanError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            let detail = try? JSONDecoder().decode(
                ScanAPIError.self,
                from: data
            )

            throw ScanError.server(
                detail?.error
                ?? "Scan failed: HTTP \(http.statusCode)"
            )
        }

        do {
            return try JSONDecoder().decode(
                ManufacturingScanResponse.self,
                from: data
            )
        } catch {
            throw ScanError.invalidResponse
        }
    }
}
//
//  ManufacturingScanService.swift
//  Foresight
//
//  Created by Yosadaq Esparza on 10/27/26.
//

