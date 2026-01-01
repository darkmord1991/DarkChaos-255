#include "Define.h"
#include <cstdint>
#include <list>
#include <unordered_map>
#include <functional>

namespace DarkChaos
{
    namespace ItemUpgrade
    {
        /**
         * Simple LRU Cache implementation
         */
        template<typename Key, typename Value>
        class LRUCache
        {
        public:
            typedef std::pair<Key, Value> KeyValuePair;
            typedef typename std::list<KeyValuePair>::iterator ListIterator;

            LRUCache(size_t capacity) : _capacity(capacity) {}

            void Put(const Key& key, const Value& value)
            {
                auto it = _cacheMap.find(key);
                if (it != _cacheMap.end())
                {
                    _cacheList.erase(it->second);
                    _cacheMap.erase(it);
                }

                _cacheList.push_front({ key, value });
                _cacheMap[key] = _cacheList.begin();

                if (_cacheMap.size() > _capacity)
                {
                    auto last = _cacheList.end();
                    last--;
                    _cacheMap.erase(last->first);
                    _cacheList.pop_back();
                }
            }

            bool Get(const Key& key, Value& outValue)
            {
                auto it = _cacheMap.find(key);
                if (it == _cacheMap.end())
                    return false;

                _cacheList.splice(_cacheList.begin(), _cacheList, it->second);
                outValue = it->second->second;
                return true;
            }

            // Get pointer to value (allows modification without copy, but DOES NOT update LRU position automatically)
            // Use with caution or call Touch(key) manually
            Value* GetPtr(const Key& key)
            {
                auto it = _cacheMap.find(key);
                if (it == _cacheMap.end())
                    return nullptr;
                return &(it->second->second);
            }

            // Updates LRU position for an existing key
            void Touch(const Key& key)
            {
                auto it = _cacheMap.find(key);
                if (it != _cacheMap.end())
                {
                    _cacheList.splice(_cacheList.begin(), _cacheList, it->second);
                }
            }

            bool Exists(const Key& key) const
            {
                return _cacheMap.find(key) != _cacheMap.end();
            }

            void Remove(const Key& key)
            {
                auto it = _cacheMap.find(key);
                if (it != _cacheMap.end())
                {
                    _cacheList.erase(it->second);
                    _cacheMap.erase(it);
                }
            }
            
            // Remove with predicate
            void RemoveIf(std::function<bool(const Key&, const Value&)> predicate)
            {
                for (auto it = _cacheList.begin(); it != _cacheList.end(); )
                {
                    if (predicate(it->first, it->second))
                    {
                        _cacheMap.erase(it->first);
                        it = _cacheList.erase(it);
                    }
                    else
                    {
                        ++it;
                    }
                }
            }

            void Clear()
            {
                _cacheMap.clear();
                _cacheList.clear();
            }

            size_t Size() const { return _cacheMap.size(); }
            size_t Capacity() const { return _capacity; }

        private:
            size_t _capacity;
            std::list<KeyValuePair> _cacheList;
            std::unordered_map<Key, ListIterator> _cacheMap;
        };

        /**
         * Performance Statistics for Item Upgrades
         */
        struct UpgradeStatistics
        {
            uint32_t upgrades_performed{0};
			uint32_t cache_hits{0};
			uint32_t cache_misses{0};
			uint32_t db_reads{0};
			uint32_t db_writes{0};
			uint64_t total_latency_us{0}; // Microseconds

            void Reset()
            {
                upgrades_performed = 0;
                cache_hits = 0;
                cache_misses = 0;
                db_reads = 0;
                db_writes = 0;
                total_latency_us = 0;
            }
        };

    } // namespace ItemUpgrade
} // namespace DarkChaos
