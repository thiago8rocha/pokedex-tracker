import 'dart:convert';
import 'dart:developer';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _capturesKey = 'captures';

  // Retorna o Set de IDs capturados para uma Pokedex específica
  Future<Set<int>> getCaught(String pokedexId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('${_capturesKey}_$pokedexId');
      if (raw == null) return {};
      final List<dynamic> list = jsonDecode(raw);
      return list.map((e) => e as int).toSet();
    } catch (e) {
      log('Erro ao carregar capturas de $pokedexId: $e');
      return {};
    }
  }

  // Salva o Set de IDs capturados para uma Pokedex específica
  Future<void> saveCaught(String pokedexId, Set<int> caught) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '${_capturesKey}_$pokedexId',
        jsonEncode(caught.toList()),
      );
    } catch (e) {
      log('Erro ao salvar capturas de $pokedexId: $e');
    }
  }

  // Retorna quantos Pokémon foram capturados em uma Pokedex
  Future<int> getCaughtCount(String pokedexId) async {
    final caught = await getCaught(pokedexId);
    return caught.length;
  }

  // Limpa todos os dados do app
  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      log('Erro ao limpar dados: $e');
    }
  }
}