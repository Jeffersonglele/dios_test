import Flutter
import UIKit

@available(iOS 17.0, *)
final class NavBarFactory: NSObject, FlutterPlatformViewFactory {
    private let channel: FlutterMethodChannel

    init(channel: FlutterMethodChannel) {
        self.channel = channel
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        let params = args as? [String: Any]
        let currentIndex = params?["currentIndex"] as? Int ?? 0
        let rawItems = params?["items"] as? [[String: Any]] ?? []
        let items = rawItems.enumerated().map { position, raw in
            NavItem(
                id: raw["index"] as? Int ?? position,
                icon: raw["icon"] as? String ?? "circle.fill",
                label: raw["label"] as? String ?? ""
            )
        }

        return NavBarPlatformView(
            frame: frame,
            channel: channel,
            currentIndex: currentIndex,
            items: items
        )
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }
}
