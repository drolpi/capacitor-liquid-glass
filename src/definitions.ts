import type { PluginListenerHandle } from '@capacitor/core';

export interface LiquidGlassTabItem {
  /** Stable id used in tab selection events. */
  id: string;
  /** Label rendered under the icon. */
  label: string;
  /** SF Symbol name for iOS (e.g. "house.fill"). */
  sfSymbol: string;
  /** Optional badge value (e.g. "3" or "•"). */
  badge?: string;
}

/**
 * Visual style of the tab bar background.
 *  - `'default'` (default): Liquid Glass on iOS 26+ (translucent blurred).
 *  - `'ultraThin'`: minimal blur (`UIBlurEffect.Style.systemUltraThinMaterial`),
 *    more see-through than default.
 *  - `'transparent'`: no background, no blur — content behind shows through 100%.
 *    Trade-off: legibilidad puede sufrir sobre contenido caótico.
 *  - `'liquidGlass'`: REAL iOS 26 `UIGlassEffect` — el mismo material que usan
 *    Music y App Store. En iOS < 26 cae a `UIBlurEffect.systemThinMaterial`
 *    (aproximación cercana con system vibrancy).
 */
export type TabBarStyle = 'default' | 'ultraThin' | 'transparent' | 'liquidGlass';

export interface ShowTabBarOptions {
  items: LiquidGlassTabItem[];
  /** Index of the initially selected item. Defaults to 0. */
  selectedIndex?: number;
  /** Tint color for selected state, hex "#RRGGBB". Defaults to iOS system tint. */
  tintColor?: string;
  /** Visual style of the tab bar background. Defaults to `'default'`. */
  tabBarStyle?: TabBarStyle;
}

export interface SetSelectedTabOptions {
  /** Either pass numeric index or the item id. */
  index?: number;
  id?: string;
}

export interface UpdateTabBadgeOptions {
  /** Tab item id whose badge should change. */
  id: string;
  /** New badge value; pass empty string or omit to clear it. */
  badge?: string;
}

export interface TabSelectedEvent {
  index: number;
  id: string;
}

export interface TabBarLayoutEvent {
  /** Total height of the tab bar including internal padding (pt). */
  height: number;
  /** Safe-area bottom inset the tab bar is sitting on (pt). */
  bottomSafeArea: number;
}

/**
 * Options for the native iOS Liquid Glass search bar overlay (top of window).
 *
 * On iOS 26+ the underlying `UISearchBar` adopts the system Liquid Glass look
 * automatically; on earlier iOS we wrap it in a `systemUltraThinMaterial`
 * blurred container so the visual is as close as possible.
 */
export interface ShowSearchBarOptions {
  /** Placeholder shown when the field is empty. */
  placeholder?: string;
  /** Initial text the field opens with. */
  initialText?: string;
  /** Custom label for the trailing "Cancel" button. */
  cancelText?: string;
  /** Tint color for the cursor + Cancel button, hex `"#RRGGBB"`. */
  tintColor?: string;
  /** Hide the trailing Cancel button (defaults to `false`). */
  hideCancelButton?: boolean;
}

export interface SearchTextChangedEvent {
  /** Current text in the search field. */
  text: string;
}

export interface SearchSubmittedEvent {
  /** Text the user submitted (return key on the keyboard). */
  text: string;
}

export interface LiquidGlassPlugin {
  /** Creates (or updates) and shows the native Liquid Glass tab bar. */
  showTabBar(options: ShowTabBarOptions): Promise<void>;

  /** Hides the tab bar without destroying configuration. */
  hideTabBar(): Promise<void>;

  /** Updates the currently selected tab. */
  setSelectedTab(options: SetSelectedTabOptions): Promise<void>;

  /** Updates a single tab's badge without reconfiguring the whole bar. */
  updateTabBadge(options: UpdateTabBadgeOptions): Promise<void>;

  /** Current layout of the tab bar (height + safe area). */
  getTabBarLayout(): Promise<TabBarLayoutEvent>;

  /** Emitted every time the user taps a tab. */
  addListener(
    eventName: 'tabSelected',
    listenerFunc: (event: TabSelectedEvent) => void,
  ): Promise<PluginListenerHandle>;

  /** Emitted when the tab bar's height or safe-area changes (rotation, etc.). */
  addListener(
    eventName: 'tabBarLayoutChanged',
    listenerFunc: (event: TabBarLayoutEvent) => void,
  ): Promise<PluginListenerHandle>;

  /** Shows the native Liquid Glass search bar overlay anchored to the top. */
  showSearchBar(options?: ShowSearchBarOptions): Promise<void>;

  /** Hides the search bar without destroying configuration. */
  hideSearchBar(): Promise<void>;

  /** Clears the text in the search field without dismissing the overlay. */
  clearSearchText(): Promise<void>;

  /** Emitted on every keystroke while the user types in the search field. */
  addListener(
    eventName: 'searchTextChanged',
    listenerFunc: (event: SearchTextChangedEvent) => void,
  ): Promise<PluginListenerHandle>;

  /** Emitted when the user taps the keyboard's "Search" / return key. */
  addListener(
    eventName: 'searchSubmitted',
    listenerFunc: (event: SearchSubmittedEvent) => void,
  ): Promise<PluginListenerHandle>;

  /** Emitted when the user taps the trailing Cancel button. */
  addListener(
    eventName: 'searchCancelled',
    listenerFunc: () => void,
  ): Promise<PluginListenerHandle>;

  removeAllListeners(): Promise<void>;
}
