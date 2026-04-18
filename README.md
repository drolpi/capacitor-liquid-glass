# @ajuarezso/capacitor-liquid-glass

Native iOS 26 **Liquid Glass** chrome (TabBar, NavigationBar, Alerts, Sheets, Menus) for Capacitor apps. Falls back gracefully on iOS &lt; 26 and Android (no-op), so your app keeps its own CSS chrome on unsupported platforms.

This plugin exists because, as of 2026, no existing Capacitor plugin exposes the real iOS 26 `.glassEffect()` rendered by UIKit — only CSS `backdrop-filter` approximations. This plugin floats a real `UITabBar` (and friends) as a native overlay above your `WKWebView`, so you get the actual Apple-native morphing, refraction, and tint animations of Liquid Glass on iOS 26+.

> Status: `0.1.0` — **TabBar only**. NavigationBar, Toolbar, Sheet, Alert, Menu, Popover are on the roadmap.

## Install

```bash
npm install @ajuarezso/capacitor-liquid-glass
npx cap sync ios
```

iOS minimum target: `15.0`. Real Liquid Glass requires **iOS 26+**; on older versions the native `UITabBar` still renders but without the Liquid Glass effect.

## Quick start

```ts
import { LiquidGlass } from '@ajuarezso/capacitor-liquid-glass';

// Show the native tab bar
await LiquidGlass.showTabBar({
  items: [
    { id: '/home',    label: 'Home',    sfSymbol: 'house' },
    { id: '/search',  label: 'Search',  sfSymbol: 'magnifyingglass' },
    { id: '/cart',    label: 'Cart',    sfSymbol: 'bag', badge: '3' },
    { id: '/profile', label: 'Profile', sfSymbol: 'person' },
  ],
  selectedIndex: 0,
  tintColor: '#FA7319',
});

// Listen for taps
await LiquidGlass.addListener('tabSelected', ({ id, index }) => {
  console.log('Tab tapped:', id, index);
});

// Update badge without rebuilding the tab bar
await LiquidGlass.updateTabBadge({ id: '/cart', badge: '5' });

// Programmatically change the selected tab
await LiquidGlass.setSelectedTab({ id: '/profile' });

// Hide (e.g. when opening a fullscreen modal)
await LiquidGlass.hideTabBar();
```

## API

### `showTabBar(options)`

| Option          | Type                    | Required | Description                                                 |
| --------------- | ----------------------- | -------- | ----------------------------------------------------------- |
| `items`         | `LiquidGlassTabItem[]`  | yes      | At least one item.                                          |
| `selectedIndex` | `number`                | no       | Initial selection. Defaults to `0`.                         |
| `tintColor`     | `string` (`#RRGGBB`)    | no       | Color of the selected pill. Defaults to the system tint.    |

### `LiquidGlassTabItem`

```ts
interface LiquidGlassTabItem {
  /** Stable id emitted in `tabSelected` events. */
  id: string;
  /** Text under the icon. */
  label: string;
  /** SF Symbol name (e.g. 'house.fill'). */
  sfSymbol: string;
  /** Optional badge value (e.g. '3' or '•'). */
  badge?: string;
}
```

### `hideTabBar()`

Hides the tab bar without destroying it. Use this when opening fullscreen modals, maps, or any UI that should temporarily own the screen. Call `showTabBar(...)` again to restore it.

### `setSelectedTab({ index?, id? })`

Updates the selected tab programmatically. Useful when the user navigates via a deep link, a button inside a page, or any source other than the tab bar itself.

### `updateTabBadge({ id, badge })`

Updates a single tab's badge **without** reconfiguring the whole bar (preserves selection). Pass an empty string or omit `badge` to clear.

### `getTabBarLayout()`

Returns the current `{ height, bottomSafeArea }` in points so you can reserve content padding.

### Events

| Event                  | Payload                                     |
| ---------------------- | ------------------------------------------- |
| `tabSelected`          | `{ index: number, id: string }`             |
| `tabBarLayoutChanged`  | `{ height: number, bottomSafeArea: number }` |

## Angular example

```ts
import { bindLiquidGlassNav } from './liquid-glass-nav';

export class CustomerLayout {
  private readonly nav = bindLiquidGlassNav({
    items: [
      { id: '/home',    label: 'Home',    sfSymbol: 'house' },
      { id: '/orders',  label: 'Orders',  sfSymbol: 'list.bullet.clipboard' },
      { id: '/profile', label: 'Profile', sfSymbol: 'person' },
    ],
    isFullscreen: this.isFullscreen, // signal<boolean>
  });

  readonly useNativeTabBar = this.nav.useNativeTabBar;
}
```

See the `example/` folder for a full wiring including router sync and HTML fallback for unsupported platforms.

## Platform behavior

| Widget       | iOS 26+              | iOS 15–25           | Android | Web        |
| ------------ | -------------------- | ------------------- | ------- | ---------- |
| TabBar       | ✅ Liquid Glass real | ⚠️ Classic UITabBar | ❌ no-op | ❌ no-op   |

When the plugin is a no-op (Android, Web, iOS &lt; 26), render your own HTML / CSS fallback. The plugin exposes `Capacitor.getPlatform()` and your Angular / React code can conditionally swap to a `backdrop-filter` bar.

## Why not just CSS `backdrop-filter`?

Because it's not the same thing.

- **CSS `backdrop-filter`** gives you blur. That's it.
- **Liquid Glass** gives you blur + *dynamic refraction*, *edge highlights that shift with content*, *morphing between elements*, *touch-reactive deformation*, *tinted / clear variants*, and system-level Dynamic Island integration. These require private Metal shaders that Apple does not expose to `WKWebView`.

This plugin is the shortest path to Apple-authentic Liquid Glass from a Capacitor app.

## Roadmap

- [x] `TabBar`
- [ ] `NavigationBar` (large title, leading/trailing items)
- [ ] `Toolbar` (floating toolbar like Safari)
- [ ] `Alert` (standard and destructive)
- [ ] `Sheet` (with detents)
- [ ] `Menu` / `Popover`
- [ ] Android Material 3 Expressive equivalents

PRs welcome.

## License

MIT © Anthony Juarez Solis
