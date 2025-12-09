import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pokemon.dart';
import '../core/constants/app_constants.dart';

/// Implements proper multi-layer caching (memory + disk)
class CacheService {
  final SharedPreferences _prefs;

  // In-memory cache
  final Map<int, Pokemon> _memoryCache = {};

  CacheService(this._prefs);

  /// Cache individual Pokemon with timestamp
  Future<void> cachePokemon(Pokemon pokemon) async {
    try {
      final key = '${AppConstants.pokemonCachePrefix}${pokemon.id}';

      // Store in memory cache
      _memoryCache[pokemon.id] = pokemon;

      // Store in persistent cache
      await _prefs.setString(key, jsonEncode(pokemon.toJson()));
      await _prefs.setInt(
        '${AppConstants.cacheTimePrefix}${pokemon.id}',
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      debugPrint('Cache error: $e');
    }
  }

  /// Get cached Pokemon with expiry check
  Pokemon? getCachedPokemon(int id) {
    // Check memory cache first (fastest)
    if (_memoryCache.containsKey(id)) {
      return _memoryCache[id];
    }

    // Check persistent cache
    try {
      final key = '${AppConstants.pokemonCachePrefix}$id';
      final jsonString = _prefs.getString(key);
      final timestamp = _prefs.getInt('${AppConstants.cacheTimePrefix}$id');

      if (jsonString != null && timestamp != null) {
        final age = DateTime.now().millisecondsSinceEpoch - timestamp;

        // Check if cache is still valid
        if (age < AppConstants.cacheExpiry.inMilliseconds) {
          final pokemon = Pokemon.fromJson(jsonDecode(jsonString));

          // Populate memory cache
          _memoryCache[id] = pokemon;

          return pokemon;
        } else {
          // Cache expired, remove it
          _removeCachedPokemon(id);
        }
      }
    } catch (e) {
      debugPrint('Cache retrieval error: $e');
    }

    return null;
  }

  /// Cache Pokemon list
  Future<void> cachePokemonList(List<Pokemon> pokemons) async {
    try {
      final jsonList = pokemons.map((p) => p.toJson()).toList();
      await _prefs.setString(
        AppConstants.pokemonListCacheKey,
        jsonEncode(jsonList),
      );
      await _prefs.setInt(
        '${AppConstants.cacheTimePrefix}list',
        DateTime.now().millisecondsSinceEpoch,
      );

      // Cache individually as well for quick access
      for (var pokemon in pokemons) {
        _memoryCache[pokemon.id] = pokemon;
      }
    } catch (e) {
      debugPrint('Cache list error: $e');
    }
  }

  /// Get cached Pokemon list
  List<Pokemon>? getCachedPokemonList() {
    try {
      final jsonString = _prefs.getString(AppConstants.pokemonListCacheKey);
      final timestamp = _prefs.getInt('${AppConstants.cacheTimePrefix}list');

      if (jsonString != null && timestamp != null) {
        final age = DateTime.now().millisecondsSinceEpoch - timestamp;

        // Check if cache is still valid
        if (age < AppConstants.cacheExpiry.inMilliseconds) {
          final List<dynamic> jsonList = jsonDecode(jsonString);
          final pokemons = jsonList
              .map((json) => Pokemon.fromJson(json))
              .toList();

          // Populate memory cache
          for (var pokemon in pokemons) {
            _memoryCache[pokemon.id] = pokemon;
          }

          return pokemons;
        } else {
          // Cache expired, remove it
          _prefs.remove(AppConstants.pokemonListCacheKey);
          _prefs.remove('${AppConstants.cacheTimePrefix}list');
        }
      }
    } catch (e) {

      debugPrint('Cache list retrieval error: $e');
    }

    return null;
  }

  /// Remove specific Pokemon from cache
  Future<void> _removeCachedPokemon(int id) async {
    _memoryCache.remove(id);
    await _prefs.remove('${AppConstants.pokemonCachePrefix}$id');
    await _prefs.remove('${AppConstants.cacheTimePrefix}$id');
  }

  /// Clear all Pokemon cache
  Future<void> clearCache() async {
    _memoryCache.clear();

    final keys = _prefs.getKeys().where(
      (key) =>
          key.startsWith(AppConstants.pokemonCachePrefix) ||
          key.startsWith(AppConstants.cacheTimePrefix) ||
          key == AppConstants.pokemonListCacheKey,
    );

    for (final key in keys) {
      await _prefs.remove(key);
    }
  }

  /// Clear memory cache only (keep disk cache)
  void clearMemoryCache() {
    _memoryCache.clear();
  }

  /// Get cache statistics for debugging
  Map<String, dynamic> getCacheStats() {
    return {
      'memoryCacheSize': _memoryCache.length,
      'diskCacheKeys': _prefs
          .getKeys()
          .where((key) => key.startsWith(AppConstants.pokemonCachePrefix))
          .length,
    };
  }
}
