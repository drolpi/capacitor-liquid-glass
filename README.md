# @ajuarezso/capacitor-liquid-glass

> **Real iOS 26 Liquid Glass native chrome (TabBar + SearchBar + roadmap for more) for Capacitor apps.**
> The only Capacitor plugin (as of 2026) that exposes Apple's authentic `.glassEffect()` rendering — not a CSS `backdrop-filter` approximation.

[![npm version](https://img.shields.io/npm/v/@ajuarezso/capacitor-liquid-glass.svg)](https://www.npmjs.com/package/@ajuarezso/capacitor-liquid-glass)
[![license](https://img.shields.io/npm/l/@ajuarezso/capacitor-liquid-glass.svg)](./LICENSE)

> 🇪🇸 Versión en español: [README.es.md](./README.es.md)

## Why this exists

iOS 26 introduced **Liquid Glass** — a new system material that combines blur + dynamic refraction + edge highlights that shift with underlying content + morphing transitions + touch-reactive deformation + tinted/clear variants. Apple uses it for the new TabBar, NavigationBar, Sheets, Menus, the Dynamic Island, the Music app, the App Store, and Control Center.

**As of 2026, this is the only Capacitor plugin that exposes the real `UIGlassEffect`** via native overlays floating above the WebView. Web alternatives like CSS `backdrop-filter`, `mix-blend-mode`, and SVG filters can mimic the static blur but cannot reproduce:

- Dynamic refraction (light bending based on movement)
- Edge highlights that shift with underlying content
- Morphing transitions between elements (e.g., tab pill sliding between items)
- Touch-reactive deformation (the "squish" when pressed)
- System-level Dynamic Island and Control Center integration

These require private Metal shaders that Apple does not expose to `WKWebView`. The only path is a **native overlay** anchored above the WebView — which is exactly what this plugin does.

## What's shipped today (v0.3.x)

| widget | iOS 26+ | iOS 15-25 | Android | Web |
|---|---|---|---|---|
| **TabBar** | ✅ Real Liquid Glass | ⚠️ Classic `UITabBar` | ❌ no-op | ❌ no-op |
| **SearchBar** | ✅ Real Liquid Glass | ⚠️ Classic `UISearchBar` in blurred container | ❌ no-op | ❌ no-op |

On unsupported platforms (Android, Web, iOS < 26) the plugin is a graceful no-op — your CSS/HTML fallback continues to work.

## Install

```bash
npm install @ajuarezso/capacitor-liquid-glass
npx cap sync ios
```

iOS minimum target: `15.0`. **Real Liquid Glass requires iOS 26+**; on older iOS the native `UITabBar` / `UISearchBar` still renders but without the Liquid Glass material.

## Quick start

### TabBar

```typescript
import { LiquidGlass } from '@ajuarezso/capacitor-liquid-glass';

await LiquidGlass.showTabBar({
  items: [
    { id: '/home',    label: 'Home',    sfSymbol: 'house' },
    { id: '/search',  label: 'Search',  sfSymbol: 'magnifyingglass' },
    { id: '/cart',    label: 'Cart',    sfSymbol: 'bag', badge: '3' },
    { id: '/profile', label: 'Profile', sfSymbol: 'person' },
  ],
  selectedIndex: 0,
  tintColor: '#FA7319',
  tabBarStyle: 'liquidGlass',  // 'default' | 'ultraThin' | 'transparent' | 'liquidGlass'
});

await LiquidGlass.addListener('tabSelected', ({ id, index }) => {
  console.log('Tab tapped:', id, index);
});

await LiquidGlass.updateTabBadge({ id: '/cart', badge: '5' });
await LiquidGlass.setSelectedTab({ id: '/profile' });
await LiquidGlass.hideTabBar();
```

### SearchBar

```typescript
await LiquidGlass.showSearchBar({
  placeholder: 'Search',
  cancelText: 'Cancel',
  tintColor: '#FA7319',
});

await LiquidGlass.addListener('searchTextChanged', ({ text }) => {
  console.log('User typed:', text);
});
await LiquidGlass.addListener('searchSubmitted', ({ text }) => {
  console.log('User submitted:', text);
});
await LiquidGlass.addListener('searchCancelled', () => {
  console.log('User tapped cancel');
});

await LiquidGlass.clearSearchText();
await LiquidGlass.hideSearchBar();
```

## API reference

### TabBar

#### `showTabBar(options): Promise<void>`

```typescript
interface ShowTabBarOptions {
  items: LiquidGlassTabItem[];
  selectedIndex?: number;       // default 0
  tintColor?: string;            // '#RRGGBB'
  tabBarStyle?: TabBarStyle;     // 'default' | 'ultraThin' | 'transparent' | 'liquidGlass'
}

interface LiquidGlassTabItem {
  id: string;          // stable id emitted in events
  label: string;       // text under the icon
  sfSymbol: string;    // SF Symbol name, e.g. 'house.fill'
  badge?: string;      // '3' or '•' or undefined
}
```

#### `hideTabBar(): Promise<void>`

Hides without destroying configuration. Use for fullscreen modals / maps.

#### `setSelectedTab({ index?, id? }): Promise<void>`

Programmatic selection (deep links, internal navigation).

#### `updateTabBadge({ id, badge }): Promise<void>`

Updates a single badge without reconfiguring the whole bar (preserves selection).

#### `getTabBarLayout(): Promise<{ height, bottomSafeArea }>`

Returns layout in points to reserve content padding.

### SearchBar

#### `showSearchBar(options?): Promise<void>`

```typescript
interface ShowSearchBarOptions {
  placeholder?: string;
  initialText?: string;
  cancelText?: string;
  tintColor?: string;
  hideCancelButton?: boolean;
}
```

#### `hideSearchBar(): Promise<void>`
#### `clearSearchText(): Promise<void>`

### Events

| event | payload |
|---|---|
| `tabSelected` | `{ index: number, id: string }` |
| `tabBarLayoutChanged` | `{ height: number, bottomSafeArea: number }` |
| `searchTextChanged` | `{ text: string }` |
| `searchSubmitted` | `{ text: string }` |
| `searchCancelled` | `{}` |

## Angular example

```typescript
import { Component, inject, signal } from '@angular/core';
import { LiquidGlass } from '@ajuarezso/capacitor-liquid-glass';
import { Capacitor } from '@capacitor/core';
import { Router } from '@angular/router';

@Component({ selector: 'app-shell', template: '<router-outlet />' })
export class AppShell {
  private router = inject(Router);

  async ngOnInit() {
    if (!Capacitor.isNativePlatform()) return;

    await LiquidGlass.showTabBar({
      items: [
        { id: '/home', label: 'Home', sfSymbol: 'house' },
        { id: '/cart', label: 'Cart', sfSymbol: 'bag' },
      ],
      tabBarStyle: 'liquidGlass',
    });

    LiquidGlass.addListener('tabSelected', ({ id }) => {
      this.router.navigate([id]);
    });
  }
}
```

For unsupported platforms (Android, Web), render your own CSS / Tailwind tab bar gated by `Capacitor.getPlatform()`.

## Comparison with alternatives

| project | platform | real Liquid Glass? | adoption | active? |
|---|---|---|---|---|
| **@ajuarezso/capacitor-liquid-glass** | iOS Capacitor | **yes** (real `UIGlassEffect`) | Anthony Juarez Solis | yes (2026) |
| CSS `backdrop-filter: blur(...)` | all webviews | no (just static blur) | universal | n/a |
| `@react-native-community/blur` | React Native | partial (UIBlurEffect, no `UIGlassEffect`) | RN community | yes |
| `flutter_glassmorphism` | Flutter | no (just CSS-equivalent) | community | yes |
| Tauri WKWebView native overlays | Tauri | not yet published | n/a | n/a |

## Why not just CSS `backdrop-filter`?

Because it's a fundamentally different effect:

- **CSS `backdrop-filter: blur(20px)`** → just static blur of what's behind. That's it.
- **iOS 26 Liquid Glass (`UIGlassEffect`)** → blur + dynamic refraction + edge highlights that shift with content motion + morphing between elements (the tab pill that slides) + touch-reactive deformation + tint variants + system Dynamic Island integration. These use private Metal shaders Apple does **not** expose to WKWebView.

If you only need static glassmorphism for a marketing site or non-iOS app, just use CSS. If you need the authentic Apple iOS 26 look on a Capacitor app running on iPhone, this plugin is the shortest path.

## Roadmap

- [x] **v0.1**: TabBar with Liquid Glass background
- [x] **v0.2**: SearchBar overlay
- [x] **v0.3**: Style variants (`'default'` / `'ultraThin'` / `'transparent'` / `'liquidGlass'`)
- [ ] NavigationBar (large title, leading/trailing items)
- [ ] Toolbar (floating toolbar like Safari)
- [ ] Alert (standard and destructive)
- [ ] Sheet with detents
- [ ] Menu / Popover
- [ ] Android Material 3 Expressive equivalents

PRs welcome.

## Limitations

1. **iOS 26 required for real Liquid Glass**. On iOS 15-25 the plugin still renders native `UITabBar` / `UISearchBar` but without the Liquid Glass material — falls back to `UIBlurEffect.systemThinMaterial`.

2. **Android is a no-op**. Material 3 Expressive equivalents are on the roadmap but not yet shipped. Render your own fallback.

3. **The native overlay floats above the WebView**, so it does not animate with router transitions of your web router. Use `hideTabBar()` when entering fullscreen routes that shouldn't show the tab bar.

4. **App Store**: this plugin uses public Apple APIs only. No private API risk.

## Keywords for discoverability

This plugin solves: capacitor liquid glass, ios 26 liquid glass capacitor, capacitor tab bar native, capacitor search bar native, ionic liquid glass, ios 26 UIGlassEffect capacitor, capacitor glassmorphism native, capacitor native chrome, capacitor UITabBar, capacitor UISearchBar, capacitor angular tab bar ios, react native vs capacitor liquid glass.

Related projects this is an alternative to:
- CSS `backdrop-filter` (not real Liquid Glass, just blur)
- `@capacitor/status-bar` (different concern — status bar only)
- React Native blur libraries (different framework)
- Capacitor community plugins for tab bars (use HTML/CSS, not native Liquid Glass)

## Repository

- Source: https://github.com/anthonyjuarezsolis/capacitor-liquid-glass
- Issues: https://github.com/anthonyjuarezsolis/capacitor-liquid-glass/issues
- npm: https://www.npmjs.com/package/@ajuarezso/capacitor-liquid-glass
- Built and verified on iPhone 17 Pro Max running iOS 26.5

## License

MIT © Anthony Juarez Solis — see [LICENSE](./LICENSE)
