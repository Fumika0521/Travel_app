import SwiftUI
import SwiftData

struct PackingPlanListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PackingPlan.createdAt, order: .reverse) private var plans: [PackingPlan]
    @State private var isShowingNewPlan = false

    var body: some View {
        List {
            ForEach(plans) { plan in
                NavigationLink {
                    PackingPlanDetailView(plan: plan)
                } label: {
                    VStack(alignment: .leading) {
                        Text(plan.destinationName).font(.headline)
                        Text("\(plan.startDate.formatted(date: .abbreviated, time: .omitted)) 〜 \(plan.endDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete(perform: deletePlans)
        }
        .overlay {
            if plans.isEmpty {
                ContentUnavailableView(
                    "持ち物リストがありません",
                    systemImage: "bag",
                    description: Text("右上の＋から旅行の持ち物リストを作成しましょう")
                )
            }
        }
        .navigationTitle("持ち物リスト")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingNewPlan = true
                } label: {
                    Label("新規作成", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isShowingNewPlan) {
            NewPackingPlanView()
        }
    }

    private func deletePlans(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(plans[index])
        }
    }
}
