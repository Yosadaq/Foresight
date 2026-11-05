
import SwiftUI

struct CycleCountTask: Decodable, Identifiable {

    let taskID: UUID
    let partNumber: String
    let locationID: String
    let erpQuantity: Double
    let countVariance: Double?
    let priorityRank: Int?
    let status: String
    let assignedTo: String?

    var id: UUID { taskID }

    enum CodingKeys: String, CodingKey {
        case taskID = "task_id"
        case partNumber = "part_number"
        case locationID = "location_id"
        case erpQuantity = "erp_quantity"
        case countVariance = "count_variance"
        case priorityRank = "priority_rank"
        case status
        case assignedTo = "assigned_to"
    }
}

struct CycleCountQueueResponse: Decodable {
    let success: Bool
    let snapshotID: UUID?
    let importedAt: Date?
    let tasks: [CycleCountTask]
}

struct CycleCountQueueView: View {

    @State private var tasks: [CycleCountTask] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var selectedPartNumber: String?

    private let repository = VercelRCARepository()

    var body: some View {

        List {

            Section {
                Label(
                    "Highest negative balances first",
                    systemImage: "arrow.down"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            ForEach(tasks) { task in

                Button {

                    selectedPartNumber = task.partNumber

                } label: {

                    VStack(
                        alignment: .leading,
                        spacing: 8
                    ) {

                        HStack {

                            Text(
                                "#\(task.priorityRank ?? 0)"
                            )
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)

                            Spacer()

                            Text(task.status.capitalized)
                                .font(.caption)
                        }

                        Text(task.partNumber)
                            .font(.headline)

                        HStack {

                            Label(
                                task.locationID,
                                systemImage: "mappin"
                            )

                            Spacer()

                            Text(
                                task.erpQuantity.formatted()
                            )
                            .font(.headline)
                            .foregroundStyle(
                                task.erpQuantity < 0
                                ? Color.red
                                : Color.primary
                            )
                        }
                        .font(.subheadline)
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }

            if tasks.isEmpty && !isLoading {

                ContentUnavailableView(
                    "No Cycle Counts",
                    systemImage: "checklist",
                    description: Text(
                        errorMessage
                        ?? "No tasks are currently available."
                    )
                )
            }
        }
        .navigationTitle("Cycle Count Queue")
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
        .refreshable {
            await loadTasks()
        }
        .task {
            await loadTasks()
        }
        .navigationDestination(
            item: $selectedPartNumber
        ) { partNumber in

            InventoryRCAGuideView(
                partNumber: partNumber,
                database: repository
            )
        }
    }

    @MainActor
    private func loadTasks() async {

        guard let url = URL(
            string:
                "https://foresight-omega.vercel.app/api/rca/queue"
        ) else {
            return
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {

            let (data, response) =
                try await URLSession.shared.data(
                    from: url
                )

            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode)
            else {
                throw URLError(.badServerResponse)
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let result = try decoder.decode(
                CycleCountQueueResponse.self,
                from: data
            )

            tasks = result.tasks

        } catch {

            errorMessage = error.localizedDescription
        }
    }
}
