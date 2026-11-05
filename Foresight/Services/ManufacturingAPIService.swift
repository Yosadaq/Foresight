//
//  ManufacturingAPIService.swift
//  Foresight
//
//  Created by Yosadaq Esparza on 10/27/26.
//


import Foundation

struct ManufacturingLookup: Decodable {
    let success: Bool
    let source: String
    let part: ERPPart
    let inventory: [ERPInventoryBalance]
    let totalBalance: Double
    let inventoryStatus: String
}

struct ERPPart: Decodable, Identifiable {
    let partNumber: String
    let description: String?
    let description2: String?
    let typeCode: String?
    let partType: String?

    var id: String { partNumber }
}

struct ERPInventoryBalance: Decodable, Identifiable {
    let id: Int
    let area: String?
    let balance: Double
    let standardCost: Double?
    let inventoryValue: Double?
}

enum ManufacturingAPIError: LocalizedError {
    case invalidPartNumber
    case notFound
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidPartNumber:
            return "Please enter a valid part number."
        case .notFound:
            return "This part was not found in the database."
        case .serverError(let status):
            return "Manufacturing API error: \(status)"
        }
    }
}

struct ManufacturingAPIService {
    private let baseURL =
        "https://foresight-omega.vercel.app/api/parts"

    func findPart(number: String) async throws -> ManufacturingLookup {
        let normalized = number
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        guard !normalized.isEmpty,
              let encoded = normalized.addingPercentEncoding(
                  withAllowedCharacters: .urlPathAllowed
              ),
              let url = URL(string: "\(baseURL)/\(encoded)") else {
            throw ManufacturingAPIError.invalidPartNumber
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue(
            "application/json",
            forHTTPHeaderField: "Accept"
        )

        let (data, response) = try await URLSession.shared.data(
            for: request
        )

        guard let http = response as? HTTPURLResponse else {
            throw ManufacturingAPIError.serverError(0)
        }

        if http.statusCode == 404 {
            throw ManufacturingAPIError.notFound
        }

        guard (200...299).contains(http.statusCode) else {
            throw ManufacturingAPIError.serverError(
                http.statusCode
            )
        }

        return try JSONDecoder().decode(
            ManufacturingLookup.self,
            from: data
        )
    }
}
