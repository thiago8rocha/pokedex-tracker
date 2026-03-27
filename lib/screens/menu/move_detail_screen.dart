import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pokedex_tracker/theme/type_colors.dart';
import 'package:pokedex_tracker/models/pokemon.dart';
import 'package:pokedex_tracker/screens/detail/detail_shared.dart'
    show ptType, typeIconAsset, typeTextColor, neutralBg, kApiBase, PokeballLoader;
import 'package:pokedex_tracker/screens/detail/mainline_detail_screen.dart';
import 'package:pokedex_tracker/screens/detail/nacional_detail_screen.dart';
import 'package:pokedex_tracker/services/pokeapi_service.dart';
import 'package:pokedex_tracker/services/dex_bundle_service.dart';
import 'package:pokedex_tracker/services/pokedex_data_service.dart';
import 'package:pokedex_tracker/services/storage_service.dart';
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

  @override State<MoveDetailScreen> createState() => _MoveDetailScreenState();
}

class _MoveDetailScreenState extends State<MoveDetailScreen> {
  Map<String, dynamic>? _detail;
  bool                  _loadingDetail   = true;
  List<_LearnEntry>     _learners        = [];
  bool                  _loadingLearners = false; // lazy — não inicia sozinho
  bool                  _learnersLoaded  = false;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    final d = await widget.loadDetail(widget.entry.url);
    if (mounted) setState(() { _detail = d; _loadingDetail = false; });
  }

  // Só carrega ao usuário clicar no botão
  Future<void> _loadLearners() async {
    setState(() => _loadingLearners = true);

    final gameId   = widget.activeGameId;
    final sections = PokeApiService.pokedexSections[gameId] ?? [];

    final allIds = <int>{};
    for (final s in sections) {
      final entries = await DexBundleService.instance.loadSection(s.apiName);
      if (entries != null) {
        for (final e in entries) allIds.add(e['speciesId']!);
      }
    }
    if (allIds.isEmpty && gameId == 'nacional') {
      for (int i = 1; i <= 1025; i++) allIds.add(i);
    }

    final moveNameEn = widget.entry.nameEn;
    final learners   = <_LearnEntry>[];
    final ids        = allIds.toList()..sort();

    for (int i = 0; i < ids.length; i += 20) {
      if (!mounted) return;
      final batch   = ids.skip(i).take(20).toList();
      final results = await Future.wait(
          batch.map((id) => _checkLearner(id, moveNameEn)));
      for (final r in results) { if (r != null) learners.add(r); }
    }

    learners.sort((a, b) => a.id.compareTo(b.id));
    if (mounted) setState(() {
      _learners        = learners;
      _loadingLearners = false;
      _learnersLoaded  = true;
    });
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
        final vg     = (m['version_group_details'] as List).last;
        final method = vg['move_learn_method']['name'] as String;
        final level  = vg['level_learned_at'] as int;
        final name   = PokedexDataService.instance.getName(pokemonId);
        final types  = PokedexDataService.instance.getTypes(pokemonId);
        return _LearnEntry(id: pokemonId, name: name, method: method,
            level: level, types: types);
      }
    } catch (_) {}
    return null;
  }

  // ── Navegar para o detalhe do pokémon ─────────────────────────
  void _openPokemonDetail(BuildContext ctx, _LearnEntry l) async {
    // Construir Pokemon mínimo para a tela de detalhe
    final poke = Pokemon(
      id:            l.id,
      entryNumber:   l.id,
      name:          l.name,
      types:         l.types,
      baseHp:        0, baseAttack:    0, baseDefense: 0,
      baseSpAttack:  0, baseSpDefense: 0, baseSpeed:   0,
      spriteUrl: 'assets/sprites/artwork/${l.id}.webp',
      spritePixelUrl:  'assets/sprites/pixel/${l.id}.webp',
      spriteHomeUrl:   'assets/sprites/home/${l.id}.webp',
    );

    final isCaught = await StorageService().isCaught(widget.activeGameId, l.id);
    final isNacional = widget.activeGameId == 'nacional';

    if (!mounted) return;
    Navigator.push(ctx, MaterialPageRoute(
      builder: (_) => isNacional
          ? NacionalDetailScreen(
              pokemon: poke, caught: isCaught,
              pokedexId: 'nacional',
              onToggleCaught: () async {
                final cur = await StorageService().isCaught(widget.activeGameId, l.id);
                await StorageService().setCaught(widget.activeGameId, l.id, !cur);
              })
          : SwitchDetailScreen(
              pokemon: poke, caught: isCaught,
              pokedexId: widget.activeGameId,
              onToggleCaught: () async {
                final cur = await StorageService().isCaught(widget.activeGameId, l.id);
                await StorageService().setCaught(widget.activeGameId, l.id, !cur);
              }),
    ));
  }

  // ── Helpers ───────────────────────────────────────────────────
  String _flavorText() {
    if (widget.entry.flavor.isNotEmpty) return widget.entry.flavor;
    final flavors = _detail?['flavor_text_entries'] as List<dynamic>? ?? [];
    String pt = '', en = '';
    for (final e in flavors) {
      final lang = e['language']['name'] as String;
      if (lang == 'pt-BR' && pt.isEmpty)
        pt = (e['flavor_text'] as String? ?? '').replaceAll('\n', ' ').trim();
      else if (lang == 'en' && en.isEmpty)
        en = (e['flavor_text'] as String? ?? '').replaceAll('\n', ' ').trim();
    }
    return pt.isNotEmpty ? pt : en;
  }

  String _effectText() {
    final effects = _detail?['effect_entries'] as List<dynamic>? ?? [];
    if (widget.entry.effect.isNotEmpty) return widget.entry.effect;
    for (final e in effects) {
      if ((e['language']['name'] as String) == 'en') {
        return (e['effect'] as String? ?? '').replaceAll('\n', ' ').trim();
      }
    }
    return '';
  }

  Color _catColor(String cat) {
    if (cat == 'physical') return const Color(0xFFE24B4A);
    if (cat == 'special')  return const Color(0xFF9C27B0);
    return const Color(0xFF888888);
  }

  @override
  Widget build(BuildContext context) {
    final scheme  = Theme.of(context).colorScheme;
    final entry   = widget.entry;
    final namePt  = translateMove(entry.nameEn);
    final typeEn  = entry.typeEn;
    final typePt  = typeEn.isNotEmpty ? ptType(typeEn) : '';
    final typeColor = typeEn.isNotEmpty
        ? TypeColors.fromType(typePt) : scheme.surfaceContainerHighest;
    final catName = entry.category;
    final flavor  = _flavorText();
    final effect  = _effectText();

    return Scaffold(
      appBar: AppBar(
        title: Text(namePt),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: _loadingDetail
          ? Center(child: PokeballLoader())
          : ListView(padding: const EdgeInsets.all(16), children: [

              // ── Tipo e categoria ──────────────────────────────
              Row(children: [
                if (typeEn.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: typeColor, borderRadius: BorderRadius.circular(4)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Image.asset(typeIconAsset(typeEn), width: 16, height: 16,
                          errorBuilder: (_, __, ___) => const SizedBox()),
                      const SizedBox(width: 6),
                      Text(typePt, style: TextStyle(fontSize: 12,
                          fontWeight: FontWeight.w700, color: typeTextColor(typeColor))),
                    ]),
                  ),
                const SizedBox(width: 8),
                if (catName.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _catColor(catName).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: _catColor(catName).withOpacity(0.4))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Image.asset('assets/categories/$catName.png', width: 37, height: 16, fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const SizedBox()),
                      const SizedBox(width: 6),
                      Text(catName == 'physical' ? 'Ataque Físico'
                          : catName == 'special' ? 'Ataque Especial' : 'Ataque de Status',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                              color: _catColor(catName))),
                    ]),
                  ),
              ]),

              const SizedBox(height: 16),

              // ── Stats ──────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                    color: neutralBg(context),
                    borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  _statBox(context, entry.power    != null ? '${entry.power}'    : '—', 'Poder'),
                  _vDivider(),
                  _statBox(context, entry.accuracy != null ? '${entry.accuracy}%': '—', 'Precisão'),
                  _vDivider(),
                  _statBox(context, entry.pp       != null ? '${entry.pp}'       : '—', 'PP'),
                ]),
              ),

              // ── Descrição ──────────────────────────────────────
              if (flavor.isNotEmpty) ...[
                const SizedBox(height: 16),
                const _SectionTitle('Descrição'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: neutralBg(context),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(flavor, style: TextStyle(fontSize: 13,
                      color: scheme.onSurface, height: 1.5,
                      fontStyle: FontStyle.italic)),
                ),
              ],

              // ── Efeito ────────────────────────────────────────
              if (effect.isNotEmpty) ...[
                const SizedBox(height: 16),
                const _SectionTitle('Efeito'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: neutralBg(context),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(effect, style: TextStyle(fontSize: 13,
                      color: scheme.onSurface, height: 1.5)),
                ),
              ],

              // ── Pokémon que aprendem ───────────────────────────
              const SizedBox(height: 16),
              const _SectionTitle('Pokémon que aprendem'),
              const SizedBox(height: 8),

              if (!_learnersLoaded && !_loadingLearners)
                OutlinedButton.icon(
                  onPressed: _loadLearners,
                  icon: const Icon(Icons.catching_pokemon_outlined, size: 18),
                  label: const Text('Carregar Pokémon'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                  ),
                )
              else if (_loadingLearners)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: PokeballLoader.small()),
                )
              else if (_learners.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('Nenhum Pokémon aprende este golpe no jogo ativo.',
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                )
              else
                ...(_learners.map((l) => _LearnerTile(
                    learner: l, scheme: scheme,
                    onTap: () => _openPokemonDetail(context, l)))),

              const SizedBox(height: 32),
            ]),
    );
  }

  Widget _vDivider() => Container(width: 0.5, height: 52,
      color: Theme.of(context).colorScheme.outlineVariant);

  Widget _statBox(BuildContext ctx, String val, String lbl) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(children: [
        Text(val, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(lbl, style: TextStyle(fontSize: 10,
            color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
      ]),
    ),
  );
}

// ─── Widgets auxiliares ───────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override Widget build(BuildContext ctx) =>
      Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700));
}

class _LearnerTile extends StatelessWidget {
  final _LearnEntry  learner;
  final ColorScheme  scheme;
  final VoidCallback onTap;
  const _LearnerTile({required this.learner, required this.scheme, required this.onTap});

  String get _method {
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: scheme.outlineVariant, width: 0.5),
        ),
        child: Row(children: [
          Image.asset('assets/sprites/artwork/${learner.id}.webp',
              width: 36, height: 36, fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => SizedBox(width: 36, height: 36,
                  child: Icon(Icons.catching_pokemon, size: 20,
                      color: scheme.onSurfaceVariant.withOpacity(0.4)))),
          const SizedBox(width: 10),
          Expanded(child: Text(learner.name,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4)),
            child: Text(_method, style: TextStyle(fontSize: 10,
                color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, size: 14,
              color: scheme.onSurfaceVariant.withOpacity(0.5)),
        ]),
      ),
    );
  }
}

class _LearnEntry {
  final int         id;
  final String      name;
  final String      method;
  final int         level;
  final List<String> types;
  const _LearnEntry({required this.id, required this.name,
      required this.method, required this.level, required this.types});
}
