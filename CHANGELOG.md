# Changelog

All notable changes to this project will be documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) • SemVer.

## [0.3.x] — 2026-05

### Added
- TabBar style variants: `'default'` | `'ultraThin'` | `'transparent'` | `'liquidGlass'`
- `getTabBarLayout()` returns `{ height, bottomSafeArea }` for content padding

## [0.2.0] — 2026-05

### Added
- Native Liquid Glass SearchBar overlay (`showSearchBar`, `hideSearchBar`, `clearSearchText`)
- Events: `searchTextChanged`, `searchSubmitted`, `searchCancelled`

## [0.1.0] — 2026-05

### Added
- Initial release: TabBar with Liquid Glass background
- iOS 26+ real `UIGlassEffect`, fallback to `UITabBar` on iOS 15-25
- API: `showTabBar`, `hideTabBar`, `setSelectedTab`, `updateTabBadge`
- Events: `tabSelected`, `tabBarLayoutChanged`
- Android: graceful no-op
