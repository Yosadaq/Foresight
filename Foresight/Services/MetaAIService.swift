//
//  MetaAIService.swift
//  Foresight
//
//  Created by Yosadaq Esparza on 10/26/26.
//


import Foundation
import UIKit

struct PartAnalysis: Decodable {
    let success: Bool
    let model: String
    let result: String
}

enum ForesightError: LocalizedError {
    case invalidURL
    case imageProcessingFailed
    case invalidResponse
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The backend URL is not configured."
        case .imageProcessingFailed:
            return "Unable to process this image."
        case .invalidResponse:
            return "The server returned an invalid response."
        case .serverError(let message):
            return message
        }
    }
}

struct MetaAIService {

    private let endpoint =
        "https://foresight-omega.vercel.app/api/analyze"

    func analyze(image: UIImage) async throws -> PartAnalysis {

        guard let url = URL(string: endpoint) else {
            throw ForesightError.invalidURL
        }

        // Resize photos to avoid oversized API requests.
        let maxDimension: CGFloat = 1400
        let scale = min(
            1,
            maxDimension / max(image.size.width, image.size.height)
        )

        let newSize = CGSize(
            width: max(1, image.size.width * scale),
            height: max(1, image.size.height * scale)
        )

        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }

        guard let imageData = resized.jpegData(
            compressionQuality: 0.65
        ) else {
            throw ForesightError.imageProcessingFailed
        }

        let encoded = imageData.base64EncodedString()
        let dataURL = "data:image/jpeg;base64,\(encoded)"

        let body = ScanRequest(image: dataURL)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120

        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )

        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(
            for: request
        )

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ForesightError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let error = try? JSONDecoder().decode(
                APIErrorResponse.self,
                from: data
            )

            throw ForesightError.serverError(
                error?.error ?? "Server error: \(httpResponse.statusCode)"
            )
        }

        return try JSONDecoder().decode(
            PartAnalysis.self,
            from: data
        )
    }
}

private struct ScanRequest: Encodable {
    let image: String
}

private struct APIErrorResponse: Decodable {
    let error: String
}
