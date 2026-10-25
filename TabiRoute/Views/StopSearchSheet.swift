import SwiftUI
import MapKit

/// Search sheet for picking a single place for one stop slot (departure,
/// a "want to go" spot, or the destination) in `LocationSearchSheet`.
/// Defaults to a 県→市→観光地 drill-down (inherently Tohoku-only, since
/// `TohokuArea` only lists Tohoku places); keyword search is the fallback
/// for typing a specific name, with live as-you-type suggestions via
/// `PlaceSearchCompleter` (no need to press submit) biased toward a
/// neighboring stop's coordinate when one is already resolved. Since
/// keyword search can resolve to anywhere, selections outside the Tohoku
/// bounding box get a confirm-or-cancel prompt rather than being silently
/// accepted or silently blocked.
struct StopSearchSheet: View {
    var biasCoordinate: CLLocationCoordinate2D?
    var onSelect: (String, CLLocationCoordinate2D) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var completer = PlaceSearchCompleter()
    @State private var query = ""
    @State private var isResolvingSelection = false
    @State private var mode: SearchMode = .area
    @State private var pendingOutOfAreaSelection: (name: String, coordinate: CLLocationCoordinate2D)?

    private enum SearchMode: String, CaseIterable, Identifiable {
        case area = "エリアから探す"
        case keyword = "キーワード検索"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("検索方法", selection: $mode) {
                    ForEach(SearchMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                switch mode {
                case .keyword:
                    keywordSearchView
                case .area:
                    PrefectureListView(onSelect: onSelect)
                }
            }
            .navigationTitle("場所を検索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .overlay {
                if isResolvingSelection {
                    ProgressView()
                }
            }
            .alert(
                "東北地方の外のようです",
                isPresented: Binding(get: { pendingOutOfAreaSelection != nil }, set: { if !$0 { pendingOutOfAreaSelection = nil } })
            ) {
                Button("キャンセル", role: .cancel) {}
                Button("追加する") {
                    if let pendingOutOfAreaSelection {
                        onSelect(pendingOutOfAreaSelection.name, pendingOutOfAreaSelection.coordinate)
                        dismiss()
                    }
                }
            } message: {
                Text("「\(pendingOutOfAreaSelection?.name ?? "")」は東北6県の範囲外の場所のようです。それでも追加しますか？")
            }
        }
        .onAppear {
            if let biasCoordinate {
                completer.setRegion(MKCoordinateRegion(center: biasCoordinate, span: MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)))
            }
        }
    }

    private var keywordSearchView: some View {
        List {
            Section {
                ForEach(completer.suggestions, id: \.self) { suggestion in
                    Button {
                        Task { await resolve(suggestion) }
                    } label: {
                        VStack(alignment: .leading) {
                            Text(suggestion.title).foregroundStyle(.primary)
                            if !suggestion.subtitle.isEmpty {
                                Text(suggestion.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .overlay {
            if completer.suggestions.isEmpty && !query.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "場所を検索")
        .onChange(of: query) { _, newValue in
            completer.update(queryFragment: newValue)
        }
    }

    private func resolve(_ suggestion: MKLocalSearchCompletion) async {
        isResolvingSelection = true
        let request = MKLocalSearch.Request(completion: suggestion)
        if let response = try? await MKLocalSearch(request: request).start(), let item = response.mapItems.first {
            let coordinate = item.placemark.coordinate
            if TohokuArea.contains(coordinate) {
                onSelect(suggestion.title, coordinate)
                dismiss()
            } else {
                pendingOutOfAreaSelection = (suggestion.title, coordinate)
            }
        }
        isResolvingSelection = false
    }
}
