//
//  Manufacturing.swift
//  Foresight
//
//  Created by Yosadaq Esparza on 10/26/26.
//


import Foundation

enum PartType: String, Codable, CaseIterable {
    case rawMaterial = "Raw Material"
    case fabricated = "Fabricated"
    case purchased = "Purchased"
    case subassembly = "Subassembly"
    case finishedGood = "Finished Good"
}

struct StockBalance: Identifiable, Codable {
    let location: String
    var quantity: Int

    var id: String { location }
}

struct BOMComponent: Identifiable, Codable {
    let partNumber: String
    let description: String
    let quantityPerParent: Double
    let unitOfMeasure: String

    var id: String { partNumber }
}

struct ManufacturingPart: Identifiable, Codable {
    let partNumber: String
    let name: String
    let description: String
    let manufacturer: String?
    let type: PartType
    let material: String
    let revision: String
    let unitOfMeasure: String
    let weightLbs: Double
    let scrapFactor: Double
    let standardScrapWeightLbs: Double
    let reorderPoint: Int
    let active: Bool
    let stock: [StockBalance]
    let components: [BOMComponent]

    var id: String { partNumber }

    var totalStock: Int {
        stock.reduce(0) { $0 + $1.quantity }
    }
}
