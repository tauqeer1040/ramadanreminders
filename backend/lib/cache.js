const CACHE_TTL = 3600 * 1000;
const MAX_SIZE = 200;

class LRUCache {
  constructor(maxSize = MAX_SIZE) {
    this._map = new Map();
    this._maxSize = maxSize;
  }

  get(key) {
    const item = this._map.get(key);
    if (!item) return null;
    if (Date.now() > item.expiry) {
      this._map.delete(key);
      return null;
    }
    this._map.delete(key);
    this._map.set(key, item);
    return item.value;
  }

  set(key, value, ttl = CACHE_TTL) {
    if (this._map.has(key)) {
      this._map.delete(key);
    } else if (this._map.size >= this._maxSize) {
      const oldest = this._map.keys().next().value;
      if (oldest) this._map.delete(oldest);
    }
    this._map.set(key, { value, expiry: Date.now() + ttl });
  }

  delete(key) {
    this._map.delete(key);
  }

  deleteWhere(predicate) {
    for (const key of this._map.keys()) {
      if (predicate(key)) {
        this._map.delete(key);
      }
    }
  }

  get size() {
    return this._map.size;
  }
}

const instance = new LRUCache();

function setCache(key, value) {
  instance.set(key, value);
}

function getCache(key) {
  return instance.get(key);
}

function clearUserCache(uid) {
  instance.delete(`user:${uid}`);
  instance.deleteWhere((key) => key.startsWith(`daily:${uid}:`));
}

function clearJournalCache(id) {
  instance.delete(`journal:${id}`);
}

function deleteCache(key) {
  instance.delete(key);
}

module.exports = { setCache, getCache, clearUserCache, clearJournalCache, deleteCache };
