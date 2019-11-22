import { NativeEventEmitter, NativeModules } from 'react-native';
import networkStatus from './globals/browser/networkStatus';
import './globals/navigator/userAgent';
import './globals/window/DOMParser';

const browser = {
  networkStatus,
  webRequest: {
    onHeadersReceived: {
      addListener() {},
    },
  },
  history: {
    onVisited: {
      addListener() {},
    },
    getVisits() {
      return Promise.resolve([]);
    },
    search() {
      return Promise.resolve([]);
    },
  },
  tabs: {
    onCreated: {
      addListener() {},
      removeListener() {},
    },
    onUpdated: {
      addListener() {},
      removeListener() {},
    },
    onRemoved: {
      addListener() {},
      removeListener() {},
    },
    onActivated: {
      addListener() {},
      removeListener() {},
    },
    query: () => Promise.resolve([]),
  },
  cliqz: {
    async setPref(/* key, value */) {
      return Promise.resolve();
    },
    async getPref(key) {
      return NativeModules.BrowserCliqz.getPref(key);
    },
    async hasPref(/* key */) {
      return Promise.resolve(false);
    },
    async clearPref(/* key */) {
      return Promise.resolve();
    },
    onPrefChange: (function setupPrefs() {
      const prefs = NativeModules.BrowserCliqz;
      const listeners = new Map();
      const eventEmitter = new NativeEventEmitter(prefs);

      eventEmitter.addListener('prefChange', pref => {
        listeners.entries().forEach(([listener, prefName]) => {
          if (pref === prefName) {
            try {
              listener();
            } catch (e) {
              // one failing listener should not prevent other from being called
            }
          }
        });
      });

      return {
        addListener(listener, prefix, key) {
          const pref = `${prefix || ''}${key || ''}`;
          listeners.set(listener, pref);
          prefs.addPrefListener(pref);
        },
        removeListener(listener) {
          const pref = listeners.get(listener);
          listeners.delete(listener);
          prefs.removePrefListener(pref);
        },
      };
    })(),
  },
};

global.browser = browser;
global.chrome = browser;
// eslint-disable-next-line no-underscore-dangle
const _fetch = global.window.fetch;
global.window.fetch = (u, o) => {
  if (!o) {
    return _fetch(u);
  }

  return _fetch(u, {
    ...o,
    headers: {
      ...(o.headers || {}),
      'user-agent':
        'Mozilla/5.0 (iPhone; CPU iPhone OS 13_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) FxiOS/3.1.0 Mobile/15E148 Safari/605.1.15',
    },
  });
};
