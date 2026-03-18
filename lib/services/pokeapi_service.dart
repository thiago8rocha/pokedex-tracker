import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:pokedex_tracker/models/pokemon.dart';

class PokeApiService {
  static const String _baseUrl = 'https://pokeapi.co/api/v2';

  Future<Pokemon?> fetchPokemon(int id) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/pokemon/$id'));
      if (response.statusCode == 200) {
        return Pokemon.fromJson(jsonDecode(response.body));
      }
      log('Erro ao buscar Pokémon $id: ${response.statusCode}');
      return null;
    } catch (e) {
      log('Exceção ao buscar Pokémon $id: $e');
      return null;
    }
  }

  Future<List<Pokemon>> fetchPokemonList({
    int offset = 0,
    int limit = 20,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/pokemon?offset=$offset&limit=$limit'),
      );
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      final results = data['results'] as List;

      final pokemons = await Future.wait(
        results.map((r) async {
          final detail = await http.get(Uri.parse(r['url'] as String));
          if (detail.statusCode == 200) {
            return Pokemon.fromJson(jsonDecode(detail.body));
          }
          return null;
        }),
      );

      return pokemons.whereType<Pokemon>().toList();
    } catch (e) {
      log('Exceção ao buscar lista: $e');
      return [];
    }
  }
}