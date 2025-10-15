import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}

@MainActor
func exportAndShareProtocol(for survey: Survey, meta: FieldMeta? = nil, presenter: UIViewController) {
    do {
        let url = try survey.exportProtocolCSV(meta: meta)
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        presenter.present(controller, animated: true)
    } catch {
        print("Export fehlgeschlagen: \(error)")
    }
}
