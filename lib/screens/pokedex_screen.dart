import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pokedex_tracker/services/pokeapi_service.dart';
import 'package:pokedex_tracker/services/storage_service.dart';
import 'package:pokedex_tracker/screens/detail/nacional_detail_screen.dart';
import 'package:pokedex_tracker/screens/detail/switch_detail_screen.dart';
import 'package:pokedex_tracker/screens/detail/go_detail_screen.dart';
import 'package:pokedex_tracker/screens/detail/pokopia_detail_screen.dart';
import 'package:pokedex_tracker/models/pokemon.dart';
import 'package:pokedex_tracker/theme/type_colors.dart';

// ─── TIPO PT ─────────────────────────────────────────────────────

const Map<String, String> _typesPt = {
  'normal': 'Normal', 'fire': 'Fogo', 'water': 'Água', 'electric': 'Elétrico',
  'grass': 'Planta', 'ice': 'Gelo', 'fighting': 'Lutador', 'poison': 'Veneno',
  'ground': 'Terreno', 'flying': 'Voador', 'psychic': 'Psíquico', 'bug': 'Inseto',
  'rock': 'Pedra', 'ghost': 'Fantasma', 'dragon': 'Dragão', 'dark': 'Sombrio',
  'steel': 'Aço', 'fairy': 'Fada',
};

String _pt(String en) => _typesPt[en.toLowerCase()] ?? en;

// ─── MODELO INTERNO ────────────────────────────────────────────

class _Entry {
  final int entryNumber; // número dentro da dex
  final int speciesId;   // ID nacional
  _Entry({required this.entryNumber, required this.speciesId});
}

// ─── SCREEN ───────────────────────────────────────────────────────

class PokedexScreen extends StatefulWidget {
  final String pokedexId;
  final String pokedexName;
  final int totalPokemon;
  final String? initialSectionFilter; // apiName da seção (ex: 'kitakami')

  const PokedexScreen({
    super.key,
    required this.pokedexId,
    required this.pokedexName,
    required this.totalPokemon,
    this.initialSectionFilter,
  });

  @override
  State<PokedexScreen> createState() => _PokedexScreenState();
}

class _PokedexScreenState extends State<PokedexScreen> {
  final PokeApiService _api = PokeApiService();
  final StorageService _storage = StorageService();

  // Entries por seção: apiName → lista de _Entry
  Map<String, List<_Entry>> _entriesBySection = {};
  // Dados dos Pokémon: speciesId → Map da API
  final Map<int, Map<String, dynamic>> _pokemonData = {};
  // Capturados: speciesId → bool
  final Map<int, bool> _caughtMap = {};

  bool _loadingIds = true;
  bool _loadingPage = false;
  String? _error;

  List<PokedexSection> _sections = [];
  // Set vazio = todas as seções (sem filtro)
  final Set<String> _selectedSections = {};

  // Gens selecionadas para Nacional — Set vazio = todas
  final Set<String> _selectedGens = {};

  List<_Entry> _visibleEntries = [];
  int _currentPage = 0;
  static const int _pageSize = 30;

  String _filterStatus = 'todos';
  String? _filterType;
  String _sortBy = 'numero';
  String _searchQuery = '';
  bool _searchOpen = false;
  final TextEditingController _searchController = TextEditingController();

  bool get _isNacional => widget.pokedexId == 'nacional';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _sections = _api.getSections(widget.pokedexId);

    if (widget.initialSectionFilter != null) {
      _selectedSections.add(widget.initialSectionFilter!);
    }

    _initPokedex();
  }

  // ─── INICIALIZAÇÃO ────────────────────────────────────────────────

  Future<void> _initPokedex() async {
    setState(() { _loadingIds = true; _error = null; });

    try {
      final bySection = <String, List<_Entry>>{};

      for (final section in _sections) {
        final cached = await _storage.getSectionEntries(widget.pokedexId, section.apiName);
        if (cached != null) {
          bySection[section.apiName] = cached
              .map((e) => _Entry(entryNumber: e['entryNumber']!, speciesId: e['speciesId']!))
              .toList();
        }
      }

      // Busca da API as seções faltantes
      if (bySection.length < _sections.length) {
        final fromApi = await _api.fetchEntriesBySection(widget.pokedexId);
        for (final entry in fromApi.entries) {
          final entries = entry.value
              .map((e) => _Entry(entryNumber: e.entryNumber, speciesId: e.speciesId))
              .toList();
          bySection[entry.key] = entries;
          await _storage.saveSectionEntries(
            widget.pokedexId,
            entry.key,
            entries.map((e) => {'entryNumber': e.entryNumber, 'speciesId': e.speciesId}).toList(),
          );
        }
      }

      // Fallback para GO / Pokopia (sem seção na API)
      if (bySection.isEmpty) {
        final ids = List.generate(math.min(widget.totalPokemon, 1025), (i) => i + 1);
        bySection['all'] = ids
            .map((id) => _Entry(entryNumber: id, speciesId: id))
            .toList();
      }

      _entriesBySection = bySection;

      // Carrega status de captura
      final allSpeciesIds = _allFilteredEntries().map((e) => e.speciesId).toList();
      final caughtMap = await _storage.getCaughtMap(widget.pokedexId, allSpeciesIds);

      if (!mounted) return;
      setState(() {
        _caughtMap.addAll(caughtMap);
        _loadingIds = false;
      });

      await _loadPage(0);
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Erro ao carregar: $e'; _loadingIds = false; });
    }
  }

  // ─── ENTRIES FILTRADAS ────────────────────────────────────────────

  List<_Entry> _allFilteredEntries() {
    List<_Entry> entries;

    if (_isNacional && _selectedGens.isNotEmpty) {
      // Filtra por gens selecionadas
      final allNac = _entriesBySection['national'] ?? [];
      final genRanges = nationalGens.where((g) => _selectedGens.contains(g.label)).toList();
      entries = allNac.where((e) =>
        genRanges.any((g) => e.speciesId >= g.startId && e.speciesId <= g.endId)
      ).toList();
    } else if (!_isNacional && _selectedSections.isNotEmpty) {
      // Mostra apenas as seções selecionadas, mescladas sem duplicatas
      final seen = <int>{};
      entries = [];
      for (final apiName in _selectedSections) {
        for (final e in (_entriesBySection[apiName] ?? [])) {
          if (seen.add(e.speciesId)) entries.add(e);
        }
      }
      entries.sort((a, b) => a.entryNumber.compareTo(b.entryNumber));
    } else {
      // Todas as seções sem duplicatas
      final seen = <int>{};
      entries = [];
      for (final list in _entriesBySection.values) {
        for (final e in list) {
          if (seen.add(e.speciesId)) entries.add(e);
        }
      }
    }

    // Filtro status
    if (_filterStatus == 'capturados') {
      entries = entries.where((e) => _caughtMap[e.speciesId] == true).toList();
    } else if (_filterStatus == 'não capturados') {
      entries = entries.where((e) => _caughtMap[e.speciesId] != true).toList();
    }

    // Filtro tipo
    if (_filterType != null) {
      entries = entries.where((e) {
        final data = _pokemonData[e.speciesId];
        if (data == null) return true;
        return _api.extractTypes(data).contains(_filterType);
      }).toList();
    }

    // Ordenação
    if (_sortBy == 'nome') {
      entries.sort((a, b) {
        final nameA = _pokemonData[a.speciesId]?['name'] as String? ?? '';
        final nameB = _pokemonData[b.speciesId]?['name'] as String? ?? '';
        return nameA.compareTo(nameB);
      });
    }
    // padrão = por entryNumber (já está ordenado)

    // Filtro de busca — nome, número e tipo
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      entries = entries.where((e) {
        final data = _pokemonData[e.speciesId];
        // Por número (#007 ou "7")
        final numStr = e.speciesId.toString();
        final numPadded = e.speciesId.toString().padLeft(3, '0');
        if (numStr.contains(q) || numPadded.contains(q)) return true;
        // Por nome
        if (data != null) {
          final name = (data['name'] as String).split('-').first.toLowerCase();
          if (name.contains(q)) return true;
          // Por tipo (EN ou PT)
          final types = _api.extractTypes(data);
          for (final t in types) {
            if (t.toLowerCase().contains(q)) return true;
            if ((_typesPt[t] ?? '').toLowerCase().contains(q)) return true;
          }
        }
        return false;
      }).toList();
    }

    return entries;
  }

  // ─── PAGINAÇÃO ────────────────────────────────────────────────────

  Future<void> _loadPage(int page) async {
    if (_loadingPage) return;
    setState(() => _loadingPage = true);

    final filtered = _allFilteredEntries();
    final start = page * _pageSize;
    if (start >= filtered.length) {
      setState(() => _loadingPage = false);
      return;
    }

    final toLoad = filtered
        .skip(start)
        .take(_pageSize)
        .where((e) => !_pokemonData.containsKey(e.speciesId))
        .map((e) => e.speciesId)
        .toList();

    if (toLoad.isNotEmpty) {
      final batch = await _api.fetchPokemonBatch(toLoad);
      if (!mounted) return;
      for (final p in batch) {
        _pokemonData[p['id'] as int] = p;
      }
    }

    if (!mounted) return;
    setState(() {
      _currentPage = page;
      _visibleEntries = filtered.take((page + 1) * _pageSize).toList();
      _loadingPage = false;
    });
  }

  // ─── CAPTURA ──────────────────────────────────────────────────────

  Future<void> _toggleCatch(int speciesId) async {
    final current = _caughtMap[speciesId] ?? false;
    final newVal = !current;
    HapticFeedback.mediumImpact();
    setState(() => _caughtMap[speciesId] = newVal);
    await _storage.setCaught(widget.pokedexId, speciesId, newVal);

    if (!mounted) return;
    final rawName = (_pokemonData[speciesId]?['name'] as String? ?? '#$speciesId')
        .split('-').first;
    final name = rawName[0].toUpperCase() + rawName.substring(1).toLowerCase();
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(newVal ? '$name capturado!' : '$name removido'),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ─── DETALHE ──────────────────────────────────────────────────────

  /// Constrói um Pokemon a partir do speciesId carregado em _pokemonData
  Pokemon? _buildPokemon(int speciesId) {
    final data = _pokemonData[speciesId];
    if (data == null) return null;
    final stats   = _api.extractStats(data);
    final rawName = data['name'] as String;
    final baseName = rawName.split('-').first;
    final displayName = baseName[0].toUpperCase() + baseName.substring(1);
    final sprites = _api.extractAllSprites(data);
    return Pokemon(
      id: data['id'] as int,
      name: displayName,
      types: _api.extractTypes(data),
      baseHp:        stats['hp'] ?? 0,
      baseAttack:    stats['attack'] ?? 0,
      baseDefense:   stats['defense'] ?? 0,
      baseSpAttack:  stats['special-attack'] ?? 0,
      baseSpDefense: stats['special-defense'] ?? 0,
      baseSpeed:     stats['speed'] ?? 0,
      spriteUrl:          sprites['default'] ?? sprites['pixel'] ?? '',
      spriteShinyUrl:     sprites['shiny'],
      spritePixelUrl:     sprites['pixel'],
      spritePixelShinyUrl:sprites['pixelShiny'],
      spritePixelFemaleUrl:sprites['pixelFemale'],
      spriteHomeUrl:      sprites['home'],
      spriteHomeShinyUrl: sprites['homeShiny'],
      spriteHomeFemaleUrl:sprites['homeFemale'],
    );
  }

  void _openDetail(_Entry entry) async {
    final filtered = _allFilteredEntries();
    final idx = filtered.indexWhere((e) => e.speciesId == entry.speciesId);
    await _openDetailAt(filtered, idx);
  }

  Future<void> _openDetailAt(List<_Entry> filtered, int idx) async {
    if (idx < 0 || idx >= filtered.length) return;
    final entry = filtered[idx];

    // Garante que o Pokémon atual está carregado
    if (!_pokemonData.containsKey(entry.speciesId)) {
      final batch = await _api.fetchPokemonBatch([entry.speciesId]);
      if (!mounted) return;
      for (final p in batch) _pokemonData[p['id'] as int] = p;
    }

    final pokemon = _buildPokemon(entry.speciesId);
    if (pokemon == null) return;

    bool isCaught = _caughtMap[entry.speciesId] ?? false;

    // Vizinhos — pré-carrega os dados se necessário
    final prevEntry = idx > 0 ? filtered[idx - 1] : null;
    final nextEntry = idx < filtered.length - 1 ? filtered[idx + 1] : null;

    if (prevEntry != null && !_pokemonData.containsKey(prevEntry.speciesId)) {
      _api.fetchPokemonBatch([prevEntry.speciesId]).then((batch) {
        if (mounted) for (final p in batch) _pokemonData[p['id'] as int] = p;
      });
    }
    if (nextEntry != null && !_pokemonData.containsKey(nextEntry.speciesId)) {
      _api.fetchPokemonBatch([nextEntry.speciesId]).then((batch) {
        if (mounted) for (final p in batch) _pokemonData[p['id'] as int] = p;
      });
    }

    String? _prevName, _nextName;
    int?    _prevId,   _nextId;

    if (prevEntry != null) {
      final d = _pokemonData[prevEntry.speciesId];
      if (d != null) {
        final raw = (d['name'] as String).split('-').first;
        _prevName = raw[0].toUpperCase() + raw.substring(1);
        _prevId   = d['id'] as int;
      }
    }
    if (nextEntry != null) {
      final d = _pokemonData[nextEntry.speciesId];
      if (d != null) {
        final raw = (d['name'] as String).split('-').first;
        _nextName = raw[0].toUpperCase() + raw.substring(1);
        _nextId   = d['id'] as int;
      }
    }

    final onToggle = () async {
      isCaught = !isCaught;
      await _storage.setCaught(widget.pokedexId, entry.speciesId, isCaught);
      if (mounted) setState(() => _caughtMap[entry.speciesId] = isCaught);
    };

    final isNacional = widget.pokedexId == 'nacional';
    final isGo = widget.pokedexId.contains('pokémon_go') || widget.pokedexId.contains('pokemon_go');
    final isPokopia = widget.pokedexId.contains('pokopia');

    if (!mounted) return;
    await Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) {
          if (isNacional) {
            return NacionalDetailScreen(
              pokemon: pokemon, caught: isCaught, onToggleCaught: onToggle,
              prevName: _prevName, prevId: _prevId,
              nextName: _nextName, nextId: _nextId,
              onPrev: prevEntry != null ? () {
                Navigator.pop(context);
                _openDetailAt(filtered, idx - 1);
              } : null,
              onNext: nextEntry != null ? () {
                Navigator.pop(context);
                _openDetailAt(filtered, idx + 1);
              } : null,
            );
          } else if (isGo) {
            return GoDetailScreen(
              pokemon: pokemon, caught: isCaught, onToggleCaught: onToggle);
          } else if (isPokopia) {
            return PokopiaDetailScreen(
              pokemon: pokemon, caught: isCaught, onToggleCaught: onToggle);
          } else {
            return SwitchDetailScreen(
              pokemon: pokemon, caught: isCaught, onToggleCaught: onToggle,
              prevName: _prevName, prevId: _prevId,
              nextName: _nextName, nextId: _nextId,
              onPrev: prevEntry != null ? () {
                Navigator.pop(context);
                _openDetailAt(filtered, idx - 1);
              } : null,
              onNext: nextEntry != null ? () {
                Navigator.pop(context);
                _openDetailAt(filtered, idx + 1);
              } : null,
            );
          }
        },
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 180),
      ),
    );

    if (mounted) {
      final updated = await _storage.isCaught(widget.pokedexId, entry.speciesId);
      setState(() => _caughtMap[entry.speciesId] = updated);
    }
  }

  // ─── BUILD ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final filtered = _allFilteredEntries();
    final caught = _caughtMap.values.where((v) => v).length;
    final totalInSection = filtered.length == 0
        ? widget.totalPokemon
        : _allFilteredEntries().length;

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: _searchOpen
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Nome, número ou tipo...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(fontSize: 15),
                ),
                style: const TextStyle(fontSize: 15),
                onChanged: (v) => setState(() => _searchQuery = v),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.pokedexName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  Text(
                    '$caught / ${_entriesBySection.values.fold(0, (s, l) => s + l.length) == 0 ? widget.totalPokemon : _entriesBySection.values.fold(0, (s, l) => s + l.length)} capturados',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
        actions: [
          // Ícone de busca
          IconButton(
            icon: Icon(_searchOpen ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _searchOpen = !_searchOpen;
                if (!_searchOpen) {
                  _searchQuery = '';
                  _searchController.clear();
                }
              });
            },
          ),
          // Ícone de filtro (só quando busca fechada)
          if (!_searchOpen)
            IconButton(icon: const Icon(Icons.filter_list), onPressed: _showFilterSheet),
        ],
      ),
      body: Column(
        children: [
          // Chips de seção (jogos com DLC ou Nacional com gens)
          if (_sections.length > 1) _buildSectionChips(),
          if (_isNacional) _buildGenChips(),
          Expanded(child: _buildBody(filtered)),
        ],
      ),
    );
  }

  Widget _buildSectionChips() {
    final hasSelection = _selectedSections.isNotEmpty;
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 12),
              children: _sections.map((s) {
                final isSelected = _selectedSections.contains(s.apiName);
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(s.isDlc ? '${s.label} (DLC)' : s.label),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() {
                        if (isSelected) {
                          _selectedSections.remove(s.apiName);
                        } else {
                          _selectedSections.add(s.apiName);
                        }
                        _visibleEntries = [];
                        _currentPage = 0;
                      });
                      _loadPage(0);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          // Botão X discreto — só aparece quando há seleção
          if (hasSelection)
            Padding(
              padding: const EdgeInsets.only(right: 8, left: 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  setState(() {
                    _selectedSections.clear();
                    _visibleEntries = [];
                    _currentPage = 0;
                  });
                  _loadPage(0);
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close, size: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGenChips() {
    final hasSelection = _selectedGens.isNotEmpty;
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 12),
              children: nationalGens.map((gen) {
                final isSelected = _selectedGens.contains(gen.label);
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text('${gen.label} · ${gen.region}'),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() {
                        if (isSelected) {
                          _selectedGens.remove(gen.label);
                        } else {
                          _selectedGens.add(gen.label);
                        }
                        _visibleEntries = [];
                        _currentPage = 0;
                      });
                      _loadPage(0);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          if (hasSelection)
            Padding(
              padding: const EdgeInsets.only(right: 8, left: 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  setState(() {
                    _selectedGens.clear();
                    _visibleEntries = [];
                    _currentPage = 0;
                  });
                  _loadPage(0);
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close, size: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(List<_Entry> filtered) {
    if (_loadingIds) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Carregando Pokémon...',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 12),
          Text(_error!),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _initPokedex, child: const Text('Tentar novamente')),
        ],
      ));
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollEndNotification &&
            n.metrics.extentAfter < 300 &&
            !_loadingPage &&
            _visibleEntries.length < filtered.length) {
          _loadPage(_currentPage + 1);
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: _initPokedex,
        child: GridView.builder(
          padding: const EdgeInsets.all(10),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.72,
          ),
          itemCount: _visibleEntries.length + (_loadingPage ? 3 : 0),
          itemBuilder: (context, index) {
            if (index >= _visibleEntries.length) return _SkeletonCard();
            final entry = _visibleEntries[index];
            final data = _pokemonData[entry.speciesId];
            return _PokemonCard(
              entry: entry,
              data: data,
              caught: _caughtMap[entry.speciesId] ?? false,
              onLongPress: () => _toggleCatch(entry.speciesId),
              onTap: () => _openDetail(entry),
            );
          },
        ),
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _FilterSheet(
        currentStatus: _filterStatus,
        currentType: _filterType,
        currentSort: _sortBy,
        onApply: (status, type, sort) {
          setState(() {
            _filterStatus = status;
            _filterType = type;
            _sortBy = sort;
            _currentPage = 0;
            _visibleEntries = [];
          });
          _loadPage(0);
          Navigator.pop(ctx);
        },
      ),
    );
  }
}

// ─── CARD DE POKÉMON ─────────────────────────────────────────────

class _PokemonCard extends StatelessWidget {
  final _Entry entry;
  final Map<String, dynamic>? data;
  final bool caught;
  final VoidCallback onLongPress;
  final VoidCallback onTap;

  const _PokemonCard({
    required this.entry,
    required this.data,
    required this.caught,
    required this.onLongPress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (data == null) return _SkeletonCard();

    final rawName = data!['name'] as String;
    final baseName = rawName.split('-').first;
    final displayName = baseName[0].toUpperCase() + baseName.substring(1);

    final sprite = data!['sprites']['other']['official-artwork']['front_default']
            as String? ??
        data!['sprites']['front_default'] as String?;

    final types = (data!['types'] as List<dynamic>)
        .map((t) => t['type']['name'] as String)
        .toList();

    // Cores dos tipos — mais saturadas
    final color1 = TypeColors.fromType(_pt(types[0]));
    final color2 = types.length > 1 ? TypeColors.fromType(_pt(types[1])) : color1;

    // Número formatado com o entryNumber da dex (não o ID nacional)
    final displayNumber = '#${entry.entryNumber.toString().padLeft(3, '0')}';

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: caught
                ? [color1.withOpacity(0.45), color2.withOpacity(0.30)]
                : [color1.withOpacity(0.22), color2.withOpacity(0.14)],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: caught
                ? color1.withOpacity(0.65)
                : color1.withOpacity(0.30),
            width: caught ? 1.5 : 0.8,
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Opacity(
                      opacity: caught ? 1.0 : 0.5,
                      child: sprite != null
                          ? Image.network(
                              sprite,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.catching_pokemon, size: 40),
                            )
                          : const Icon(Icons.catching_pokemon, size: 40),
                    ),
                  ),
                  Text(
                    displayNumber,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 9,
                        ),
                  ),
                  Text(
                    displayName,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  // Badges: cor sólida por tipo
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: types.map((type) {
                      final color = TypeColors.fromType(_pt(type));
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          _pt(type),
                          style: const TextStyle(
                            fontSize: 8,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            if (caught)
              Positioned(
                top: 5,
                right: 5,
                child: CustomPaint(
                  size: const Size(14, 14),
                  painter: _PokeballPainter(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── SKELETON ────────────────────────────────────────────────────

class _SkeletonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

// ─── POKÉBOLA ────────────────────────────────────────────────────

class _PokeballPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), math.pi, math.pi, false, Paint()..color = Colors.red);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), 0, math.pi, false, Paint()..color = Colors.white);
    canvas.drawLine(Offset(0, c.dy), Offset(size.width, c.dy),
        Paint()..color = Colors.black87..strokeWidth = 1.2);
    canvas.drawCircle(c, r * 0.3, Paint()..color = Colors.white);
    canvas.drawCircle(c, r * 0.3, Paint()..color = Colors.black87..style = PaintingStyle.stroke..strokeWidth = 1.2);
    canvas.drawCircle(c, r, Paint()..color = Colors.black87..style = PaintingStyle.stroke..strokeWidth = 1.2);
  }
  @override
  bool shouldRepaint(_) => false;
}

// ─── FILTER SHEET ────────────────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  final String currentStatus;
  final String? currentType;
  final String currentSort;
  final void Function(String, String?, String) onApply;
  const _FilterSheet({required this.currentStatus, required this.currentType,
      required this.currentSort, required this.onApply});
  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String _status;
  String? _type;
  late String _sort;

  @override
  void initState() {
    super.initState();
    _status = widget.currentStatus;
    _type = widget.currentType;
    _sort = widget.currentSort;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filtros', style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Text('Status', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: ['todos', 'capturados', 'não capturados'].map((s) =>
              ChoiceChip(
                label: Text(s[0].toUpperCase() + s.substring(1)),
                selected: _status == s,
                onSelected: (_) => setState(() => _status = s),
              ),
            ).toList()),
            const SizedBox(height: 16),
            Text('Tipo', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: [
                ChoiceChip(label: const Text('Todos'), selected: _type == null,
                    onSelected: (_) => setState(() => _type = null)),
                ..._typesPt.entries.map((e) => ChoiceChip(
                  label: Text(e.value),
                  selected: _type == e.key,
                  onSelected: (_) => setState(() => _type = e.key),
                  selectedColor: TypeColors.fromType(e.value).withOpacity(0.25),
                  labelStyle: TextStyle(
                    color: _type == e.key ? TypeColors.fromType(e.value) : null,
                    fontSize: 12,
                  ),
                )),
              ],
            ),
            const SizedBox(height: 16),
            Text('Ordenar por', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              ChoiceChip(label: const Text('Número'), selected: _sort == 'numero',
                  onSelected: (_) => setState(() => _sort = 'numero')),
              ChoiceChip(label: const Text('Nome'), selected: _sort == 'nome',
                  onSelected: (_) => setState(() => _sort = 'nome')),
            ]),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => widget.onApply(_status, _type, _sort),
                child: const Text('Aplicar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}