import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/pokemon.dart';
import '../core/errors/exceptions.dart';
import '../core/constants/app_constants.dart';

export '../models/pokemon.dart' show EvolutionStage;

class PaginatedPokemonResponse {
  final List<PokemonListItem> results;
  final int totalCount;
  final bool hasMore;

  PaginatedPokemonResponse({
    required this.results,
    required this.totalCount,
    required this.hasMore,
  });
}

/// API Service - Single Responsibility: Handle all Pokemon API calls
/// Fixes Issue #8: Proper API call handling with error management
/// Fixes Issue #14: Query parameter issues resolved with proper URI building
class ApiService {
  final http.Client _client;

  ApiService(this._client);

  /// Fetch paginated Pokemon list with proper validation
  /// FIX #8: Comprehensive error handling for API calls
  /// FIX #14: Correct query parameter handling using Uri.replace
  Future<PaginatedPokemonResponse> fetchPokemonList({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      // Validate parameters (Issue #14 fix)
      if (offset < 0 || limit <= 0 || limit > AppConstants.maxPageSize) {
        throw ValidationException(
          'Offset must be >= 0 and limit must be between 1 and ${AppConstants.maxPageSize}',
        );
      }

      // Build URI with proper query parameters (Issue #14 fix)
      final url = Uri.parse('${AppConstants.apiBaseUrl}/pokemon').replace(
        queryParameters: {
          'offset': offset.toString(),
          'limit': limit.toString(),
        },
      );

      final response = await _client
          .get(url)
          .timeout(
            AppConstants.apiTimeout,
            onTimeout: () => throw NetworkException(
              'Request timed out after ${AppConstants.apiTimeout.inSeconds}s',
              code: 'TIMEOUT',
            ),
          );

      if (response.statusCode != 200) {
        throw NetworkException(
          'Failed to load pokemon list: HTTP ${response.statusCode}',
          code: response.statusCode.toString(),
        );
      }

      final Map<String, dynamic> data = json.decode(response.body);
      final int totalCount = data['count'];
      final List<dynamic> results = data['results'];

      final pokemonListItems = <PokemonListItem>[];

      for (var item in results) {
        final pokemonUrl = item['url'] as String;
        try {
          final detailResponse = await _client.get(Uri.parse(pokemonUrl));
          if (detailResponse.statusCode == 200) {
            final detailData = json.decode(detailResponse.body);
            final types = (detailData['types'] as List)
                .map((typeData) => typeData['type']['name'] as String)
                .toList();

            pokemonListItems.add(
              PokemonListItem(
                name: item['name'],
                url: item['url'],
                types: types,
              ),
            );
          }
        } catch (e) {
          pokemonListItems.add(PokemonListItem.fromJson(item));
        }
      }

      final String? nextUrl = data['next'];

      return PaginatedPokemonResponse(
        results: pokemonListItems,
        totalCount: totalCount,
        hasMore: nextUrl != null,
      );
    } catch (e) {
      throw NetworkException('Failed to load pokemon list: $e');
    }
  }

  /// Search Pokemon by name or ID
  Future<List<PokemonListItem>> searchPokemon(
    String query, {
    int limit = 20,
  }) async {
    final lowerQuery = query.toLowerCase().trim();

    if (lowerQuery.isEmpty) {
      return [];
    }

    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/pokemon/$lowerQuery');
      final response = await _client.get(url).timeout(AppConstants.apiTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final types = (data['types'] as List)
            .map((typeData) => typeData['type']['name'] as String)
            .toList();

        return [
          PokemonListItem(
            name: data['name'],
            url: '${AppConstants.apiBaseUrl}/pokemon/${data['id']}/',
            types: types,
          ),
        ];
      }
    } catch (_) {
      // If direct search fails, fall through to list search
    }

    _allPokemons ??= await _fetchAllPokemons();

    final filtered = _allPokemons!
        .where((pokemon) => pokemon.name.toLowerCase().contains(lowerQuery))
        .take(limit)
        .toList();

    return filtered;
  }

  List<PokemonListItem>? _allPokemons;

  Future<List<PokemonListItem>> _fetchAllPokemons() async {
    final url = Uri.parse(
      '${AppConstants.apiBaseUrl}/pokemon?limit=2000&offset=0',
    );

    final response = await _client.get(url).timeout(AppConstants.apiTimeout);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final List<dynamic> results = data['results'];

      return results
          .map(
            (json) => PokemonListItem(
              name: json['name'],
              url: json['url'],
              types: [],
            ),
          )
          .toList();
    } else {
      throw NetworkException(
        'Failed to load pokemon list: ${response.statusCode}',
      );
    }
  }

  /// Fetch Pokemon details by ID or name
  Future<Pokemon> fetchPokemonDetails(dynamic idOrName) async {
    final data = await fetchPokemonDetailsRaw(idOrName);
    return Pokemon.fromJson(data);
  }

  Future<Map<String, dynamic>> fetchPokemonDetailsRaw(dynamic idOrName) async {
    final url = Uri.parse('${AppConstants.apiBaseUrl}/pokemon/$idOrName');

    final response = await _client.get(url).timeout(AppConstants.apiTimeout);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw NetworkException(
        'Failed to load pokemon details: ${response.statusCode}',
      );
    }
  }

  /// Fetch Pokemon description from species data
  Future<String?> fetchPokemonDescription(int pokemonId) async {
    try {
      final url = Uri.parse(
        '${AppConstants.apiBaseUrl}/pokemon-species/$pokemonId',
      );
      final response = await _client.get(url).timeout(AppConstants.apiTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final flavorTextEntries = data['flavor_text_entries'] as List;

        for (var entry in flavorTextEntries) {
          if (entry['language']['name'] == 'en') {
            String text = entry['flavor_text'];
            text = text.replaceAll('\n', ' ').replaceAll('\f', ' ');
            return text;
          }
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Fetch evolution chain for a Pokemon
  /// FIX #10: Proper error handling for evolution chain
  Future<List<EvolutionStage>> fetchEvolutionChain(int pokemonId) async {
    try {
      final speciesUrl = Uri.parse(
        '${AppConstants.apiBaseUrl}/pokemon-species/$pokemonId',
      );
      final speciesResponse = await _client
          .get(speciesUrl)
          .timeout(AppConstants.apiTimeout);

      if (speciesResponse.statusCode != 200) {
        return [];
      }

      final speciesData = json.decode(speciesResponse.body);
      final evolutionChainUrl = speciesData['evolution_chain']['url'] as String;

      final evolutionsResponse = await _client
          .get(Uri.parse(evolutionChainUrl))
          .timeout(AppConstants.apiTimeout);

      if (evolutionsResponse.statusCode != 200) {
        return [];
      }

      final evolutionsData = json.decode(evolutionsResponse.body);
      final chain = evolutionsData['chain'];

      List<EvolutionStage> stages = [];
      _parseEvolutionChain(chain, stages);

      return stages;
    } catch (e) {
      return [];
    }
  }

  /// Parse evolution chain recursively
  void _parseEvolutionChain(
    Map<String, dynamic> chain,
    List<EvolutionStage> stages,
  ) {
    final species = chain['species']['name'] as String;
    final speciesUrl = chain['species']['url'] as String;

    final uri = Uri.parse(speciesUrl);
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    final id = int.parse(segments.last);

    int? minLevel;
    String? trigger;

    final evolutionDetails = chain['evolution_details'] as List;
    if (evolutionDetails.isNotEmpty) {
      final details = evolutionDetails[0];
      minLevel = details['min_level'];
      trigger = details['trigger']['name'];
    }

    final imageUrl = '${AppConstants.officialArtworkBaseUrl}/$id.png';

    stages.add(
      EvolutionStage(
        name: species,
        id: id,
        imageUrl: imageUrl,
        minLevel: minLevel,
        trigger: trigger,
      ),
    );

    final evolvesTo = chain['evolves_to'] as List;
    for (var evolution in evolvesTo) {
      _parseEvolutionChain(evolution, stages);
    }
  }
}
