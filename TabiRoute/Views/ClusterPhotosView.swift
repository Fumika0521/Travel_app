import SwiftUI
import CoreLocation
import RouteClusteringKit

/// Shown when a map marker is tapped — the place name and thumbnails of
/// the photos that were clustered into that marker.
struct ClusterPhotosView: View {
    let cluster: RouteCluster
    let onDismiss: () -> Void

    @State private var thumbnails: [String: UIImage] = [:]
    @State private var placeName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if let placeName {
                        Text(placeName)
                            .font(.footnote.bold())
                    }
                    Text(cluster.photoCount > 1 ? "\(cluster.photoCount)枚の写真" : "写真")
                        .font(.caption)
                        .foregroundStyle(placeName == nil ? .primary : .secondary)
                }
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(cluster.memberIDs, id: \.self) { assetIdentifier in
                        thumbnailView(for: assetIdentifier)
                    }
                }
            }
        }
        .padding(8)
        .background(.thinMaterial)
        .task(id: cluster.id) {
            placeName = nil
            async let thumbnailsLoad: Void = loadThumbnails()
            async let placeNameLoad = PlacemarkService.placeName(for: cluster.coordinate)
            placeName = await placeNameLoad
            await thumbnailsLoad
        }
    }

    @ViewBuilder
    private func thumbnailView(for assetIdentifier: String) -> some View {
        if let image = thumbnails[assetIdentifier] {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(.secondary.opacity(0.2))
                .frame(width: 72, height: 72)
                .overlay { ProgressView() }
        }
    }

    private func loadThumbnails() async {
        for assetIdentifier in cluster.memberIDs where thumbnails[assetIdentifier] == nil {
            if let image = await PhotoLibraryService.thumbnail(for: assetIdentifier) {
                thumbnails[assetIdentifier] = image
            }
        }
    }
}
