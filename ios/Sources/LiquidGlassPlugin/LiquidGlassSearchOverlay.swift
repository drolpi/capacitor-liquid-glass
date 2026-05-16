import UIKit

/// Callbacks emitted from the search overlay back to the plugin so it can
/// `notifyListeners(...)` to JS land.
protocol LiquidGlassSearchOverlayDelegate: AnyObject {
    func searchOverlayDidChangeText(_ text: String)
    func searchOverlayDidSubmit(_ text: String)
    func searchOverlayDidCancel()
}

/// A floating UISearchBar overlay wrapped in a UIVisualEffectView so it
/// inherits the iOS 26 Liquid Glass look (and falls back to
/// `systemUltraThinMaterial` blur on earlier iOS).
///
/// Auto-layout pin: top of the keyWindow, respecting the safe area, full width.
final class LiquidGlassSearchOverlay: NSObject {

    weak var delegate: LiquidGlassSearchOverlayDelegate?

    // Internal state
    private weak var window: UIWindow?
    private var container: UIVisualEffectView?
    private var searchBar: UISearchBar?

    // Cached config (so re-configures persist across show/hide)
    private var placeholder: String?
    private var initialText: String?
    private var cancelText: String?
    private var tintHex: String?
    private var hideCancelButton: Bool = false

    /// Stores the configuration; safe to call before `show()`.
    func configure(
        placeholder: String?,
        initialText: String?,
        cancelText: String?,
        tintHex: String?,
        hideCancelButton: Bool
    ) {
        self.placeholder = placeholder
        self.initialText = initialText
        self.cancelText = cancelText
        self.tintHex = tintHex
        self.hideCancelButton = hideCancelButton
        // If already attached, push config to live UI right away.
        applyConfigToSearchBar()
    }

    /// Attach + show the overlay on the given window. Idempotent: re-attaching
    /// to the same window is a no-op (just re-applies the config + first responder).
    func show(on window: UIWindow) {
        if self.window === window, container != nil {
            applyConfigToSearchBar()
            container?.isHidden = false
            searchBar?.becomeFirstResponder()
            return
        }
        self.window = window

        // Container with blur — auto-becomes Liquid Glass on iOS 26 SDK.
        let blur = UIBlurEffect(style: .systemUltraThinMaterial)
        let container = UIVisualEffectView(effect: blur)
        container.translatesAutoresizingMaskIntoConstraints = false

        let searchBar = UISearchBar()
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.delegate = self
        searchBar.searchBarStyle = .minimal
        searchBar.backgroundImage = UIImage() // strip default chrome so blur shows through
        searchBar.autocorrectionType = .no
        searchBar.autocapitalizationType = .none
        searchBar.returnKeyType = .search

        container.contentView.addSubview(searchBar)
        window.addSubview(container)

        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: window.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: window.trailingAnchor),
            container.topAnchor.constraint(equalTo: window.topAnchor),

            searchBar.leadingAnchor.constraint(equalTo: container.contentView.leadingAnchor, constant: 8),
            searchBar.trailingAnchor.constraint(equalTo: container.contentView.trailingAnchor, constant: -8),
            searchBar.topAnchor.constraint(equalTo: window.safeAreaLayoutGuide.topAnchor),
            searchBar.bottomAnchor.constraint(equalTo: container.contentView.bottomAnchor, constant: -8),
        ])

        self.container = container
        self.searchBar = searchBar

        applyConfigToSearchBar()
        searchBar.becomeFirstResponder()
    }

    /// Hide overlay (don't tear down — keep config so next `show()` is fast).
    func hide() {
        searchBar?.resignFirstResponder()
        UIView.animate(withDuration: 0.18, animations: { [weak self] in
            self?.container?.alpha = 0
        }, completion: { [weak self] _ in
            self?.container?.isHidden = true
            self?.container?.alpha = 1
        })
    }

    /// Clear text without dismissing the overlay.
    func clearText() {
        searchBar?.text = ""
        // Notify delegate so JS land sees the empty value.
        delegate?.searchOverlayDidChangeText("")
    }

    // MARK: - Private

    private func applyConfigToSearchBar() {
        guard let searchBar else { return }
        searchBar.placeholder = placeholder
        if let initialText { searchBar.text = initialText }
        searchBar.showsCancelButton = !hideCancelButton
        if let tintHex, let tint = UIColor(searchBarHex: tintHex) {
            searchBar.tintColor = tint
        }
        // Override the system "Cancel" label if a custom one was provided.
        if let cancelText, !hideCancelButton {
            // Walk subviews to find the cancel button (UIKit private path is
            // historically how this is done; safe enough — falls through to no-op
            // if the button can't be located on a future iOS).
            if let button = findCancelButton(in: searchBar) {
                button.setTitle(cancelText, for: .normal)
            }
        }
    }

    private func findCancelButton(in view: UIView) -> UIButton? {
        for sub in view.subviews {
            if let btn = sub as? UIButton { return btn }
            if let nested = findCancelButton(in: sub) { return nested }
        }
        return nil
    }
}

// MARK: - UISearchBarDelegate
extension LiquidGlassSearchOverlay: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        delegate?.searchOverlayDidChangeText(searchText)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        delegate?.searchOverlayDidSubmit(searchBar.text ?? "")
        searchBar.resignFirstResponder()
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        searchBar.resignFirstResponder()
        delegate?.searchOverlayDidCancel()
    }
}

// MARK: - UIColor+hex (scoped to this file to avoid duplicate-symbol with TabBarOverlay)
private extension UIColor {
    convenience init?(searchBarHex hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let rgb = UInt64(value, radix: 16) else { return nil }
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255
        let b = CGFloat(rgb & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
