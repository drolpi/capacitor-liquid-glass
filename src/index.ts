import { registerPlugin } from '@capacitor/core';

import type { LiquidGlassPlugin } from './definitions';

const LiquidGlass = registerPlugin<LiquidGlassPlugin>('LiquidGlass', {
  web: () => import('./web').then((m) => new m.LiquidGlassWeb()),
});

export * from './definitions';
export { LiquidGlass };
