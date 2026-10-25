import SwiftUI
import MapKit

/// Google Maps-style multi-stop builder: a fixed 出発地 (departure) and
/// 目的地 (destination) slot with any number of 行きたい場所 (want-to-go)
/// stops insertable between them. Each slot is resolved individually via
/// `StopSearchSheet`; the result is an ordered `[ManualWaypoint]` so the
/// resulting map shows the planned route in the order the user built it.
struct LocationSearchSheet: View {
    var onSelection: ([ManualWaypoint]) -> Void

    @Environment(\.dismiss) private var dismiss

    private struct Stop: Identifiable {
        let id = UUID()
        var name: String?
        var coordinate: CLLocationCoordinate2D?
    }

    @State private var stops: [Stop] = [Stop(), Stop()]
    @State private var activeStopIndex: Int?

    private var isActiveSheetPresented: Binding<Bool> {
        Binding(get: { activeStopIndex != nil }, set: { if !$0 { activeStopIndex = nil } })
    }

    private var canCreate: Bool {
        stops.allSatisfy { $0.coordinate != nil }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(stops.indices, id: \.self) { index in
                        stopRow(for: index)
                            .swipeActions {
                                if index != 0 && index != stops.count - 1 {
                                    Button(role: .destructive) {
                                        stops.remove(at: index)
                                    } label: {
                                        Label("削除", systemImage: "trash")
                                    }
                                }
                            }
                    }
                }

                Section {
                    Button {
                        stops.insert(Stop(), at: stops.count - 1)
                    } label: {
                        Label("行きたい場所を追加", systemImage: "plus.circle")
                    }
                }
            }
            .navigationTitle("ルートを検索して作成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("作成") {
                        let waypoints = stops.compactMap { stop -> ManualWaypoint? in
                            guard let name = stop.name, let coordinate = stop.coordinate else { return nil }
                            return ManualWaypoint(name: name, latitude: coordinate.latitude, longitude: coordinate.longitude)
                        }
                        onSelection(waypoints)
                        dismiss()
                    }
                    .disabled(!canCreate)
                }
            }
            .sheet(isPresented: isActiveSheetPresented) {
                if let activeStopIndex {
                    StopSearchSheet(biasCoordinate: biasCoordinate(for: activeStopIndex)) { name, coordinate in
                        stops[activeStopIndex].name = name
                        stops[activeStopIndex].coordinate = coordinate
                    }
                }
            }
        }
    }

    private func stopRow(for index: Int) -> some View {
        Button {
            activeStopIndex = index
        } label: {
            HStack {
                Image(systemName: iconName(for: index))
                    .foregroundStyle(iconColor(for: index))
                VStack(alignment: .leading, spacing: 2) {
                    Text(label(for: index))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(stops[index].name ?? "タップして検索")
                        .foregroundStyle(stops[index].name == nil ? .secondary : .primary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func label(for index: Int) -> String {
        if index == 0 { return "出発地" }
        if index == stops.count - 1 { return "目的地" }
        return "行きたい場所"
    }

    private func iconName(for index: Int) -> String {
        if index == 0 { return "figure.walk" }
        if index == stops.count - 1 { return "flag.checkered" }
        return "mappin"
    }

    private func iconColor(for index: Int) -> Color {
        if index == 0 { return .green }
        if index == stops.count - 1 { return .purple }
        return .blue
    }

    /// Biases search toward whichever neighboring stop is already
    /// resolved, closest index first, so results stay geographically
    /// relevant even before every stop is filled in.
    private func biasCoordinate(for index: Int) -> CLLocationCoordinate2D? {
        for offset in 1..<stops.count {
            if index - offset >= 0, let coordinate = stops[index - offset].coordinate {
                return coordinate
            }
            if index + offset < stops.count, let coordinate = stops[index + offset].coordinate {
                return coordinate
            }
        }
        return nil
    }
}
