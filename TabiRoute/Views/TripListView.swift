import SwiftUI
import SwiftData

struct TripListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Trip.createdAt, order: .reverse) private var trips: [Trip]
    @State private var isShowingPicker = false
    @State private var isShowingLocationSearch = false
    @State private var renamingTrip: Trip?
    @State private var editedTripName = ""
    @State private var tripPendingDeletion: Trip?

    var body: some View {
        List {
            ForEach(trips) { trip in
                NavigationLink {
                    TripMapView(trip: trip)
                } label: {
                    VStack(alignment: .leading) {
                        Text(trip.name).font(.headline)
                        Text(trip.createdAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .contextMenu {
                    Button {
                        editedTripName = trip.name
                        renamingTrip = trip
                    } label: {
                        Label("名前を変更", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        tripPendingDeletion = trip
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                }
            }
            .onDelete(perform: deleteTrips)
        }
        .overlay {
            if trips.isEmpty {
                ContentUnavailableView(
                    "まだトリップがありません",
                    systemImage: "map",
                    description: Text("右上の＋から写真を選んでルート地図を作成しましょう")
                )
            }
        }
        .navigationTitle("マイトリップ")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        isShowingLocationSearch = true
                    } label: {
                        Label("検索して作成", systemImage: "magnifyingglass")
                    }
                    Button {
                        isShowingPicker = true
                    } label: {
                        Label("写真から作成", systemImage: "photo.on.rectangle")
                    }
                } label: {
                    Label("新規トリップ", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isShowingPicker) {
            PhotoPickerSheet { identifiers in
                guard !identifiers.isEmpty else { return }
                let trip = Trip(name: defaultTripName(), assetIdentifiers: identifiers)
                modelContext.insert(trip)
            }
        }
        .sheet(isPresented: $isShowingLocationSearch) {
            LocationSearchSheet { waypoints in
                guard !waypoints.isEmpty else { return }
                let trip = Trip(name: defaultTripName(), assetIdentifiers: [])
                trip.manualWaypoints = waypoints
                modelContext.insert(trip)
            }
        }
        .alert("トリップ名を変更", isPresented: Binding(get: { renamingTrip != nil }, set: { if !$0 { renamingTrip = nil } })) {
            TextField("トリップ名", text: $editedTripName)
            Button("キャンセル", role: .cancel) {}
            Button("保存") {
                let trimmed = editedTripName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                renamingTrip?.name = trimmed
            }
        }
        .alert(
            "「\(tripPendingDeletion?.name ?? "")」を削除しますか？",
            isPresented: Binding(get: { tripPendingDeletion != nil }, set: { if !$0 { tripPendingDeletion = nil } })
        ) {
            Button("キャンセル", role: .cancel) {}
            Button("削除", role: .destructive) {
                if let tripPendingDeletion {
                    modelContext.delete(tripPendingDeletion)
                }
            }
        } message: {
            Text("この操作は取り消せません")
        }
    }

    private func defaultTripName() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日の旅"
        return formatter.string(from: .now)
    }

    private func deleteTrips(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(trips[index])
        }
    }
}
