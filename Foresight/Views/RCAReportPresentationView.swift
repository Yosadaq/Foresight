
//
// RCAReportPresentationView.swift
// Foresight
//

import SwiftUI
import MessageUI

struct RCAReportPresentationView: View {

    let saved: SavedVoiceRCA

    @State private var showMailComposer = false

    private var report: RCAAIReport {
        saved.report
    }

    private var emailSubject: String {
        report.managementEmailSubject
        ?? "Inventory Investigation — Part \(saved.partNumber)"
    }

    private var emailBody: String {
        if let body = report.managementEmailBody,
           !body.isEmpty {
            return body
        }

        return """
        Hello,

        Please review the following inventory investigation.

        Part: \(saved.partNumber)

        Investigation Summary:
        \(report.summary)

        Possible Root Causes:
        \(report.possibleCauses)

        Recommended Corrective Actions:
        \(report.correctiveAction)

        Outstanding Verification:
        \(report.nextVerification)

        Preventive Actions:
        \(report.preventiveAction)

        Please review these recommendations before any inventory or engineering changes are approved.

        Thank you.
        """
    }

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 18
        ) {

            header

            Divider()
            
            
            RCAInventoryAreaGrid(
                locations: saved.inventoryLocations ?? [],
                totalBalance: saved.erpTotalBalance
            )

            Divider()

            reportSection(
                "Investigation Summary",
                icon: "doc.text",
                content: report.summary
            )

            if let count = report.countSummary,
               !count.isEmpty {

                reportSection(
                    "Inventory & Physical Count",
                    icon: "number.square",
                    content: count
                )
            }

            if let completed = report.completedChecks,
               !completed.isEmpty {

                bulletSection(
                    "What Was Checked",
                    icon: "checkmark.circle",
                    content: completed
                )
            }

            if let outstanding = report.outstandingChecks,
               !outstanding.isEmpty {

                bulletSection(
                    "What Still Needs Verification",
                    icon: "clock",
                    content: outstanding
                )
            }

            bulletSection(
                "Possible Root Causes",
                icon: "magnifyingglass",
                content: report.possibleCauses
            )

            bulletSection(
                "Corrective Action Plan",
                icon: "wrench.and.screwdriver",
                content: report.correctiveAction
            )

            bulletSection(
                "Preventive Measures",
                icon: "shield.checkered",
                content: report.preventiveAction
            )

            reportSection(
                "Follow-Up Verification",
                icon: "checkmark.seal",
                content: report.effectivenessCheck
            )

            Divider()

            emailActions

            Label(
                "Recommendations require supervisor or engineering review before implementation.",
                systemImage: "info.circle"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        
        
        .padding(18)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .background(
            Color.white,
            in: RoundedRectangle(
                cornerRadius: 20
            )
        )

        // FIX: Always render the white report card
        // using light-mode text and controls.
        .environment(\.colorScheme, .light)

        // Explicitly define the main foreground color.
        .foregroundStyle(
            Color(
                red: 0.08,
                green: 0.12,
                blue: 0.21
            )
        )

        .sheet(isPresented: $showMailComposer) {

            ManagementMailComposer(
                subject: emailSubject,
                body: emailBody
            )
        }
    }

    // MARK: - Report Header

    private var header: some View {

        VStack(
            alignment: .leading,
            spacing: 10
        ) {

            Label(
                "Manufacturing Investigation Report",
                systemImage: "doc.text.fill"
            )
            .font(.title2.bold())
            .foregroundStyle(
                Color(
                    red: 0.08,
                    green: 0.12,
                    blue: 0.21
                )
            )

            if let name = saved.partName,
               !name.isEmpty {

                Text(name)
                    .font(.headline)
                    .foregroundStyle(.black)
            }

            Text("Part #\(saved.partNumber)")
                .font(.subheadline)
                .foregroundStyle(
                    Color(
                        red: 0.35,
                        green: 0.39,
                        blue: 0.47
                    )
                )

            Text(
                saved.createdAt.formatted(
                    date: .abbreviated,
                    time: .shortened
                )
            )
            .font(.caption)
            .foregroundStyle(.gray)
        }
    }

    // MARK: - Text Section

    private func reportSection(
        _ title: String,
        icon: String,
        content: String
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 9
        ) {

            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(
                    Color(
                        red: 0.08,
                        green: 0.12,
                        blue: 0.21
                    )
                )

            Text(content)
                .font(.subheadline)
                .foregroundStyle(
                    Color(
                        red: 0.20,
                        green: 0.25,
                        blue: 0.33
                    )
                )
                .lineSpacing(4)
                .textSelection(.enabled)
        }
    }

    // MARK: - Bullet Section

    private func bulletSection(
        _ title: String,
        icon: String,
        content: String
    ) -> some View {

        let lines = content
            .components(separatedBy: .newlines)
            .map {
                $0.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            .filter { !$0.isEmpty }

        return VStack(
            alignment: .leading,
            spacing: 11
        ) {

            Label(title, systemImage: icon)
                .font(.headline)

            ForEach(
                Array(lines.enumerated()),
                id: \.offset
            ) { _, line in

                HStack(
                    alignment: .top,
                    spacing: 10
                ) {

                    Circle()
                        .fill(Color.indigo)
                        .frame(
                            width: 6,
                            height: 6
                        )
                        .padding(.top, 7)

                    Text(cleanBullet(line))
                        .font(.subheadline)
                        .foregroundStyle(
                            Color(
                                red: 0.20,
                                green: 0.25,
                                blue: 0.33
                            )
                        )
                        .lineSpacing(3)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private func cleanBullet(
        _ value: String
    ) -> String {

        var text = value

        text = text.replacingOccurrences(
            of: #"^\s*(?:[-*•]|\d+[.)])\s*"#,
            with: "",
            options: .regularExpression
        )

        return text
    }

    // MARK: - Email

    private var emailActions: some View {

        VStack(spacing: 12) {

            if MFMailComposeViewController.canSendMail() {

                Button {

                    showMailComposer = true

                } label: {

                    Label(
                        "Email Management",
                        systemImage: "envelope.fill"
                    )
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(15)
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
            }

            ShareLink(
                item: emailBody,
                subject: Text(emailSubject),
                message: Text(
                    "Foresight inventory investigation"
                )
            ) {

                Label(
                    "Share or Copy Management Summary",
                    systemImage: "square.and.arrow.up"
                )
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(12)
            }
            .buttonStyle(.bordered)
        }
    }
}

// MARK: - Native Mail Composer

struct ManagementMailComposer:
    UIViewControllerRepresentable {

    let subject: String
    let body: String

    @Environment(\.dismiss)
    private var dismiss

    func makeUIViewController(
        context: Context
    ) -> MFMailComposeViewController {

        let composer =
            MFMailComposeViewController()

        composer.mailComposeDelegate =
            context.coordinator

        composer.setSubject(subject)

        composer.setMessageBody(
            body,
            isHTML: false
        )

        return composer
    }

    func updateUIViewController(
        _ controller: MFMailComposeViewController,
        context: Context
    ) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator:
        NSObject,
        MFMailComposeViewControllerDelegate {

        let parent: ManagementMailComposer

        init(_ parent: ManagementMailComposer) {
            self.parent = parent
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result:
                MFMailComposeResult,
            error: Error?
        ) {
            parent.dismiss()
        }
    }
}
