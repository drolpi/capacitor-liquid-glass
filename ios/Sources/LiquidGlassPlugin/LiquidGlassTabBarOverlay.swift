import UIKit

struct LiquidGlassTabItem {
    let id: String
    let label: String
    let sfSymbol: String
    let badge: String?

    init?(dictionary: [String: Any]) {
        guard
            let id = dictionary["id"] as? String,
            let label = dictionary["label"] as? String,
            let sfSymbol = dictionary["sfSymbol"] as? String
        else {
            return nil
        }
        self.id = id
        self.label = label
        self.sfSymbol = sfSymbol
        self.badge = dictionary["badge"] as? String
    }
}

/// A floating UITabBar overlay that adopts iOS 26 Liquid Glass automatically
/// when the app is built against the iOS 26 SDK. On earlier iOS the bar falls
/// back to the translucent blurred UITabBar appearance.
final class LiquidGlassTabBarOverlay: NSObject {

    // Public callbacks
    var onTabSelected: ((Int, String) -> Void)?
    var onLayoutChanged: ((Double, Double) -> Void)?

    // Internal state
    private weak var window: UIWindow?
    private var tabBar: UITabBar?
    private var items: [LiquidGlassTabItem] = []

    func attach(to window: UIWindow) {
        if self.window === window, tabBar != nil { return }
        self.window = window

        let tabBar = UITabBar()
        tabBar.translatesAutoresizingMaskIntoConstraints = false
        tabBar.delegate = self

        // Default appearance triggers Liquid Glass automatically on iOS 26.
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        tabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = appearance
        }

        window.addSubview(tabBar)

        NSLayoutConstraint.activate([
            tabBar.leadingAnchor.constraint(equalTo: window.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: window.trailingAnchor),
            tabBar.bottomAnchor.constraint(equalTo: window.bottomAnchor),
        ])

        self.tabBar = tabBar
        emitLayout()
    }

    func configure(items: [LiquidGlassTabItem], selectedIndex: Int, tintHex: String?) {
        guard let tabBar else { return }

        // Preserve selection across re-configs (badge changes, etc.)
        let previousSelectedId: String? = tabBar.selectedItem.flatMap { current in
            self.items.indices.contains(current.tag) ? self.items[current.tag].id : nil
        }

        self.items = items

        let uiItems: [UITabBarItem] = items.enumerated().map { index, item in
            let tab = UITabBarItem(
                title: item.label,
                image: UIImage(systemName: item.sfSymbol),
                tag: index
            )
            if let badge = item.badge, !badge.isEmpty {
                tab.badgeValue = badge
            }
            return tab
        }

        tabBar.setItems(uiItems, animated: false)

        if let previousSelectedId, let restoreIdx = items.firstIndex(where: { $0.id == previousSelectedId }) {
            tabBar.selectedItem = uiItems[restoreIdx]
        } else if selectedIndex >= 0, selectedIndex < uiItems.count {
            tabBar.selectedItem = uiItems[selectedIndex]
        }

        if let tintHex, let tint = UIColor(hex: tintHex) {
            tabBar.tintColor = tint
        }
        emitLayout()
    }

    func updateBadge(id: String, badge: String?) {
        guard let tabBar, let tabBarItems = tabBar.items,
              let idx = items.firstIndex(where: { $0.id == id }),
              idx < tabBarItems.count else { return }
        let value = (badge?.isEmpty ?? true) ? nil : badge
        tabBarItems[idx].badgeValue = value
    }

    func show() {
        tabBar?.isHidden = false
        emitLayout()
    }

    func hide() {
        tabBar?.isHidden = true
    }

    func setSelectedIndex(_ index: Int) {
        guard let tabBar, let items = tabBar.items, index >= 0, index < items.count else { return }
        tabBar.selectedItem = items[index]
    }

    func setSelected(id: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        setSelectedIndex(index)
    }

    func currentLayout() -> (height: Double, bottomSafeArea: Double) {
        guard let tabBar else { return (0, 0) }
        tabBar.layoutIfNeeded()
        let bottomInset = tabBar.safeAreaInsets.bottom
        return (Double(tabBar.frame.height), Double(bottomInset))
    }

    private func emitLayout() {
        let layout = currentLayout()
        onLayoutChanged?(layout.height, layout.bottomSafeArea)
    }
}

// MARK: - UITabBarDelegate
extension LiquidGlassTabBarOverlay: UITabBarDelegate {
    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        guard item.tag >= 0, item.tag < items.count else { return }
        let selected = items[item.tag]
        onTabSelected?(item.tag, selected.id)
    }
}

// MARK: - UIColor+hex
private extension UIColor {
    convenience init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let rgb = UInt64(value, radix: 16) else { return nil }
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255
        let b = CGFloat(rgb & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
