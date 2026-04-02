import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dexcurator/theme/type_colors.dart';
import 'package:dexcurator/screens/detail/detail_shared.dart'
    show ptType, typeIconAsset, calculateWeaknesses, PokeballLoader;
import 'package:dexcurator/services/dex_bundle_service.dart';
import 'package:dexcurator/services/pokeapi_service.dart';
import 'package:dexcurator/services/pokedex_data_service.dart';
import 'package:dexcurator/services/teams_storage_service.dart';

class TeamBuilderScreen extends StatefulWidget {
  final Map<String, dynamic> activeGame;
  final PokemonTeam?         existing;
  const TeamBuilderScreen({super.key,
      required this.activeGame, this.existing});
  @override State<TeamBuilderScreen> createState() => _TeamBuilderScreenState();
}

class _TeamBuilderScreenState extends State<TeamBuilderScreen> {
  List<int>   _members   = [];
  List<int>   _available = [];
  List<int>   _filtered  = [];
  bool        _loading   = true;
  String      _search    = '';
  String?     _typeFilter;
  late TextEditingController _nameCtrl;
  late TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _members  = List.from(widget.existing?.members ?? []);
    _nameCtrl = TextEditingController(
        text: widget.existing?.name ?? 'Meu Time');
    _searchCtrl = TextEditingController();
    _loadAvailable();
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _searchCtrl.dispose(); super.dispose();
  }

  Future<void> _loadAvailable() async {
    final sections = PokeApiService.pokedexSections[widget.activeGame['id']] ?? [];
    final ids      = <int>{};
    for (final s in sections) {
      final entries = await DexBundleService.instance.loadSection(s.apiName);
      if (entries != null) for (final e in entries) ids.add(e['speciesId']!);
    }
    if (ids.isEmpty) for (int i = 1; i <= 1025; i++) ids.add(i);
    final sorted = ids.toList()..sort();
    if (mounted) setState(() {
      _available = sorted;
      _applyFilters();
      _loading   = false;
    });
  }

  void _applyFilters() {
    var list = _available;
    if (_typeFilter != null) {
      list = list.where((id) {
        final types = PokedexDataService.instance.getTypes(id);
        return types.contains(_typeFilter);
      }).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((id) =>
          PokedexDataService.instance.getName(id).toLowerCase().contains(q) ||
          id.toString() == q).toList();
    }
    _filtered = list;
  }

  void _toggle(int id) {
    setState(() {
      if (_members.contains(id)) {
        _members.remove(id);
      } else if (_members.length < 6) {
        _members.add(id);
      }
    });
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) { _nameCtrl.text = 'Meu Time'; return; }
    if (_members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Adicione pelo menos 1 Pokémon.')));
      return;
    }

    final gameId   = widget.activeGame['id'] as String;
    final gameName = widget.activeGame['name'] as String;

    // Se editando, reutilizar ID; se novo, verificar limite
    if (widget.existing == null) {
      final canSave = await TeamsStorageService.instance.canSave(gameId);
      if (!canSave && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
            'Limite de ${TeamsStorageService.maxPerGame} times por jogo atingido.')));
        return;
      }
    }

    final team = PokemonTeam(
      id:       widget.existing?.id ?? TeamsStorageService.newId(),
      gameId:   gameId,
      gameName: gameName,
      name:     name,
      members:  List.from(_members),
    );
    await TeamsStorageService.instance.save(team);
    if (mounted) Navigator.pop(context);
  }

  void _showTypeFilter() async {
    final all = ['normal','fire','water','electric','grass','ice','fighting',
        'poison','ground','flying','psychic','bug','rock','ghost',
        'dragon','dark','steel','fairy'];

    final result = await showModalBottomSheet<String?>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _TypeFilterSheet(selected: _typeFilter, types: all),
    );
    if (mounted) setState(() { _typeFilter = result; _applyFilters(); });
  }

  @override
  Widget build(BuildContext context) {
    final scheme  = Theme.of(context).colorScheme;
    final title   = widget.existing == null ? 'Criar Time' : 'Editar Time';
    final hasFilter = _typeFilter != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          Badge(isLabelVisible: hasFilter,
            child: IconButton(icon: const Icon(Icons.filter_list_outlined),
                onPressed: _showTypeFilter)),
          TextButton(onPressed: _save,
              child: const Text('Salvar',
                  style: TextStyle(fontWeight: FontWeight.w700))),
        ],
      ),
      body: Column(children: [

        // Nome do time
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: 'Nome do time',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              isDense: true,
            ),
          ),
        ),

        // Time atual (6 slots)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(children: List.generate(6, (i) {
            final filled = i < _members.length;
            return Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: GestureDetector(
                onTap: filled ? () => _toggle(_members[i]) : null,
                child: AspectRatio(aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: filled
                          ? scheme.primaryContainer.withOpacity(0.4)
                          : scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: filled ? scheme.primary : scheme.outlineVariant,
                          width: filled ? 1.5 : 0.5)),
                    child: filled
                        ? Stack(children: [
                            Positioned.fill(child: Image.asset(
                                'assets/sprites/artwork/${_members[i]}.webp',
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) =>
                                    Icon(Icons.catching_pokemon, size: 20,
                                        color: scheme.onSurfaceVariant))),
                            Positioned(top: 2, right: 2,
                                child: Icon(Icons.remove_circle,
                                    size: 14, color: scheme.error)),
                          ])
                        : Icon(Icons.add, size: 18,
                            color: scheme.onSurfaceVariant.withOpacity(0.3)),
                  ),
                ),
              ),
            ));
          })),
        ),

        // Info slots
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(children: [
            Text('${_members.length}/6 Pokémon',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            const Spacer(),
            if (_members.length >= 2)
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => _QuickCoverageSheet(members: _members))),
                child: Row(children: [
                  Icon(Icons.shield_outlined, size: 12,
                      color: scheme.primary),
                  const SizedBox(width: 3),
                  Text('ver cobertura',
                      style: TextStyle(fontSize: 11, color: scheme.primary)),
                ]),
              ),
          ]),
        ),

        const Divider(height: 1),

        // Busca
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() { _search = v; _applyFilters(); }),
            decoration: InputDecoration(
              hintText: 'Buscar Pokémon...',
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: scheme.outlineVariant)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: scheme.outlineVariant)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
          ),
        ),

        if (hasFilter)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(ptType(_typeFilter!),
                      style: TextStyle(fontSize: 11,
                          color: scheme.onPrimaryContainer)),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => setState(() { _typeFilter = null; _applyFilters(); }),
                    child: Icon(Icons.close, size: 13,
                        color: scheme.onPrimaryContainer)),
                ]),
              ),
            ]),
          ),

        // Grid de pokémon
        Expanded(
          child: _loading
              ? Center(child: PokeballLoader())
              : _filtered.isEmpty
                  ? Center(child: Text('Nenhum Pokémon encontrado.',
                      style: TextStyle(color: scheme.onSurfaceVariant)))
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3, childAspectRatio: 0.85,
                          crossAxisSpacing: 8, mainAxisSpacing: 8),
                      itemCount: _filtered.length,
                      itemBuilder: (ctx, i) {
                        final id      = _filtered[i];
                        final name    = PokedexDataService.instance.getName(id);
                        final types   = PokedexDataService.instance.getTypes(id);
                        final inTeam  = _members.contains(id);
                        final full    = _members.length >= 6 && !inTeam;
                        return _PokemonGridCell(
                          id: id, name: name, types: types,
                          inTeam: inTeam, disabled: full,
                          onTap: () => _toggle(id),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}

// ─── Célula do grid ───────────────────────────────────────────────
class _PokemonGridCell extends StatelessWidget {
  final int id; final String name; final List<String> types;
  final bool inTeam, disabled; final VoidCallback onTap;
  const _PokemonGridCell({required this.id, required this.name,
      required this.types, required this.inTeam,
      required this.disabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final typeColor = types.isNotEmpty
        ? TypeColors.fromType(ptType(types[0])) : scheme.surfaceContainerHighest;

    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: inTeam
              ? typeColor.withOpacity(0.18)
              : disabled
                  ? scheme.surfaceContainer
                  : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: inTeam ? typeColor : scheme.outlineVariant,
              width: inTeam ? 2 : 0.5)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(flex: 3, child: Image.asset(
                'assets/sprites/artwork/$id.webp',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(Icons.catching_pokemon,
                    size: 32, color: scheme.onSurfaceVariant.withOpacity(0.4)))),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
              child: Column(children: [
                Text(name, style: TextStyle(fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: disabled ? scheme.onSurfaceVariant.withOpacity(0.4)
                        : scheme.onSurface),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (final t in types.take(2))
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Image.asset(typeIconAsset(t),
                          width: 10, height: 10,
                          errorBuilder: (_, __, ___) => const SizedBox()),
                    ),
                ]),
              ]),
            ),
            if (inTeam)
              const Positioned(child: SizedBox()),
          ],
        ),
      ),
    );
  }
}

// ─── Filtro de tipo ───────────────────────────────────────────────
class _TypeFilterSheet extends StatelessWidget {
  final String? selected; final List<String> types;
  const _TypeFilterSheet({required this.selected, required this.types});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Filtrar por tipo',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const Spacer(),
          if (selected != null)
            TextButton(onPressed: () => Navigator.pop(context, null),
                child: const Text('Limpar')),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 6, runSpacing: 6,
          children: types.map((t) {
            final sel = selected == t;
            final tc  = TypeColors.fromType(ptType(t));
            return GestureDetector(
              onTap: () => Navigator.pop(context, t),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: sel ? tc : tc.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: sel ? tc : tc.withOpacity(0.35),
                      width: sel ? 1.5 : 0.5)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Image.asset(typeIconAsset(t), width: 12, height: 12,
                      errorBuilder: (_, __, ___) => const SizedBox()),
                  const SizedBox(width: 4),
                  Text(ptType(t), style: TextStyle(fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: sel ? Colors.white : tc)),
                ]),
              ),
            );
          }).toList()),
      ]),
    );
  }
}

// ─── Cobertura rápida inline ──────────────────────────────────────
class _QuickCoverageSheet extends StatelessWidget {
  final List<int> members;
  const _QuickCoverageSheet({required this.members});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final svc    = PokedexDataService.instance;

    // Agregar fraquezas do time
    final teamWeak = <String, int>{};
    for (final id in members) {
      final types = svc.getTypes(id);
      final wk    = calculateWeaknesses(types);
      for (final e in wk.entries) {
        if (e.value >= 2.0) teamWeak[e.key] = (teamWeak[e.key] ?? 0) + 1;
      }
    }
    final sorted = teamWeak.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(title: const Text('Cobertura do Time'),
          scrolledUnderElevation: 0),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Fraquezas compartilhadas',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (sorted.isEmpty)
          Text('Nenhuma fraqueza crítica!',
              style: TextStyle(color: scheme.onSurfaceVariant))
        else
          Wrap(spacing: 8, runSpacing: 8,
            children: sorted.map((e) {
              final tc = TypeColors.fromType(ptType(e.key));
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: tc.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: tc.withOpacity(0.4))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Image.asset(typeIconAsset(e.key), width: 14, height: 14,
                      errorBuilder: (_, __, ___) => const SizedBox()),
                  const SizedBox(width: 4),
                  Text(ptType(e.key), style: TextStyle(fontSize: 11,
                      fontWeight: FontWeight.w600, color: tc)),
                  const SizedBox(width: 4),
                  Text('×${e.value}', style: TextStyle(fontSize: 10,
                      color: e.value >= 3 ? scheme.error : scheme.onSurfaceVariant)),
                ]),
              );
            }).toList()),
      ]),
    );
  }
}
