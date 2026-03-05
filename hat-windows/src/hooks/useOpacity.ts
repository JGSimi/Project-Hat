import { useState, useEffect, useCallback } from 'react';
import { load } from '@tauri-apps/plugin-store';

const STORE_KEY = 'bg-opacity';
const DEFAULT_OPACITY = 0.65;

function applyOpacity(value: number) {
  const root = document.documentElement.style;
  root.setProperty('--bg-opacity', value.toString());
  root.setProperty('--bg-color', `rgba(10, 10, 12, ${value})`);
  root.setProperty('--header-bg', `rgba(15, 15, 18, ${value * 0.6})`);
}

export function useOpacity() {
  const [opacity, setOpacityState] = useState(DEFAULT_OPACITY);

  useEffect(() => {
    (async () => {
      try {
        const store = await load('settings.json', { autoSave: true });
        const saved = await store.get<number>(STORE_KEY);
        if (saved !== null && saved !== undefined) {
          setOpacityState(saved);
          applyOpacity(saved);
        }
      } catch (e) {
        console.warn('Failed to load opacity setting', e);
      }
    })();
  }, []);

  const setOpacity = useCallback(async (value: number) => {
    setOpacityState(value);
    applyOpacity(value);
    try {
      const store = await load('settings.json', { autoSave: true });
      await store.set(STORE_KEY, value);
    } catch (e) {
      console.warn('Failed to save opacity setting', e);
    }
  }, []);

  return { opacity, setOpacity };
}
