import SwiftUI

struct PackingPlanDetailView: View {
    let plan: PackingPlan

    @State private var climate: ClimateSummary?
    @State private var items: [PackingItem] = []
    @State private var isLoading = true

    private static let categoryOrder = ["必需品", "スーツケース・鞄", "移動中に", "観光・街歩き", "宿泊時に", "衣類", "感染症対策"]

    var body: some View {
        List {
            if let climate {
                Section("気候") {
                    HStack {
                        Image(systemName: climateIcon(for: climate.category))
                        Text(climateDescription(for: climate))
                    }
                    if climate.isRainySeason {
                        Text("雨の多い時期です。レインアイテムを忘れずに")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            ForEach(groupedItems, id: \.category) { group in
                Section(group.category) {
                    ForEach(group.items) { item in
                        checklistRow(for: item)
                    }
                }
            }
        }
        .navigationTitle(plan.destinationName)
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isLoading {
                ProgressView("気候を確認中...")
            }
        }
        .task { await load() }
    }

    private var groupedItems: [(category: String, items: [PackingItem])] {
        let grouped = Dictionary(grouping: items, by: \.category)
        return Self.categoryOrder.compactMap { category in
            guard let items = grouped[category] else { return nil }
            return (category, items)
        }
    }

    private func checklistRow(for item: PackingItem) -> some View {
        let isChecked = plan.checkedItemIDs.contains(item.id)
        return Button {
            toggle(item)
        } label: {
            HStack {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isChecked ? .blue : .secondary)
                Text(item.name)
                    .strikethrough(isChecked)
                    .foregroundStyle(isChecked ? .secondary : .primary)
            }
        }
        .buttonStyle(.plain)
    }

    private func toggle(_ item: PackingItem) {
        if let index = plan.checkedItemIDs.firstIndex(of: item.id) {
            plan.checkedItemIDs.remove(at: index)
        } else {
            plan.checkedItemIDs.append(item.id)
        }
    }

    private func load() async {
        let summary = await ClimateService.climateSummary(
            latitude: plan.latitude,
            longitude: plan.longitude,
            startDate: plan.startDate,
            endDate: plan.endDate
        )
        climate = summary
        let days = (Calendar.current.dateComponents([.day], from: plan.startDate, to: plan.endDate).day ?? 0) + 1
        items = PackingListGenerator.generate(climate: summary, tripType: plan.tripType, days: days, isInternational: plan.isInternational)
        isLoading = false
    }

    private func climateIcon(for category: ClimateCategory) -> String {
        switch category {
        case .cold: return "snowflake"
        case .cool: return "wind"
        case .mild: return "cloud.sun"
        case .warm: return "sun.max"
        case .hot: return "thermometer.sun"
        }
    }

    private func climateDescription(for summary: ClimateSummary) -> String {
        if let high = summary.approxHighC, let low = summary.approxLowC {
            return "\(Int(low))〜\(Int(high))℃（予報）"
        }
        switch summary.category {
        case .cold: return "寒い時期です"
        case .cool: return "涼しい時期です"
        case .mild: return "過ごしやすい時期です"
        case .warm: return "暖かい時期です"
        case .hot: return "暑い時期です"
        }
    }
}
