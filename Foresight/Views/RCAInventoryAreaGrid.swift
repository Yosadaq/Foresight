
//
// RCAInventoryAreaGrid.swift
// Foresight
//
// Two-column ERP inventory display
//

import SwiftUI

struct RCAInventoryLocation: Codable, Identifiable {

    let location: String
    let quantity: Double

    var id: String { location }
}

struct RCAInventoryAreaGrid: View {

    let locations: [RCAInventoryLocation]
    let totalBalance: Double?

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    private var sortedLocations: [RCAInventoryLocation] {

        locations.sorted { left, right in

            if left.quantity != right.quantity {
                return left.quantity < right.quantity
            }

            return left.location < right.location
        }
    }

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 14
        ) {

            Label(
                "Inventory by Area",
                systemImage: "square.grid.2x2.fill"
            )
            .font(.headline)
            .foregroundStyle(.primary)

            if sortedLocations.isEmpty {

                Text("No area balances were returned.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

            } else {

                LazyVGrid(
                    columns: columns,
                    spacing: 10
                ) {

                    ForEach(sortedLocations) { item in

                        VStack(
                            alignment: .leading,
                            spacing: 8
                        ) {

                            HStack {

                                Image(
                                    systemName: "mappin.circle.fill"
                                )
                                .foregroundStyle(.indigo)

                                Text(item.location)
                                    .font(.subheadline.bold())
                                    .lineLimit(1)

                                Spacer(minLength: 0)
                            }

                            Text(item.quantity.formatted(
                                .number.precision(
                                    .fractionLength(0...4)
                                )
                            ))
                            .font(.system(
                                size: 25,
                                weight: .bold,
                                design: .rounded
                            ))
                            .monospacedDigit()
                            .foregroundStyle(
                                item.quantity < 0
                                ? Color.red
                                : Color.primary
                            )

                            Text("ERP balance")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(13)
                        .frame(
                            maxWidth: .infinity,
                            minHeight: 106,
                            alignment: .leading
                        )
                        .background(
                            Color(
                                uiColor:
                                    .secondarySystemGroupedBackground
                            ),
                            in: RoundedRectangle(
                                cornerRadius: 14
                            )
                        )
                    }
                }
            }

            if let totalBalance {

                Divider()

                HStack {

                    Text("Total ERP Balance")
                        .font(.subheadline.bold())

                    Spacer()

                    Text(
                        totalBalance.formatted(
                            .number.precision(
                                .fractionLength(0...4)
                            )
                        )
                    )
                    .font(.title3.bold())
                    .monospacedDigit()
                    .foregroundStyle(
                        totalBalance < 0
                        ? Color.red
                        : Color.primary
                    )
                }
            }
        }
        .foregroundStyle(.primary)
    }
}
