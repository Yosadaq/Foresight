//
//  ManifacturingPart.swift
//  Foresight
//
//  Created by Yosadaq Esparza on 10/26/26.
//

import Foundation

struct ManufacturingComponent: Identifiable, Decodable {
    let id: UUID
    let manufacturerID: String
    let manufacturerPartNumber: String?
    let internalPartNumber: String?
    let name: String
    let description: String?
    let category: String
    let material: String?
    let compatibleModels: [String]
    let verificationStatus: String
    let inventoryPartNumber: String?

    enum CodingKeys: String, CodingKey {
        case id
        case manufacturerID = "manufacturer_id"
        case manufacturerPartNumber =
            "manufacturer_part_number"
        case internalPartNumber = "internal_part_number"
        case name
        case description
        case category
        case material
        case compatibleModels = "compatible_models"
        case verificationStatus = "verification_status"
        case inventoryPartNumber = "inventory_part_number"
    }
}

struct ComponentSearchResponse: Decodable {
    let success: Bool
    let query: String
    let results: [ManufacturingComponent]
}

struct ComponentCatalogService {
    private let baseURL =
        "https://foresight-omega.vercel.app/api/components/search"

    func search(
        _ query: String
    ) async throws -> [ManufacturingComponent] {

        guard var components = URLComponents(
            string: baseURL
        ) else {
            throw URLError(.badURL)
        }

        components.queryItems = [
            URLQueryItem(name: "q", value: query)
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        let (data, response) =
            try await URLSession.shared.data(from: url)

        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode)
        else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(
            ComponentSearchResponse.self,
            from: data
        )

        return decoded.results
    }
}
