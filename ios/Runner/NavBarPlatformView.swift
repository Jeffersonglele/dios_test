import Flutter
import SwiftUI
import UIKit

@available(iOS 17.0, *)
final class NavBarState: ObservableObject {
    @Published var currentIndex: Int
    let items: [NavItem]

    init(currentIndex: Int, items: [NavItem]) {
        self.currentIndex = currentIndex
        self.items = items
    }
}

@available(iOS 17.0, *)
struct LiquidGlassNavBarWrapper: View {
    @ObservedObject var navState: NavBarState
    let channel: FlutterMethodChannel

    var body: some View {
        LiquidGlassNavBar(
            items: navState.items,
            currentIndex: $navState.currentIndex,
            onTap: { index in
                channel.invokeMethod("selectIndex", arguments: index)
            }
        )
    }
}

@available(iOS 17.0, *)
final class NavBarPlatformView: NSObject, FlutterPlatformView {
    private let hostingController: UIHostingController<AnyView>
    private let navState: NavBarState

    init(
        frame: CGRect,
        channel: FlutterMethodChannel,
        currentIndex: Int,
        items: [NavItem]
    ) {
        navState = NavBarState(currentIndex: currentIndex, items: items)
        let wrapper = LiquidGlassNavBarWrapper(navState: navState, channel: channel)
        hostingController = UIHostingController(rootView: AnyView(wrapper))
        super.init()

        hostingController.view.backgroundColor = .clear
        hostingController.view.frame = frame

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUpdateIndex(_:)),
            name: NSNotification.Name("UpdateNavBarIndex"),
            object: nil
        )
    }

    @objc private func handleUpdateIndex(_ notification: Notification) {
        guard let index = notification.userInfo?["index"] as? Int else { return }
        navState.currentIndex = index
    }

    func view() -> UIView {
        hostingController.view
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
