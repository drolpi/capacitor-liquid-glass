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

export interface ShowTabBarOptions {
  items: LiquidGlassTabItem[];
  /** Index of the initially selected item. Defaults to 0. */
  selectedIndex?: number;
  /** Tint color for selected state, hex "#RRGGBB". Defaults to iOS system tint. */
  tintColor?: string;
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

  removeAllListeners(): Promise<void>;
}
