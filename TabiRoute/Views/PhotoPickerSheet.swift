import SwiftUI
import PhotosUI

/// Presents the system photo picker. No Photos permission is required just
/// to show this and read back `assetIdentifier`s — permission is only
/// requested later, when resolving those identifiers to `PHAsset.location`.
struct PhotoPickerSheet: UIViewControllerRepresentable {
    var onSelection: ([String]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 0
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelection: onSelection)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onSelection: ([String]) -> Void

        init(onSelection: @escaping ([String]) -> Void) {
            self.onSelection = onSelection
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            let identifiers = results.compactMap(\.assetIdentifier)
            picker.dismiss(animated: true)
            onSelection(identifiers)
        }
    }
}
