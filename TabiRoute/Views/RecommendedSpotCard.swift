import SwiftUI
import MapKit

/// Shown when a recommended (orange star) marker is tapped. Tries to show
/// Apple's own Look Around street-level imagery for the spot — free, no
/// API key — since MapKit search results don't come with a photo. Look
/// Around coverage isn't universal, so this falls back to just the name
/// when no scene is available for that coordinate.
struct RecommendedSpotCard: View {
    let spot: RecommendedSpot
    let onDismiss: () -> Void

    @State private var scene: MKLookAroundScene?
    @State private var isLoadingScene = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(spot.name).font(.footnote.bold())
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }

            if let scene {
                LookAroundPreview(initialScene: scene)
                    .frame(height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if isLoadingScene {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.secondary.opacity(0.15))
                    .frame(height: 140)
                    .overlay { ProgressView() }
            }
        }
        .padding(8)
        .background(.thinMaterial)
        .task(id: spot.id) {
            await loadScene()
        }
    }

    private func loadScene() async {
        isLoadingScene = true
        let request = MKLookAroundSceneRequest(coordinate: spot.coordinate)
        scene = try? await request.scene
        isLoadingScene = false
    }
}
