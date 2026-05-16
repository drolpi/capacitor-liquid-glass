# @ajuarezso/capacitor-liquid-glass

> **Chrome nativo Liquid Glass de iOS 26 (TabBar + SearchBar + roadmap para más) en apps Capacitor.**
> El único plugin Capacitor (a 2026) que expone el `.glassEffect()` auténtico de Apple — no una aproximación con CSS `backdrop-filter`.

[![npm version](https://img.shields.io/npm/v/@ajuarezso/capacitor-liquid-glass.svg)](https://www.npmjs.com/package/@ajuarezso/capacitor-liquid-glass)
[![license](https://img.shields.io/npm/l/@ajuarezso/capacitor-liquid-glass.svg)](./LICENSE)

> 🇬🇧 English version: [README.md](./README.md)

## Por qué existe

iOS 26 introdujo **Liquid Glass** — un material de sistema nuevo que combina blur + refracción dinámica + highlights de borde que se mueven con el contenido subyacente + transiciones de morphing + deformación reactiva al touch + variantes tinted/clear. Apple lo usa en el nuevo TabBar, NavigationBar, Sheets, Menus, el Dynamic Island, la app Music, el App Store, y Control Center.

**A 2026, este es el único plugin Capacitor que expone el `UIGlassEffect` real** vía overlays nativos flotando arriba del WebView. Alternativas web como CSS `backdrop-filter`, `mix-blend-mode`, y filtros SVG pueden mimetizar el blur estático pero no reproducen:

- Refracción dinámica (la luz se curva según el movimiento)
- Highlights de borde que se mueven con el contenido subyacente
- Transiciones morphing entre elementos (ej. el pill del tab deslizándose)
- Deformación reactiva al touch (el "squish" al presionar)
- Integración a nivel de sistema con Dynamic Island y Control Center

Esto requiere shaders Metal privados que Apple no expone al `WKWebView`. El único camino es un **overlay nativo** anclado arriba del WebView — exactamente lo que hace este plugin.

## Qué hay shipped hoy (v0.3.x)

| widget | iOS 26+ | iOS 15-25 | Android | Web |
|---|---|---|---|---|
| **TabBar** | ✅ Liquid Glass real | ⚠️ `UITabBar` clásico | ❌ no-op | ❌ no-op |
| **SearchBar** | ✅ Liquid Glass real | ⚠️ `UISearchBar` clásico en contenedor blurred | ❌ no-op | ❌ no-op |

En plataformas no soportadas (Android, Web, iOS < 26) el plugin es un no-op gracioso — tu fallback CSS/HTML sigue funcionando.

## Instalación

```bash
npm install @ajuarezso/capacitor-liquid-glass
npx cap sync ios
```

Target mínimo iOS: `15.0`. **Liquid Glass real requiere iOS 26+**; en versiones anteriores el `UITabBar` / `UISearchBar` nativo todavía renderiza pero sin el material Liquid Glass.

## Quick start

### TabBar

```typescript
import { LiquidGlass } from '@ajuarezso/capacitor-liquid-glass';

await LiquidGlass.showTabBar({
  items: [
    { id: '/home',    label: 'Home',    sfSymbol: 'house' },
    { id: '/search',  label: 'Buscar',  sfSymbol: 'magnifyingglass' },
    { id: '/cart',    label: 'Carrito', sfSymbol: 'bag', badge: '3' },
    { id: '/profile', label: 'Perfil',  sfSymbol: 'person' },
  ],
  selectedIndex: 0,
  tintColor: '#FA7319',
  tabBarStyle: 'liquidGlass',
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
  placeholder: 'Buscar',
  cancelText: 'Cancelar',
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

## API completa

Ver `README.md` (inglés) para la API detallada. Resumen:

- **TabBar**: `showTabBar`, `hideTabBar`, `setSelectedTab`, `updateTabBadge`, `getTabBarLayout`
- **SearchBar**: `showSearchBar`, `hideSearchBar`, `clearSearchText`
- **Events**: `tabSelected`, `tabBarLayoutChanged`, `searchTextChanged`, `searchSubmitted`, `searchCancelled`

## Comparativa con alternativas

| proyecto | plataforma | Liquid Glass real? | activo? |
|---|---|---|---|
| **@ajuarezso/capacitor-liquid-glass** | iOS Capacitor | **sí** (`UIGlassEffect` real) | sí (2026) |
| CSS `backdrop-filter: blur(...)` | todos los webviews | no (solo blur estático) | n/a |
| `@react-native-community/blur` | React Native | parcial (`UIBlurEffect`, sin `UIGlassEffect`) | sí |
| `flutter_glassmorphism` | Flutter | no (solo CSS-equivalente) | sí |

## Por qué no solo CSS `backdrop-filter`?

Porque es un efecto fundamentalmente distinto:

- **CSS `backdrop-filter: blur(20px)`** → solo blur estático de lo que está atrás. Nada más.
- **iOS 26 Liquid Glass (`UIGlassEffect`)** → blur + refracción dinámica + highlights de borde que se mueven con el contenido + morphing entre elementos (el tab pill que desliza) + deformación reactiva al touch + variantes tinted + integración con Dynamic Island. Usa shaders Metal privados que Apple **no** expone al WKWebView.

Si solo necesitás glassmorphism estático para una landing o app no-iOS, usá CSS. Si necesitás el look auténtico iOS 26 en una app Capacitor en iPhone, este plugin es el camino más corto.

## Roadmap

- [x] **v0.1**: TabBar con fondo Liquid Glass
- [x] **v0.2**: SearchBar overlay
- [x] **v0.3**: Variantes de estilo (`'default'` / `'ultraThin'` / `'transparent'` / `'liquidGlass'`)
- [ ] NavigationBar (large title, items leading/trailing)
- [ ] Toolbar (floating toolbar tipo Safari)
- [ ] Alert (standard y destructive)
- [ ] Sheet con detents
- [ ] Menu / Popover
- [ ] Equivalentes Android Material 3 Expressive

PRs welcome.

## Limitaciones

1. **iOS 26 requerido para Liquid Glass real**. En iOS 15-25 el plugin sigue renderizando `UITabBar` / `UISearchBar` nativo pero sin el material Liquid Glass — cae a `UIBlurEffect.systemThinMaterial`.

2. **Android es un no-op**. Equivalentes Material 3 Expressive están en roadmap pero no shipped. Renderizá tu propio fallback.

3. **El overlay nativo flota arriba del WebView**, así que no anima con las transiciones del router web. Usá `hideTabBar()` cuando entrás a rutas fullscreen que no deben mostrar el tab bar.

4. **App Store**: este plugin usa solo APIs públicas de Apple. Sin riesgo de API privada.

## Keywords para discoverability

Este plugin resuelve: capacitor liquid glass, ios 26 liquid glass capacitor, capacitor tab bar native, capacitor search bar native, ionic liquid glass, ios 26 UIGlassEffect capacitor, capacitor glassmorphism native, capacitor native chrome, capacitor UITabBar, capacitor UISearchBar, capacitor angular tab bar ios.

Proyectos relacionados (alternativa o complementario):
- CSS `backdrop-filter` (no Liquid Glass real, solo blur)
- `@capacitor/status-bar` (concern distinto)
- Librerías de blur para React Native (framework distinto)
- Plugins community Capacitor para tab bars (HTML/CSS, no Liquid Glass nativo)

## Repositorio

- Source: https://github.com/anthonyjuarezsolis/capacitor-liquid-glass
- Issues: https://github.com/anthonyjuarezsolis/capacitor-liquid-glass/issues
- npm: https://www.npmjs.com/package/@ajuarezso/capacitor-liquid-glass
- Construido y verificado en iPhone 17 Pro Max con iOS 26.5

## Licencia

MIT © Anthony Juarez Solis — ver [LICENSE](./LICENSE)
