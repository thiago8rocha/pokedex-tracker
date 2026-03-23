import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pokedex_tracker/theme/type_colors.dart';
import 'package:pokedex_tracker/screens/detail/detail_shared.dart'
    show ptType, typeIconAsset, typeTextColor, neutralBg, kApiBase;
import 'package:pokedex_tracker/services/pokeapi_service.dart';
import 'package:pokedex_tracker/services/dex_bundle_service.dart';
import 'package:pokedex_tracker/services/pokedex_data_service.dart';
import 'package:pokedex_tracker/translations.dart';
import 'package:pokedex_tracker/screens/menu/moves_list_screen.dart' show MoveEntry;

class MoveDetailScreen extends StatefulWidget {
  final MoveEntry                             entry;
  final String                                activeGameId;
  final Map<String, Map<String, dynamic>>     detailCache;
  final Future<Map<String, dynamic>?> Function(String) loadDetail;

  const MoveDetailScreen({
    super.key,
    required this.entry,
    required this.activeGameId,
    required this.detailCache,
    required this.loadDetail,
  });

  @override
  State<MoveDetailScreen> createState() => _MoveDetailScreenState();
}

class _MoveDetailScreenState extends State<MoveDetailScreen> {
  Map<String, dynamic>? _detail;
  bool                  _loadingDetail   = true;
  List<_LearnEntry>     _learners        = [];
  bool                  _loadingLearners = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    // 1. Detalhes do move
    final detail = await widget.loadDetail(widget.entry.url);
    if (mounted) setState(() { _detail = detail; _loadingDetail = false; });

    // 2. Pokémon que aprendem o golpe no jogo ativo
    await _loadLearners();
  }

  Future<void> _loadLearners() async {
    final gameId  = widget.activeGameId;
    final sections = PokeApiService.pokedexSections[gameId] ?? [];

    // Coletar todos os IDs do jogo
    final allIds = <int>{};
    for (final s in sections) {
      final entries = await DexBundleService.instance.loadSection(s.apiName);
      if (entries != null) {
        for (final e in entries) allIds.add(e['speciesId']!);
      }
    }
    if (allIds.isEmpty) {
      if (mounted) setState(() => _loadingLearners = false);
      return;
    }

    // Verificar na PokeAPI qual Pokémon aprende esse move
    final moveNameEn = widget.entry.nameEn;
    final learners   = <_LearnEntry>[];

    // Buscar em lotes de 20 pokémon
    final ids = allIds.toList()..sort();
    for (int i = 0; i < ids.length; i += 20) {
      if (!mounted) return;
      final batch = ids.skip(i).take(20).toList();
      final results = await Future.wait(
          batch.map((id) => _checkLearner(id, moveNameEn)));
      for (final r in results) {
        if (r != null) learners.add(r);
      }
    }

    learners.sort((a, b) => a.id.compareTo(b.id));
    if (mounted) setState(() { _learners = learners; _loadingLearners = false; });
  }

  Future<_LearnEntry?> _checkLearner(int pokemonId, String moveNameEn) async {
    try {
      final res = await http.get(Uri.parse('$kApiBase/pokemon/$pokemonId'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final data  = jsonDecode(res.body) as Map<String, dynamic>;
      final moves = data['moves'] as List<dynamic>? ?? [];

      for (final m in moves) {
        if ((m['move']['name'] as String) != moveNameEn) continue;
        // Encontrou — pegar o método de aprendizado mais recente
        final vgDetails = m['version_group_details'] as List<dynamic>? ?? [];
        if (vgDetails.isEmpty) continue;
        final vg     = vgDetails.last;
        final method = vg['move_learn_method']['name'] as String;
        final level  = vg['level_learned_at'] as int;
        final name   = PokedexDataService.instance.getName(pokemonId);
        return _LearnEntry(
            id: pokemonId, name: name, method: method, level: level);
      }
    } catch (_) {}
    return null;
  }

  // ── Extrair flavor text ───────────────────────────────────────
  String _flavorText() {
    final flavors = _detail?['flavor_text_entries'] as List<dynamic>? ?? [];
    String ptDesc = '', enDesc = '';
    for (final e in flavors) {
      final lang = e['language']['name'] as String;
      if (lang == 'pt-BR' && ptDesc.isEmpty) {
        ptDesc = (e['flavor_text'] as String? ?? '').replaceAll('\n', ' ').trim();
      } else if (lang == 'en' && enDesc.isEmpty) {
        enDesc = (e['flavor_text'] as String? ?? '').replaceAll('\n', ' ').trim();
      }
    }
    return ptDesc.isNotEmpty ? ptDesc : enDesc;
  }

  // ── Extrair efeito ────────────────────────────────────────────
  String _effectText() {
    final effects = _detail?['effect_entries'] as List<dynamic>? ?? [];
    for (final e in effects) {
      if ((e['language']['name'] as String) == 'en') {
        final effect = e['effect'] as String? ?? '';
        return effect.replaceAll('\n', ' ').trim();
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final scheme   = Theme.of(context).colorScheme;
    final entry    = widget.entry;
    final namePt   = translateMove(entry.nameEn);
    final typeEn   = entry.typeEn;
    final typePt   = typeEn.isNotEmpty ? ptType(typeEn) : '';
    final typeColor = typeEn.isNotEmpty
        ? TypeColors.fromType(typePt)
        : scheme.surfaceContainerHighest;
    final catName  = entry.category;
    final flavor   = _flavorText();
    final effect   = _effectText();
    final cooldown = _detail?['ailment_chance'] as int?; // usar como proxy de cooldown se disponível
    final meta     = _detail?['meta'] as Map<String, dynamic>?;

    return Scaffold(
      appBar: AppBar(
        title: Text(namePt),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: _loadingDetail
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [

                // ── Tipo e categoria ──────────────────────────
                Row(children: [
                  if (typeEn.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: typeColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Image.asset(typeIconAsset(typeEn),
                            width: 16, height: 16,
                            errorBuilder: (_, __, ___) => const SizedBox()),
                        const SizedBox(width: 6),
                        Text(typePt, style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: typeTextColor(typeColor))),
                      ]),
                    ),
                  const SizedBox(width: 8),
                  if (catName.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _catColor(catName).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: _catColor(catName).withOpacity(0.4)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Image.asset('assets/categories/$catName.png',
                            width: 16, height: 16,
                            errorBuilder: (_, __, ___) => const SizedBox()),
                        const SizedBox(width: 6),
                        Text(
                          catName == 'physical' ? 'Ataque Físico'
                              : catName == 'special' ? 'Ataque Especial'
                              : 'Ataque de Status',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600,
                              color: _catColor(catName)),
                        ),
                      ]),
                    ),
                ]),

                const SizedBox(height: 16),

                // ── Stats ────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: neutralBg(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    _statBox(context, entry.power != null
                        ? '${entry.power}' : '—', 'Poder'),
                    _divider(),
                    _statBox(context, entry.accuracy != null
                        ? '${entry.accuracy}%' : '—', 'Precisão'),
                    _divider(),
                    _statBox(context, entry.pp != null
                        ? '${entry.pp}' : '—', 'PP'),
                    if (meta?['drain'] != null &&
                        (meta!['drain'] as int) != 0) ...[
                      _divider(),
                      _statBox(context, '${meta['drain']}%', 'Dreno'),
                    ],
                  ]),
                ),

                // ── Flavor text ───────────────────────────────
                if (flavor.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _SectionTitle('Descrição'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: neutralBg(context),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(flavor, style: TextStyle(
                        fontSize: 13, color: scheme.onSurface,
                        height: 1.5, fontStyle: FontStyle.italic)),
                  ),
                ],

                // ── Efeito ────────────────────────────────────
                if (effect.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _SectionTitle('Efeito'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: neutralBg(context),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(effect, style: TextStyle(
                        fontSize: 13, color: scheme.onSurface, height: 1.5)),
                  ),
                ],

                // ── Pokémon que aprendem ──────────────────────
                const SizedBox(height: 16),
                _SectionTitle('Pokémon que aprendem'),
                const SizedBox(height: 8),

                if (_loadingLearners)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator(
                        strokeWidth: 2)),
                  )
                else if (_learners.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('Nenhum Pokémon aprende este golpe no jogo ativo.',
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant)),
                  )
                else
                  ...(_learners.map((l) => _LearnerTile(
                      learner: l, scheme: scheme))),

                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _divider() => Container(
      width: 0.5, height: 48,
      color: Theme.of(context).colorScheme.outlineVariant);

  Widget _statBox(BuildContext ctx, String val, String lbl) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(children: [
        Text(val, style: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(lbl, style: TextStyle(
            fontSize: 10,
            color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
      ]),
    ),
  );

  Color _catColor(String cat) {
    if (cat == 'physical') return const Color(0xFFE24B4A);
    if (cat == 'special') return const Color(0xFF9C27B0);
    return const Color(0xFF888888);
  }
}

// ─── Widgets auxiliares ───────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700));
}

class _LearnerTile extends StatelessWidget {
  final _LearnEntry  learner;
  final ColorScheme  scheme;
  const _LearnerTile({required this.learner, required this.scheme});

  String get _methodLabel {
    switch (learner.method) {
      case 'level-up': return learner.level > 0 ? 'Nv. ${learner.level}' : 'Nv. 1';
      case 'machine':  return 'MT';
      case 'tutor':    return 'Tutor';
      case 'egg':      return 'Ovo';
      default:         return learner.method;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: scheme.outlineVariant, width: 0.5),
      ),
      child: Row(children: [
        Image.asset(
          'assets/sprites/artwork/${learner.id}.webp',
          width: 36, height: 36, fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => SizedBox(width: 36, height: 36,
              child: Icon(Icons.catching_pokemon, size: 20,
                  color: scheme.onSurfaceVariant.withOpacity(0.4))),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(learner.name,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(_methodLabel,
              style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

// ─── Modelo ───────────────────────────────────────────────────────

class _LearnEntry {
  final int    id;
  final String name;
  final String method;
  final int    level;
  const _LearnEntry({
    required this.id, required this.name,
    required this.method, required this.level,
  });
}
