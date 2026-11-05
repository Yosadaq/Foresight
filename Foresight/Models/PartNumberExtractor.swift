//
//  PartNumberExtractor.swift
//  Foresight
//
//  Created by Yosadaq Esparza on 10/27/26.
//

import Foundation

enum PartNumberExtractor {

    static func extract(from analysis: String) -> String? {

        let pattern =
            #"(?im)^\s*(?:[-*]\s*)?(?:\*\*)?(?:manufacturer\s+)?part\s*(?:number|no\.?|#)(?:\*\*)?\s*[:\-]\s*(?:\*\*)?\s*`?([A-Z0-9][A-Z0-9._/-]{2,59})"#

        guard let regex = try? NSRegularExpression(
            pattern: pattern
        ) else {
            return nil
        }

        let range = NSRange(
            analysis.startIndex..<analysis.endIndex,
            in: analysis
        )

        guard let match = regex.firstMatch(
            in: analysis,
            range: range
        ),
        let partRange = Range(
            match.range(at: 1),
            in: analysis
        ) else {
            return nil
        }

        let extracted = String(analysis[partRange])
            .trimmingCharacters(
                in: CharacterSet(charactersIn: ".,;:")
            )
            .uppercased()

        return extracted.isEmpty ? nil : extracted
    }
}
