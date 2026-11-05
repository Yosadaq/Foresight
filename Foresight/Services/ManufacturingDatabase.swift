//
//  ManufacturingDatabase.swift
//  Foresight
//
//  Created by Yosadaq Esparza on 10/26/26.
//


import Foundation

struct ManufacturingDatabase {

    static let parts: [ManufacturingPart] = [

        ManufacturingPart(
            partNumber: "P-100245",
            name: "Mounting Bracket",
            description:
                "Steel mounting bracket used for hopper assembly. "
                + "0.125 inch thick, zinc plated.",
            manufacturer: nil,
            type: .fabricated,
            material: "Steel",
            revision: "A",
            unitOfMeasure: "EA",
            weightLbs: 2.35,
            scrapFactor: 0.08,
            standardScrapWeightLbs: 0.20,
            reorderPoint: 100,
            active: true,
            stock: [
                StockBalance(location: "MCD", quantity: 125),
                StockBalance(location: "PRF", quantity: 80),
                StockBalance(location: "AC", quantity: 45),
                StockBalance(location: "RC", quantity: 60),
                StockBalance(location: "TMS", quantity: 22),
                StockBalance(location: "TDC", quantity: 10)
            ],
            components: [
                BOMComponent(
                    partNumber: "RM-00125",
                    description: "Steel Sheet",
                    quantityPerParent: 1.0,
                    unitOfMeasure: "BLANK"
                )
            ]
        ),

        ManufacturingPart(
            partNumber: "RM-00125",
            name: "Steel Sheet",
            description:
                "0.125 inch cold rolled steel sheet for fabrication.",
            manufacturer: nil,
            type: .rawMaterial,
            material: "Cold Rolled Steel",
            revision: "A",
            unitOfMeasure: "SHEET",
            weightLbs: 40.0,
            scrapFactor: 0.05,
            standardScrapWeightLbs: 0,
            reorderPoint: 50,
            active: true,
            stock: [
                StockBalance(location: "MCD", quantity: 180),
                StockBalance(location: "RC", quantity: 40)
            ],
            components: []
        ),

        ManufacturingPart(
            partNumber: "SA-20010",
            name: "Hopper Support Subassembly",
            description:
                "Welded hopper support assembly.",
            manufacturer: nil,
            type: .subassembly,
            material: "Steel",
            revision: "B",
            unitOfMeasure: "EA",
            weightLbs: 12.5,
            scrapFactor: 0.03,
            standardScrapWeightLbs: 0.35,
            reorderPoint: 25,
            active: true,
            stock: [
                StockBalance(location: "MCD", quantity: 34),
                StockBalance(location: "PRF", quantity: 12)
            ],
            components: [
                BOMComponent(
                    partNumber: "P-100245",
                    description: "Mounting Bracket",
                    quantityPerParent: 2,
                    unitOfMeasure: "EA"
                )
            ]
        ),

        ManufacturingPart(
            partNumber: "FG-30001",
            name: "Hopper Assembly",
            description:
                "Finished hopper assembly for production equipment.",
            manufacturer: nil,
            type: .finishedGood,
            material: "Steel Assembly",
            revision: "C",
            unitOfMeasure: "EA",
            weightLbs: 75.0,
            scrapFactor: 0.02,
            standardScrapWeightLbs: 1.5,
            reorderPoint: 10,
            active: true,
            stock: [
                StockBalance(location: "TDC", quantity: 15),
                StockBalance(location: "MCD", quantity: 8)
            ],
            components: [
                BOMComponent(
                    partNumber: "SA-20010",
                    description: "Hopper Support Subassembly",
                    quantityPerParent: 1,
                    unitOfMeasure: "EA"
                )
            ]
        )
    ]

    static func findPart(
        number: String
    ) -> ManufacturingPart? {
        let normalized = number
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        return parts.first {
            $0.partNumber.uppercased() == normalized
        }
    }

    static func matchAnalysis(
        _ analysis: String
    ) -> ManufacturingPart? {
        let text = analysis.uppercased()

        return parts.first {
            text.contains($0.partNumber.uppercased())
        }
    }

    static func parents(
        of partNumber: String
    ) -> [ManufacturingPart] {
        parts.filter { part in
            part.components.contains {
                $0.partNumber.caseInsensitiveCompare(
                    partNumber
                ) == .orderedSame
            }
        }
    }
}
