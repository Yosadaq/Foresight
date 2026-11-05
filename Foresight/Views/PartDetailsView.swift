
//
//  PartDetailsView.swift
//  Foresight
//
//  Updated 10/31/26
//

import SwiftUI

struct PartDetailsView: View {

    let part: ManufacturingPart

    // Connect this to your actual Supabase service.
    // Until connected, transaction forms remain unavailable
    // to prevent posting against sample inventory.
    var transactionService:
        (any ManufacturingTransactionService)? = nil

    var voiceAgent:
        (any ManufacturingVoiceFormAgent)? = nil

    @State private var selectedManufacturingAction:
        ManufacturingAction?

    @State private var showServiceAlert = false

    // MARK: - Colors

    private let navy = Color(
        red: 0.06,
        green: 0.10,
        blue: 0.19
    )

    private let green = Color(
        red: 0.17,
        green: 0.61,
        blue: 0.32
    )

    private let blue = Color(
        red: 0.08,
        green: 0.45,
        blue: 0.89
    )

    private let red = Color(
        red: 0.84,
        green: 0.20,
        blue: 0.23
    )

    private let orange = Color(
        red: 0.94,
        green: 0.46,
        blue: 0.12
    )

    // MARK: - Database Relationships

    private var parents: [ManufacturingPart] {
        ManufacturingDatabase.parents(
            of: part.partNumber
        )
    }

    // MARK: - Main View

    var body: some View {

        ScrollView {

            VStack(
                alignment: .leading,
                spacing: 20
            ) {

                partOverview

                stockSection

                actionsSection

                manufacturingSection
            }
            .padding(16)
        }
        .background(
            Color(uiColor: .systemGroupedBackground)
        )
        .navigationTitle("Part Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(
            navy,
            for: .navigationBar
        )
        .toolbarBackground(
            .visible,
            for: .navigationBar
        )
        .toolbarColorScheme(
            .dark,
            for: .navigationBar
        )

        // MARK: Transaction Form Presentation
        
        
        .sheet(item: $selectedManufacturingAction) { action in

            NavigationStack {

                Form {

                    Section("Selected Action") {

                        Text(action.rawValue)
                            .font(.headline)

                        Text(part.partNumber)

                        Text(part.description)
                    }

                    Section("Transaction Details") {

                        Text(
                            "The \(action.rawValue) form opened successfully."
                        )
                    }
                }
                .navigationTitle(action.rawValue)
                .toolbar {

                    ToolbarItem(placement: .topBarTrailing) {

                        Button("Done") {
                            selectedManufacturingAction = nil
                        }
                    }
                }
            }
        }


        .sheet(
            item: $selectedManufacturingAction
        ) { action in

            if let transactionService {

                NavigationStack {

                    ManufacturingTransactionForm(
                        part: part,
                        action: action,
                        service: transactionService,
                        stockQuantity: part.totalStock,
                        voiceAgent: voiceAgent
                    )
                }

            } else {

                NavigationStack {

                    ContentUnavailableView(
                        "Transaction Service Unavailable",
                        systemImage: "externaldrive.badge.exclamationmark",
                        description: Text(
                            "Connect the manufacturing transaction service to Supabase before posting inventory."
                        )
                    )
                    .navigationTitle(
                        action.rawValue
                    )
                    .toolbar {

                        ToolbarItem(
                            placement: .topBarTrailing
                        ) {

                            Button("Done") {
                                selectedManufacturingAction = nil
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Part Overview

    private var partOverview: some View {

        VStack(
            alignment: .leading,
            spacing: 16
        ) {

            HStack(
                alignment: .top,
                spacing: 15
            ) {

                Image(
                    systemName: "shippingbox.fill"
                )
                .font(.system(size: 45))
                .foregroundStyle(navy)
                .frame(
                    width: 90,
                    height: 100
                )
                .background(
                    Color(
                        uiColor: .secondarySystemBackground
                    ),
                    in: RoundedRectangle(
                        cornerRadius: 14
                    )
                )

                VStack(
                    alignment: .leading,
                    spacing: 5
                ) {

                    Text(part.partNumber)
                        .font(.title2.bold())
                        .foregroundStyle(navy)

                    Text(part.name)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(part.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            detailRow(
                "Part Type",
                part.type.rawValue
            )

            detailRow(
                "Material",
                part.material
            )

            detailRow(
                "Revision",
                part.revision
            )

            detailRow(
                "UOM",
                part.unitOfMeasure
            )

            detailRow(
                "Weight",
                String(
                    format: "%.2f lbs",
                    part.weightLbs
                )
            )

            detailRow(
                "Status",
                part.active
                    ? "Active"
                    : "Inactive"
            )
        }
        .padding(18)
        .background(
            .white,
            in: RoundedRectangle(
                cornerRadius: 18
            )
        )
    }

    // MARK: - Stock Quantity

    private var stockSection: some View {

        VStack(
            alignment: .leading,
            spacing: 15
        ) {

            HStack {

                Label(
                    "Stock Quantity",
                    systemImage: "square.stack.3d.up"
                )
                .font(.title3.bold())
                .foregroundStyle(navy)

                Spacer()

                Text("Database")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal) {

                HStack(spacing: 8) {

                    ForEach(part.stock) { balance in

                        stockCell(
                            title: balance.location,
                            quantity: balance.quantity,
                            highlighted: false
                        )
                    }

                    stockCell(
                        title: "Total",
                        quantity: part.totalStock,
                        highlighted: true
                    )
                }
            }
            .scrollIndicators(.hidden)

            Text(
                "Sample inventory — not live ERP stock"
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            if part.totalStock < 0 {

                Label(
                    "Negative inventory balance. Review transactions and perform a verified cycle count.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.footnote)
                .foregroundStyle(.orange)
            }
        }
        .padding(16)
        .background(
            Color(
                uiColor: .secondarySystemGroupedBackground
            ),
            in: RoundedRectangle(
                cornerRadius: 18
            )
        )
    }

    private func stockCell(
        title: String,
        quantity: Int,
        highlighted: Bool
    ) -> some View {

        VStack(spacing: 9) {

            Text(title)
                .font(.caption.bold())

            Text(
                quantity.formatted()
            )
            .font(.title3.bold())
            .foregroundStyle(
                quantity < 0
                    ? Color.red
                    : navy
            )
        }
        .frame(
            width: 100,
            height: 90
        )
        .background(
            highlighted
                ? Color.blue.opacity(0.14)
                : Color.white,
            in: RoundedRectangle(
                cornerRadius: 10
            )
        )
    }

    // MARK: - Manufacturing Actions
    
    private var actionsSection: some View {

        LazyVGrid(
            columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ],
            spacing: 12
        ) {

            actionTile(
                .production,
                subtitle: "Add completed pieces",
                icon: "building.2.fill",
                color: green
            )

            actionTile(
                .transfer,
                subtitle: "Move stock to an area",
                icon: "arrow.left.arrow.right",
                color: blue
            )

            actionTile(
                .scrap,
                subtitle: "Record scrap pieces",
                icon: "trash.fill",
                color: red
            )

            actionTile(
                .manufacturingOrder,
                subtitle: "Manufacturing order",
                icon: "doc.text.fill",
                color: orange
            )
        }
    }


    private func actionTile(
        _ action: ManufacturingAction,
        subtitle: String,
        icon: String,
        color: Color
    ) -> some View {

        Button {
            print("✅ TAPPED: \(action.rawValue)")

            selectedManufacturingAction = action

        } label: {

            VStack(alignment: .leading, spacing: 8) {

                Image(systemName: icon)
                    .font(.title2)

                Spacer(minLength: 6)

                Text(action.rawValue)
                    .font(.subheadline.bold())

                Text(subtitle)
                    .font(.caption)
                    .opacity(0.9)
            }
            .foregroundStyle(.white)
            .frame(
                maxWidth: .infinity,
                minHeight: 100,
                alignment: .leading
            )
            .padding(12)
            .background(
                color,
                in: RoundedRectangle(cornerRadius: 16)
            )
            .contentShape(
                RoundedRectangle(cornerRadius: 16)
            )
        }
        .buttonStyle(.plain)
    }


    private var manufacturingSection: some View {

        VStack(
            alignment: .leading,
            spacing: 16
        ) {

            Text(
                "Manufacturing Details"
            )
            .font(.title3.bold())
            .foregroundStyle(navy)

            detailRow(
                "Scrap Factor",
                String(
                    format: "%.1f%%",
                    part.scrapFactor * 100
                )
            )

            detailRow(
                "Standard Scrap Weight",
                String(
                    format: "%.2f lbs",
                    part.standardScrapWeightLbs
                )
            )

            detailRow(
                "Reorder Point",
                "\(part.reorderPoint) \(part.unitOfMeasure)"
            )

            Divider()

            // MARK: Bill of Materials

            Text(
                "Bill of Materials"
            )
            .font(.headline)

            if part.components.isEmpty {

                Text(
                    "No child components"
                )
                .foregroundStyle(.secondary)

            } else {

                ForEach(
                    part.components
                ) { component in

                    NavigationLink {

                        if let child =
                            ManufacturingDatabase.findPart(
                                number: component.partNumber
                            ) {

                            PartDetailsView(
                                part: child,
                                transactionService: transactionService,
                                voiceAgent: voiceAgent
                            )

                        } else {

                            ContentUnavailableView(
                                "Component Unavailable",
                                systemImage: "shippingbox",
                                description: Text(
                                    "This component was not found in the database."
                                )
                            )
                        }

                    } label: {

                        VStack(
                            alignment: .leading,
                            spacing: 4
                        ) {

                            Text(
                                component.partNumber
                            )
                            .font(
                                .subheadline.bold()
                            )

                            Text(
                                component.description
                            )
                            .font(.caption)

                            Text(
                                "Qty per parent: "
                                + "\(component.quantityPerParent.formatted()) "
                                + component.unitOfMeasure
                            )
                            .font(.caption)
                            .foregroundStyle(
                                .secondary
                            )
                        }
                        .frame(
                            maxWidth: .infinity,
                            alignment: .leading
                        )
                    }
                    .tint(navy)
                }
            }

            Divider()

            // MARK: Parent Assemblies

            Text(
                "Used In"
            )
            .font(.headline)

            if parents.isEmpty {

                Text(
                    "No parent assemblies"
                )
                .foregroundStyle(.secondary)

            } else {

                ForEach(parents) { parent in

                    NavigationLink {

                        PartDetailsView(
                            part: parent,
                            transactionService: transactionService,
                            voiceAgent: voiceAgent
                        )

                    } label: {

                        Text(
                            "\(parent.partNumber) — \(parent.name)"
                        )
                        .font(.subheadline)
                    }
                    .tint(navy)
                }
            }
        }
        .padding(18)
        .background(
            .white,
            in: RoundedRectangle(
                cornerRadius: 18
            )
        )
    }

    // MARK: - Detail Row

    private func detailRow(
        _ title: String,
        _ value: String
    ) -> some View {

        HStack(
            alignment: .top
        ) {

            Text(title)
                .foregroundStyle(
                    .secondary
                )

            Spacer(
                minLength: 12
            )

            Text(value)
                .fontWeight(
                    .medium
                )
                .multilineTextAlignment(
                    .trailing
                )
        }
        .font(.subheadline)
    }
}
