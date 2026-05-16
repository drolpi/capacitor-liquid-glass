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

/// Visual style of the tab bar background.
enum LiquidGlassTabBarStyle: String {
    /// Translucent blurred — adopta Liquid Glass automáticamente en iOS 26+
    /// cuando el binario está linkeado contra el SDK iOS 26 (Xcode 26+).
    case `default`
    /// Minimal blur (`systemUltraThinMaterial`) — más ver-through que default.
    /// NOTA: este override CANCELA el adopt automático de Liquid Glass.
    case ultraThin
    /// No background, no blur — content behind se ve completo.
    /// NOTA: este override CANCELA el adopt automático de Liquid Glass.
    case transparent
    /// Liquid Glass nativo iOS 26 — alias funcional de `.default`. Se mantiene
    /// como case separado para semántica explícita en el consumer ("este
    /// layout pide específicamente Liquid Glass, no fallback genérico").
    case liquidGlass
}

/// Tab bar flotante que adopta iOS 26 Liquid Glass automáticamente cuando la
/// app se compila contra el SDK iOS 26.
///
/// **Decisión arquitectónica crítica**: este view controller se adjunta como
/// CHILD del view controller que contiene el WKWebView de Capacitor
/// (`bridge?.viewController`), y el `UITabBar` vive como subview de
/// `self.view`. Esto crea el view controller hierarchy completo que iOS 26
/// necesita para aplicar el material Liquid Glass automáticamente al
/// UITabBar.
///
/// Por qué NO usar `window.rootViewController`: en Capacitor el rootVC del
/// window puede ser un container distinto al VC del webview. iOS 26 solo
/// aplica Liquid Glass auto cuando el UITabBar vive en la jerarquía del VC
/// que tiene el webview activo. Agregarlo al rootVC del window puede
/// romper el auto-adopt y dejarlo con material translúcido genérico opaco
/// (no el real de Music / App Store).
///
/// Patrón inspirado en `stay-liquid` (alistairheath/stay-liquid GitHub).
final class LiquidGlassTabBarOverlay: UIViewController {

    // Public callbacks
    var onTabSelected: ((Int, String) -> Void)?
    var onLayoutChanged: ((Double, Double) -> Void)?

    // Internal state
    private let tabBar = UITabBar()
    private var items: [LiquidGlassTabItem] = []
    private weak var hostVC: UIViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Background transparente. El `self.view` está sizado SOLO al rect
        // del tab bar (leading/trailing/bottom al hostVC, sin top — la
        // altura la determina el intrinsic content size del UITabBar dentro).
        // Por eso NO necesitamos `hitTest` override: el view en sí solo
        // existe sobre el área de la pill, los taps fuera no llegan.
        view.backgroundColor = .clear

        tabBar.translatesAutoresizingMaskIntoConstraints = false
        tabBar.delegate = self

        // CRÍTICO: NO setear appearance acá. iOS 26 adopta Liquid Glass
        // automáticamente SOLO si el UITabBar mantiene su appearance default
        // intacto. Tocar `standardAppearance` / `scrollEdgeAppearance` en
        // CUALQUIER forma — incluso con `configureWithDefaultBackground()` —
        // anula el adopt y deja un material translúcido genérico opaco.
        // Solo los overrides intencionales (.ultraThin, .transparent) tocan
        // el appearance, vía `applyAppearance(...)` desde `configure(...)`.

        view.addSubview(tabBar)

        // UITabBar ocupa TODO el self.view — el view es del tamaño exacto
        // de la pill gracias a las constraints del attach() (sin top).
        NSLayoutConstraint.activate([
            tabBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabBar.topAnchor.constraint(equalTo: view.topAnchor),
            tabBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    /// Adjunta este view controller como child del view controller que
    /// contiene el WKWebView de Capacitor (`bridge?.viewController`).
    /// Idempotente: si ya está adjuntado al mismo host, no-op.
    func attach(to hostVC: UIViewController?) {
        guard let hostVC else { return }
        if self.parent === hostVC { return }
        // Si está adjuntado a otro VC (cambio de host entre sesiones),
        // detachar primero antes de re-adjuntar.
        if self.parent != nil {
            self.willMove(toParent: nil)
            self.view.removeFromSuperview()
            self.removeFromParent()
        }

        hostVC.addChild(self)
        hostVC.view.addSubview(self.view)
        self.view.translatesAutoresizingMaskIntoConstraints = false
        // CRÍTICO: `didMove(toParent:)` ANTES de activar constraints. iOS 26
        // ejecuta el primer layout pass al didMove; tener el parenting
        // completo antes de que el sistema mida el UITabBar es lo que el
        // heurístico de Liquid Glass auto-adopt espera (patrón stay-liquid).
        self.didMove(toParent: hostVC)
        // SIN top constraint — la altura del view se deriva del intrinsic
        // content size del UITabBar dentro (~50pt + safe-area-bottom).
        NSLayoutConstraint.activate([
            self.view.leadingAnchor.constraint(equalTo: hostVC.view.leadingAnchor),
            self.view.trailingAnchor.constraint(equalTo: hostVC.view.trailingAnchor),
            self.view.bottomAnchor.constraint(equalTo: hostVC.view.bottomAnchor),
        ])
        self.hostVC = hostVC
        emitLayout()
    }

    /// Aplica el appearance correspondiente al estilo solicitado.
    /// - `default` / `liquidGlass`: **NO-OP** — el UITabBar mantiene su
    ///   appearance default sin tocar para que iOS 26 aplique Liquid Glass
    ///   automáticamente. Cualquier touch al appearance (incluso
    ///   `configureWithDefaultBackground()`) rompe el auto-adopt.
    /// - `ultraThin`: blur mínimo `systemUltraThinMaterial` — más ver-through.
    ///   Override intencional que CANCELA Liquid Glass.
    /// - `transparent`: sin background ni blur — content behind se ve completo.
    ///   Override intencional que CANCELA Liquid Glass.
    private func applyAppearance(_ tabBar: UITabBar, style: LiquidGlassTabBarStyle) {
        // Early-return para los estilos que confían en el adopt automático
        // del sistema. Tocar appearance acá anula Liquid Glass.
        if style == .default || style == .liquidGlass { return }

        let appearance = UITabBarAppearance()
        switch style {
        case .default, .liquidGlass:
            // Unreachable — early-return arriba. Mantenido por exhaustividad
            // del switch sobre el enum.
            return
        case .ultraThin:
            appearance.configureWithDefaultBackground()
            appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
            appearance.backgroundColor = UIColor.clear
        case .transparent:
            appearance.configureWithTransparentBackground()
            appearance.backgroundEffect = nil
            appearance.backgroundColor = UIColor.clear
            appearance.shadowColor = UIColor.clear
        }
        tabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = appearance
        }
    }

    func configure(items: [LiquidGlassTabItem], selectedIndex: Int, tintHex: String?, style: LiquidGlassTabBarStyle) {
        // Preserve selection across re-configs (badge changes, etc.)
        let previousSelectedId: String? = tabBar.selectedItem.flatMap { current in
            self.items.indices.contains(current.tag) ? self.items[current.tag].id : nil
        }

        self.items = items

        // Re-aplica appearance por si el caller cambió de estilo en runtime.
        applyAppearance(tabBar, style: style)

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

        // CRÍTICO: setter directo `tabBar.items = ...` en lugar de
        // `tabBar.setItems(_, animated: false)`. En iOS 26 el método
        // `setItems(animated:)` toma un path interno distinto que puede
        // invalidar el adopt automático de Liquid Glass. El setter directo
        // es el que stay-liquid usa (línea 98 de su TabsBarOverlay).
        tabBar.items = uiItems

        if selectedIndex < 0 {
            tabBar.selectedItem = nil
        } else if let previousSelectedId, let restoreIdx = items.firstIndex(where: { $0.id == previousSelectedId }) {
            tabBar.selectedItem = uiItems[restoreIdx]
        } else if selectedIndex < uiItems.count {
            tabBar.selectedItem = uiItems[selectedIndex]
        }

        // tintColor aplicado siempre — el A/B test contra stay-liquid confirmó
        // que el adopt del material Liquid Glass NO se logra en este proyecto
        // independientemente del tintColor, así que mantenerlo solo aporta
        // identidad de marca (naranja brand) sin perder nada.
        if let tintHex, let tint = UIColor(hex: tintHex) {
            tabBar.tintColor = tint
        }
        emitLayout()
    }

    func updateBadge(id: String, badge: String?) {
        guard let tabBarItems = tabBar.items,
              let idx = items.firstIndex(where: { $0.id == id }),
              idx < tabBarItems.count else { return }
        let value = (badge?.isEmpty ?? true) ? nil : badge
        tabBarItems[idx].badgeValue = value
    }

    /// CRÍTICO: NO tocar `tabBar.alpha`, `tabBar.transform` ni `tabBar.isHidden`.
    /// iOS 26 inspecciona el UITabBar en el primer layout pass para decidir si
    /// adopta Liquid Glass. Si en ese momento el bar está con `alpha=0` o un
    /// `transform` distinto de `.identity`, el sistema descarta el adopt y NO
    /// re-evalúa aunque después vuelva a valores normales.
    ///
    /// Para animar la aparición/desaparición sin perder el adopt, se manipula
    /// `self.view.isHidden` (el contenedor del VC), no el UITabBar mismo.
    /// Patrón validado en stay-liquid (su `update()` simplemente hace
    /// `view.isHidden = !visible`).
    func show() {
        view.isHidden = false
        emitLayout()
    }

    func hide() {
        view.isHidden = true
    }

    func setSelectedIndex(_ index: Int) {
        guard let items = tabBar.items else { return }
        if index < 0 {
            tabBar.selectedItem = nil
            return
        }
        guard index < items.count else { return }
        tabBar.selectedItem = items[index]
    }

    func setSelected(id: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        setSelectedIndex(index)
    }

    func currentLayout() -> (height: Double, bottomSafeArea: Double) {
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
