import 'dart:convert';
import 'package:http/http.dart' as http;

const String _kBase   = 'https://api.tcgdex.net/v2/en';
const String _kAssets = 'https://assets.tcgdex.net/en';

// Ordem de exibição — Promos sempre ao final
const List<String> kPocketSetOrder = [
  'A1', 'A1a',
  'A2', 'A2a', 'A2b',
  'A3', 'A3a', 'A3b',
  'A4', 'A4a', 'A4b',
  'B1', 'B1a',
  'B2', 'B2a', 'B2b',
  'P-A', 'P-B',
];

// Nomes PT-BR oficiais + cores temáticas
const Map<String, PocketSetMeta> kPocketSetMeta = {
  'A1':  PocketSetMeta(id: 'A1',  namePt: 'Dominação Genética',        releaseDate: '2024-10-30', color1: 0xFF2D0A5F, color2: 0xFF7A3000),
  'A1a': PocketSetMeta(id: 'A1a', namePt: 'Ilha Mítica',               releaseDate: '2024-12-17', color1: 0xFF0A3D1F, color2: 0xFF003D40),
  'A2':  PocketSetMeta(id: 'A2',  namePt: 'Embate do Tempo e Espaço',  releaseDate: '2025-01-30', color1: 0xFF062040, color2: 0xFF2D1A00),
  'A2a': PocketSetMeta(id: 'A2a', namePt: 'Luz Triunfante',            releaseDate: '2025-03-27', color1: 0xFF2D1A00, color2: 0xFF1A1800),
  'A2b': PocketSetMeta(id: 'A2b', namePt: 'Brilho Deslumbrante',       releaseDate: '2025-04-30', color1: 0xFF3D0020, color2: 0xFF003040),
  'A3':  PocketSetMeta(id: 'A3',  namePt: 'Guardiões Celestiais',      releaseDate: '2025-03-06', color1: 0xFF1F0040, color2: 0xFF3D1A00),
  'A3a': PocketSetMeta(id: 'A3a', namePt: 'Crise Extradimensional',    releaseDate: '2025-05-01', color1: 0xFF05073D, color2: 0xFF0D1F00),
  'A3b': PocketSetMeta(id: 'A3b', namePt: 'Bosque de Eevee',           releaseDate: '2025-05-29', color1: 0xFF0A2E0A, color2: 0xFF280040),
  'A4':  PocketSetMeta(id: 'A4',  namePt: 'Sabedoria do Mar e do Céu', releaseDate: '2025-07-03', color1: 0xFF002040, color2: 0xFF003035),
  'A4a': PocketSetMeta(id: 'A4a', namePt: 'Fontes Isoladas',           releaseDate: '2025-08-21', color1: 0xFF062010, color2: 0xFF002035),
  'A4b': PocketSetMeta(id: 'A4b', namePt: 'Pack Deluxe ex',            releaseDate: '2025-09-18', color1: 0xFF3D1000, color2: 0xFF1A1400),
  'B1':  PocketSetMeta(id: 'B1',  namePt: 'Ascensão Mega',             releaseDate: '2025-10-16', color1: 0xFF2D0010, color2: 0xFF190030),
  'B1a': PocketSetMeta(id: 'B1a', namePt: 'Chamas Carmesim',           releaseDate: '2025-12-17', color1: 0xFF3D0000, color2: 0xFF3D1800),
  'B2':  PocketSetMeta(id: 'B2',  namePt: 'Desfile Onírico',           releaseDate: '2026-01-29', color1: 0xFF1A0030, color2: 0xFF2D0020),
  'B2a': PocketSetMeta(id: 'B2a', namePt: 'Maravilhas de Paldea',      releaseDate: '2026-02-26', color1: 0xFF2D0800, color2: 0xFF062010),
  'B2b': PocketSetMeta(id: 'B2b', namePt: 'Mega Brilho',               releaseDate: '2026-03-26', color1: 0xFF001040, color2: 0xFF2D0020),
  'P-A': PocketSetMeta(id: 'P-A', namePt: 'Promos-A',                  releaseDate: '2024-10-30', color1: 0xFF0D1015, color2: 0xFF101518),
  'P-B': PocketSetMeta(id: 'P-B', namePt: 'Promos-B',                  releaseDate: '2025-10-16', color1: 0xFF080A0A, color2: 0xFF0D1010),
};

class PocketSetMeta {
  final String id;
  final String namePt;
  final String releaseDate;
  final int    color1;
  final int    color2;
  const PocketSetMeta({required this.id, required this.namePt,
      required this.releaseDate, required this.color1, required this.color2});
}

// ─── MODELOS ──────────────────────────────────────────────────────

class PocketSet {
  final String               id;
  final String               name;
  final String?              logoUrl;
  final String?              releaseDate;
  final int                  totalCards;
  final List<PocketCardBrief>  cards;

  const PocketSet({
    required this.id, required this.name, this.logoUrl,
    this.releaseDate, required this.totalCards, required this.cards,
  });

  /// URL da imagem da primeira carta do set — usada como imagem do pacote no hub
  /// Padrão TCGdex: https://assets.tcgdex.net/en/tcgp/{setId}/1/high.webp
  String get packCardImageUrl => '$_kAssets/tcgp/$id/1/high.webp';

  factory PocketSet.fromJson(Map<String, dynamic> json, {String? overrideName}) {
    final cardCount = json['cardCount'] as Map<String, dynamic>?;
    final cardList  = (json['cards']   as List<dynamic>?) ?? [];

    final cards = cardList
        .map((c) => PocketCardBrief.fromJson(c as Map<String, dynamic>))
        .toList()
      ..sort((a, b) {
          final an = int.tryParse(a.localId) ?? 9999;
          final bn = int.tryParse(b.localId) ?? 9999;
          return an.compareTo(bn);
        });

    return PocketSet(
      id:          json['id'] as String,
      name:        overrideName ?? (json['name'] as String),
      logoUrl:     json['logo'] as String?,
      releaseDate: json['releaseDate'] as String?,
      totalCards:  cardCount?['official'] as int? ?? cards.length,
      cards:       cards,
    );
  }
}

class PocketCardBrief {
  final String  id; final String localId; final String name;
  final String? imageUrlLow; final String? rarity;
  const PocketCardBrief({required this.id, required this.localId,
      required this.name, this.imageUrlLow, this.rarity});
  factory PocketCardBrief.fromJson(Map<String, dynamic> json) {
    final raw = json['image'] as String?;
    return PocketCardBrief(
      id: json['id'] as String, localId: json['localId']?.toString() ?? '',
      name: json['name'] as String,
      imageUrlLow: raw != null ? '$raw/low.webp' : null,
      rarity: json['rarity'] as String?,
    );
  }
}

class PocketAttack {
  final String name; final String? damage; final String? effect; final List<String> cost;
  const PocketAttack({required this.name, this.damage, this.effect, required this.cost});
  factory PocketAttack.fromJson(Map<String, dynamic> json) {
    final c = (json['cost'] as List<dynamic>?) ?? [];
    return PocketAttack(name: json['name'] as String, damage: json['damage']?.toString(),
        effect: json['effect'] as String?, cost: c.map((e) => e.toString()).toList());
  }
}

class PocketAbility {
  final String name; final String? effect; final String? type;
  const PocketAbility({required this.name, this.effect, this.type});
  factory PocketAbility.fromJson(Map<String, dynamic> json) => PocketAbility(
      name: json['name'] as String, effect: json['effect'] as String?,
      type: json['type'] as String?);
}

class PocketCardDetail {
  final String id; final String localId; final String name;
  final String? imageUrlHigh; final String? rarity; final String? category;
  final int? hp; final List<String> types; final String? stage;
  final String? evolveFrom; final String? description;
  final List<PocketAttack> attacks; final List<PocketAbility> abilities;
  final String? weaknessType; final int? weaknessValue; final int? retreat;
  final String? trainerEffect; final String? trainerType;

  const PocketCardDetail({
    required this.id, required this.localId, required this.name,
    this.imageUrlHigh, this.rarity, this.category, this.hp,
    required this.types, this.stage, this.evolveFrom, this.description,
    required this.attacks, required this.abilities,
    this.weaknessType, this.weaknessValue, this.retreat,
    this.trainerEffect, this.trainerType,
  });

  factory PocketCardDetail.fromJson(Map<String, dynamic> json) {
    final raw        = json['image'] as String?;
    final typesRaw   = (json['types']     as List<dynamic>?) ?? [];
    final attacksRaw = (json['attacks']   as List<dynamic>?) ?? [];
    final abilitRaw  = (json['abilities'] as List<dynamic>?) ?? [];
    final weaknesses = (json['weaknesses'] as List<dynamic>?) ?? [];
    String? weakType; int? weakVal;
    if (weaknesses.isNotEmpty) {
      final w = weaknesses.first as Map<String, dynamic>;
      weakType = w['type'] as String?; weakVal = w['value'] as int?;
    }
    return PocketCardDetail(
      id: json['id'] as String, localId: json['localId']?.toString() ?? '',
      name: json['name'] as String,
      imageUrlHigh: raw != null ? '$raw/high.webp' : null,
      rarity: json['rarity'] as String?, category: json['category'] as String?,
      hp: json['hp'] as int?,
      types: typesRaw.map((e) => e.toString()).toList(),
      stage: json['stage'] as String?, evolveFrom: json['evolveFrom'] as String?,
      description: json['description'] as String?,
      attacks:   attacksRaw.map((a) => PocketAttack.fromJson(a  as Map<String, dynamic>)).toList(),
      abilities: abilitRaw.map((a)  => PocketAbility.fromJson(a as Map<String, dynamic>)).toList(),
      weaknessType: weakType, weaknessValue: weakVal, retreat: json['retreat'] as int?,
      trainerEffect: json['effect'] as String?, trainerType: json['trainerType'] as String?,
    );
  }
}

// ─── SERVIÇO ──────────────────────────────────────────────────────

class TcgPocketService {
  static const Duration _timeout = Duration(seconds: 12);
  static List<PocketSet>?                    _seriesCache;
  static final Map<String, PocketSet>        _setCache  = {};
  static final Map<String, PocketCardDetail> _cardCache = {};

  static Future<List<PocketSet>> fetchSeries() async {
    if (_seriesCache != null) return _seriesCache!;
    try {
      final res = await http.get(Uri.parse('$_kBase/series/tcgp')).timeout(_timeout);
      if (res.statusCode != 200) return _fallbackSeries();

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final raw  = (json['sets'] as List<dynamic>?) ?? [];

      final seen = <String>{};
      final sets = <PocketSet>[];
      for (final s in raw) {
        final map = s as Map<String, dynamic>;
        final id  = map['id'] as String;
        if (!seen.add(id)) continue;
        final meta = kPocketSetMeta[id];
        sets.add(PocketSet(
          id: id, name: meta?.namePt ?? (map['name'] as String),
          logoUrl: map['logo'] as String?,
          releaseDate: meta?.releaseDate, totalCards: 0, cards: [],
        ));
      }

      // Garantir todos os sets conhecidos mesmo que a API não os retorne
      for (final id in kPocketSetOrder) {
        if (!seen.contains(id) && kPocketSetMeta.containsKey(id)) {
          final m = kPocketSetMeta[id]!;
          sets.add(PocketSet(id: m.id, name: m.namePt,
              releaseDate: m.releaseDate, totalCards: 0, cards: []));
        }
      }

      _sortSets(sets);
      _seriesCache = sets;
      return sets;
    } catch (_) {
      return _fallbackSeries();
    }
  }

  static void _sortSets(List<PocketSet> sets) {
    sets.sort((a, b) {
      final aPromo = a.id.startsWith('P-');
      final bPromo = b.id.startsWith('P-');
      if (aPromo && !bPromo) return 1;
      if (!aPromo && bPromo) return -1;
      int ai = kPocketSetOrder.indexOf(a.id);
      int bi = kPocketSetOrder.indexOf(b.id);
      if (ai == -1) ai = 990;
      if (bi == -1) bi = 990;
      return ai.compareTo(bi);
    });
  }

  static List<PocketSet> _fallbackSeries() => kPocketSetOrder
      .where(kPocketSetMeta.containsKey)
      .map((id) { final m = kPocketSetMeta[id]!;
        return PocketSet(id: m.id, name: m.namePt,
            releaseDate: m.releaseDate, totalCards: 0, cards: []); })
      .toList();

  static Future<PocketSet?> fetchSet(String setId) async {
    if (_setCache.containsKey(setId)) return _setCache[setId];
    try {
      final res = await http.get(Uri.parse('$_kBase/sets/$setId')).timeout(_timeout);
      if (res.statusCode != 200) return null;
      final set = PocketSet.fromJson(jsonDecode(res.body) as Map<String, dynamic>,
          overrideName: kPocketSetMeta[setId]?.namePt);
      _setCache[setId] = set;
      return set;
    } catch (_) { return null; }
  }

  /// Busca detalhes de uma carta via /sets/{setId}/{localId}
  /// cardId é usado apenas como chave de cache.
  static Future<PocketCardDetail?> fetchCard(
    String cardId, {
    required String setId,
    required String localId,
  }) async {
    if (_cardCache.containsKey(cardId)) return _cardCache[cardId];
    try {
      final url = '$_kBase/sets/$setId/$localId';
      final res = await http.get(Uri.parse(url)).timeout(_timeout);
      if (res.statusCode != 200) return null;
      final card = PocketCardDetail.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
      _cardCache[cardId] = card;
      return card;
    } catch (_) { return null; }
  }

  static void clearCache() {
    _seriesCache = null; _setCache.clear(); _cardCache.clear();
  }
}
