import Foundation
import Capacitor
import UIKit

@objc(LiquidGlassPlugin)
public class LiquidGlassPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "LiquidGlassPlugin"
    public let jsName = "LiquidGlass"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "showTabBar", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "hideTabBar", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setSelectedTab", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "updateTabBadge", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getTabBarLayout", returnType: CAPPluginReturnPromise),
    ]

    private var tabBarOverlay: LiquidGlassTabBarOverlay?

    @objc func showTabBar(_ call: CAPPluginCall) {
        guard let rawItems = call.getArray("items") as? [[String: Any]] else {
            call.reject("items is required")
            return
        }
        let selectedIndex = call.getInt("selectedIndex") ?? 0
        let tintHex = call.getString("tintColor")

        let items = rawItems.compactMap { LiquidGlassTabItem(dictionary: $0) }
        guard !items.isEmpty else {
            call.reject("items cannot be empty")
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.presentTabBar(items: items, selectedIndex: selectedIndex, tintHex: tintHex)
            call.resolve()
        }
    }

    @objc func hideTabBar(_ call: CAPPluginCall) {
        DispatchQueue.main.async { [weak self] in
            self?.tabBarOverlay?.hide()
            call.resolve()
        }
    }

    @objc func updateTabBadge(_ call: CAPPluginCall) {
        guard let id = call.getString("id") else {
            call.reject("id is required")
            return
        }
        let badge = call.getString("badge")

        DispatchQueue.main.async { [weak self] in
            self?.tabBarOverlay?.updateBadge(id: id, badge: badge)
            call.resolve()
        }
    }

    @objc func setSelectedTab(_ call: CAPPluginCall) {
        let index = call.getInt("index")
        let id = call.getString("id")

        DispatchQueue.main.async { [weak self] in
            guard let overlay = self?.tabBarOverlay else {
                call.reject("tab bar is not shown")
                return
            }
            if let index {
                overlay.setSelectedIndex(index)
            } else if let id {
                overlay.setSelected(id: id)
            }
            call.resolve()
        }
    }

    @objc func getTabBarLayout(_ call: CAPPluginCall) {
        DispatchQueue.main.async { [weak self] in
            let layout = self?.tabBarOverlay?.currentLayout() ?? (height: 0.0, bottomSafeArea: 0.0)
            call.resolve([
                "height": layout.height,
                "bottomSafeArea": layout.bottomSafeArea,
            ])
        }
    }

    private func presentTabBar(items: [LiquidGlassTabItem], selectedIndex: Int, tintHex: String?) {
        guard let window = UIApplication.shared.capacitorWindow else { return }

        if tabBarOverlay == nil {
            let overlay = LiquidGlassTabBarOverlay()
            overlay.onTabSelected = { [weak self] index, id in
                self?.notifyListeners("tabSelected", data: ["index": index, "id": id])
            }
            overlay.onLayoutChanged = { [weak self] height, bottomSafeArea in
                self?.notifyListeners("tabBarLayoutChanged", data: [
                    "height": height,
                    "bottomSafeArea": bottomSafeArea,
                ])
            }
            tabBarOverlay = overlay
        }

        tabBarOverlay?.attach(to: window)
        tabBarOverlay?.configure(items: items, selectedIndex: selectedIndex, tintHex: tintHex)
        tabBarOverlay?.show()
    }
}

// MARK: - UIApplication helper
private extension UIApplication {
    var capacitorWindow: UIWindow? {
        return connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ??
            connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first
    }
}
