/// Application constants
/// Following Single Responsibility Principle - separate concerns
class AppConstants {
  AppConstants._(); // Private constructor to prevent instantiation

  // API Configuration
  static const String apiBaseUrl = 'https://pokeapi.co/api/v2';
  static const Duration apiTimeout = Duration(seconds: 30);
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Cache Configuration
  static const Duration cacheExpiry = Duration(hours: 24);
  static const String pokemonCachePrefix = 'pokemon_';
  static const String pokemonListCacheKey = 'pokemon_list';
  static const String cacheTimePrefix = 'cache_time_';

  // Firebase Collections
  static const String usersCollection = 'users';
  static const String favoritesField = 'favoritePokemonIds';

  // Audio Assets
  static const String themeMusicPath = 'audio/pokemon_theme.mp3';
  static const String evolutionSoundPath = 'audio/evolution.mp3';
  static const String clickSoundPath = 'audio/click.mp3';

  // Image URLs
  static const String officialArtworkBaseUrl =
      'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork';

  // Validation
  static const int minPasswordLength = 6;
  static const int maxPasswordLength = 128;
}
