import 'package:equatable/equatable.dart';

class Pokemon extends Equatable {
  final int id;
  final String name;
  final String imageUrl;
  final List<String> types;
  final List<PokemonStat> stats;
  final int height;
  final int weight;
  final String? description;
  final List<String> abilities;
  final List<EvolutionStage> evolutionChain;

  const Pokemon({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.types,
    required this.stats,
    required this.height,
    required this.weight,
    this.description,
    this.abilities = const [],
    this.evolutionChain = const [],
  });

  /// Factory constructor with proper error handling
  /// Fixes potential null pointer exceptions
  factory Pokemon.fromJson(Map<String, dynamic> json) {
    try {
      // Safe type extraction
      final List<String> types = _extractTypes(json);
      final List<PokemonStat> stats = _extractStats(json);
      final String imageUrl = _extractImageUrl(json);
      final List<String> abilities = _extractAbilities(json);

      return Pokemon(
        id: json['id'] as int? ?? 0,
        name: json['name'] as String? ?? 'Unknown',
        imageUrl: imageUrl,
        types: types,
        stats: stats,
        height: json['height'] as int? ?? 0,
        weight: json['weight'] as int? ?? 0,
        abilities: abilities,
      );
    } catch (e) {
      throw FormatException(
        'Failed to parse Pokemon from JSON: $e',
        json.toString(),
      );
    }
  }

  static List<String> _extractTypes(Map<String, dynamic> json) {
    try {
      final typesList = json['types'] as List?;
      if (typesList == null) return [];

      return typesList
          .map((typeData) {
            final typeMap = typeData as Map<String, dynamic>?;
            final type = typeMap?['type'] as Map<String, dynamic>?;
            return type?['name'] as String?;
          })
          .whereType<String>()
          .toList();
    } catch (e) {
      return [];
    }
  }

  static List<PokemonStat> _extractStats(Map<String, dynamic> json) {
    try {
      final statsList = json['stats'] as List?;
      if (statsList == null) return [];

      return statsList
          .map((statData) {
            try {
              return PokemonStat.fromJson(statData as Map<String, dynamic>);
            } catch (e) {
              return null;
            }
          })
          .whereType<PokemonStat>()
          .toList();
    } catch (e) {
      return [];
    }
  }

  static String _extractImageUrl(Map<String, dynamic> json) {
    try {
      final sprites = json['sprites'] as Map<String, dynamic>?;
      if (sprites == null) return '';

      final other = sprites['other'] as Map<String, dynamic>?;
      final officialArtwork =
          other?['official-artwork'] as Map<String, dynamic>?;
      final officialUrl = officialArtwork?['front_default'] as String?;

      return officialUrl ?? sprites['front_default'] as String? ?? '';
    } catch (e) {
      return '';
    }
  }

  static List<String> _extractAbilities(Map<String, dynamic> json) {
    try {
      final abilitiesList = json['abilities'] as List?;
      if (abilitiesList == null) return [];

      return abilitiesList
          .map((abilityData) {
            final abilityMap = abilityData as Map<String, dynamic>?;
            final ability = abilityMap?['ability'] as Map<String, dynamic>?;
            return ability?['name'] as String?;
          })
          .whereType<String>()
          .toList();
    } catch (e) {
      return [];
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imageUrl': imageUrl,
      'types': types,
      'stats': stats.map((s) => s.toJson()).toList(),
      'height': height,
      'weight': weight,
      'description': description,
      'abilities': abilities,
    };
  }

  Pokemon copyWith({
    int? id,
    String? name,
    String? imageUrl,
    List<String>? types,
    List<PokemonStat>? stats,
    int? height,
    int? weight,
    String? description,
    List<String>? abilities,
    List<EvolutionStage>? evolutionChain,
  }) {
    return Pokemon(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      types: types ?? this.types,
      stats: stats ?? this.stats,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      description: description ?? this.description,
      abilities: abilities ?? this.abilities,
      evolutionChain: evolutionChain ?? this.evolutionChain,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    imageUrl,
    types,
    stats,
    height,
    weight,
    description,
    abilities,
    evolutionChain,
  ];

  @override
  String toString() => 'Pokemon(id: $id, name: $name)';
}

class PokemonStat extends Equatable {
  final String name;
  final int baseStat;

  const PokemonStat({required this.name, required this.baseStat});

  factory PokemonStat.fromJson(Map<String, dynamic> json) {
    return PokemonStat(
      name: json['stat']?['name'] as String? ?? 'unknown',
      baseStat: json['base_stat'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stat': {'name': name},
      'base_stat': baseStat,
    };
  }

  String get displayName {
    switch (name) {
      case 'hp':
        return 'HP';
      case 'attack':
        return 'Attack';
      case 'defense':
        return 'Defense';
      case 'special-attack':
        return 'Sp. Atk';
      case 'special-defense':
        return 'Sp. Def';
      case 'speed':
        return 'Speed';
      default:
        return name[0].toUpperCase() + name.substring(1);
    }
  }

  @override
  List<Object?> get props => [name, baseStat];
}

class PokemonListItem extends Equatable {
  final String name;
  final String url;
  final List<String> types;

  const PokemonListItem({
    required this.name,
    required this.url,
    this.types = const [],
  });

  factory PokemonListItem.fromJson(Map<String, dynamic> json) {
    return PokemonListItem(
      name: json['name'] as String? ?? 'Unknown',
      url: json['url'] as String? ?? '',
      types: json['types'] != null
          ? (json['types'] as List).map((t) => t.toString()).toList()
          : [],
    );
  }

  int get id {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      return int.parse(segments.last);
    } catch (e) {
      return 0;
    }
  }

  @override
  List<Object?> get props => [name, url, types];
}

class EvolutionStage extends Equatable {
  final int id;
  final String name;
  final String imageUrl;
  final int? minLevel;
  final String? trigger;

  const EvolutionStage({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.minLevel,
    this.trigger,
  });

  String get displayName {
    if (name.isEmpty) return 'Unknown';
    return name[0].toUpperCase() + name.substring(1);
  }

  String get evolutionInfo {
    if (minLevel != null) {
      return 'Level $minLevel';
    } else if (trigger != null && trigger!.isNotEmpty) {
      return trigger![0].toUpperCase() + trigger!.substring(1);
    }
    return 'Unknown';
  }

  @override
  List<Object?> get props => [id, name, imageUrl, minLevel, trigger];
}
