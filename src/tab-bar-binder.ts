import { Capacitor } from '@capacitor/core';

import type { LiquidGlassPlugin, ShowTabBarOptions, TabBarBounds } from './definitions';

/**
 * Keeps the native tab bar glued to an HTML element when `containerElement` is
 * passed to `showTabBar`. Mirrors the measure-and-observe approach of
 * `@capacitor/google-maps`, but adapted for a **fixed overlay** rather than an
 * inline view:
 *
 *  - Google Maps (iOS) reparents its native view into a `WKChildScrollView` so
 *    it scrolls *with* page content. A tab bar must stay glued to the element's
 *    on-screen rect, so we instead push the rect to native, which positions an
 *    on-top overlay via Auto Layout constraints (never `setFrame` — see the
 *    iOS 26 Liquid Glass notes in `LiquidGlassTabBarOverlay.swift`).
 *  - We re-sync on `ResizeObserver` + `scroll` (capture phase, catches nested
 *    scroll containers) + `resize`/`orientationchange` + `visualViewport`
 *    (keyboard / browser-chrome / pinch-zoom), all **coalesced through a single
 *    `requestAnimationFrame`** so a 120 Hz scroll fires at most one bridge call
 *    per frame (the Maps plugin's lack of this is its main jitter source).
 *
 * When `containerElement` is omitted, this is a transparent pass-through to the
 * native bottom-pinned behaviour — zero regression.
 */
export class TabBarBinder {
  private element: HTMLElement | null = null;
  private resizeObserver: ResizeObserver | null = null;
  private rafId: number | null = null;
  /** Last rect pushed to native — skip redundant bridge calls when unchanged. */
  private lastSent: TabBarBounds | null = null;
  /**
   * Bumped on every teardown. Async work (the `measure` retry loop, the awaits
   * in `showTabBar`) snapshots it and bails if a newer call superseded it —
   * prevents a slow first measurement from clobbering a second `showTabBar`.
   */
  private generation = 0;

  /** Stable identity so `removeEventListener` actually detaches the listeners. */
  private readonly onReflow = (): void => this.scheduleSync();

  constructor(private readonly native: LiquidGlassPlugin) {}

  async showTabBar(options: ShowTabBarOptions): Promise<void> {
    // A fresh call always supersedes any previous binding (bumps generation).
    this.teardown();
    const gen = this.generation;

    const target = options.containerElement;
    const wantsBinding = Capacitor.getPlatform() === 'ios' && target != null;

    if (!wantsBinding) {
      return this.native.showTabBar(this.stripElement(options));
    }

    const element = this.resolve(target as string | HTMLElement);
    if (!element) {
      // Selector didn't match — fall back to bottom-pinned instead of throwing.
      return this.native.showTabBar(this.stripElement(options));
    }

    this.element = element;
    const bounds = await this.measure(element, gen);
    if (gen !== this.generation) return; // superseded while measuring

    await this.native.showTabBar({ ...this.stripElement(options), bounds });
    if (gen !== this.generation) return; // superseded while the bridge call ran

    this.lastSent = bounds;
    this.observe(element);
  }

  async hideTabBar(): Promise<void> {
    this.teardown();
    return this.native.hideTabBar();
  }

  // --- internals -----------------------------------------------------------

  /** Removes the (possibly non-serializable) element ref before crossing the bridge. */
  private stripElement(options: ShowTabBarOptions): ShowTabBarOptions {
    if (options.containerElement == null) return options;
    const { containerElement: _drop, ...rest } = options;
    void _drop;
    return rest;
  }

  private resolve(target: string | HTMLElement): HTMLElement | null {
    if (typeof target !== 'string') return target;
    return document.getElementById(target) ?? document.querySelector<HTMLElement>(target);
  }

  private rect(element: HTMLElement): TabBarBounds {
    const r = element.getBoundingClientRect();
    return { x: r.x, y: r.y, width: r.width, height: r.height };
  }

  /**
   * Retry until the element has a non-zero width AND height (guards against
   * pre-layout reads). Bails early if a newer `showTabBar`/`hideTabBar` bumped
   * the generation, so a stale interval can't outlive the call that started it.
   * If it still measures 0 after ~3s, resolves with the zero rect (native falls
   * back to bottom-pinned) and warns so the misconfig is visible.
   */
  private measure(element: HTMLElement, gen: number): Promise<TabBarBounds> {
    const valid = (b: TabBarBounds): boolean => b.width !== 0 && b.height !== 0;
    return new Promise((resolve) => {
      let bounds = this.rect(element);
      if (valid(bounds)) {
        resolve(bounds);
        return;
      }
      let retries = 0;
      const id = setInterval(() => {
        if (gen !== this.generation) {
          clearInterval(id);
          resolve(bounds);
          return;
        }
        bounds = this.rect(element);
        retries++;
        if (valid(bounds) || retries >= 30) {
          clearInterval(id);
          if (!valid(bounds)) {
            console.warn(
              '[LiquidGlass] containerElement still measures 0 after 3s — the native bar will fall back to bottom-pinned.',
            );
          }
          resolve(bounds);
        }
      }, 100);
    });
  }

  private observe(element: HTMLElement): void {
    if (typeof ResizeObserver !== 'undefined') {
      this.resizeObserver = new ResizeObserver(this.onReflow);
      this.resizeObserver.observe(element);
    }
    // Position changes a ResizeObserver won't catch. Capture phase so scrolls in
    // nested `overflow:auto` containers (which don't bubble to window) re-sync too.
    window.addEventListener('scroll', this.onReflow, { passive: true, capture: true });
    window.addEventListener('resize', this.onReflow, { passive: true });
    window.addEventListener('orientationchange', this.onReflow, { passive: true });
    const vv = window.visualViewport;
    if (vv) {
      vv.addEventListener('resize', this.onReflow);
      vv.addEventListener('scroll', this.onReflow);
    }
  }

  private scheduleSync(): void {
    if (this.rafId != null) return;
    this.rafId = requestAnimationFrame(() => {
      this.rafId = null;
      if (!this.element) return;
      const bounds = this.rect(this.element);
      // Hidden / collapsed (display:none, detached, off-screen with 0 width):
      // keep the last position, don't push a degenerate rect. A zero in EITHER
      // dimension is useless — matches the native guard (rect.width/height > 0).
      if (bounds.width === 0 || bounds.height === 0) return;
      // Skip redundant bridge calls when the rect didn't actually move (e.g. a
      // scroll in an unrelated container, or a position:fixed element). Each
      // skipped call also saves a native `layoutIfNeeded`.
      if (this.sameRect(bounds, this.lastSent)) return;
      this.lastSent = bounds;
      void this.native.setTabBarBounds({ bounds });
    });
  }

  private sameRect(a: TabBarBounds, b: TabBarBounds | null): boolean {
    if (!b) return false;
    return (
      Math.abs(a.x - b.x) < 0.5 &&
      Math.abs(a.y - b.y) < 0.5 &&
      Math.abs(a.width - b.width) < 0.5 &&
      Math.abs(a.height - b.height) < 0.5
    );
  }

  private teardown(): void {
    // Invalidate any in-flight measure/await chain from a previous call.
    this.generation++;
    this.lastSent = null;
    if (this.rafId != null) {
      cancelAnimationFrame(this.rafId);
      this.rafId = null;
    }
    this.resizeObserver?.disconnect();
    this.resizeObserver = null;
    // `capture` must match the add-time flag for removal to take effect.
    window.removeEventListener('scroll', this.onReflow, { capture: true });
    window.removeEventListener('resize', this.onReflow);
    window.removeEventListener('orientationchange', this.onReflow);
    const vv = window.visualViewport;
    if (vv) {
      vv.removeEventListener('resize', this.onReflow);
      vv.removeEventListener('scroll', this.onReflow);
    }
    this.element = null;
  }
}
