import SwiftUI
import VisionKit

struct DocumentScanner: UIViewControllerRepresentable {
    var completion: (Result<[Data], Error>) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScanner
        init(parent: DocumentScanner) { self.parent = parent }
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) { parent.dismiss() }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            parent.dismiss()
            parent.completion(.failure(error))
        }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            guard scan.pageCount <= 12 else {
                parent.dismiss()
                parent.completion(.failure(StudyError.invalid(String(localized: "Scan at most 12 pages per lesson."))))
                return
            }
            let pages = (0..<scan.pageCount).compactMap { scan.imageOfPage(at: $0).jpegData(compressionQuality: 0.85) }
            parent.dismiss()
            guard pages.count == scan.pageCount else {
                parent.completion(.failure(StudyError.invalid(String(localized: "A page image couldn't be read. Scan it again."))))
                return
            }
            parent.completion(.success(pages))
        }
    }
}
