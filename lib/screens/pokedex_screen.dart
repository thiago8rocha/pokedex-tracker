import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pokedex_tracker/services/pokeapi_service.dart';
import 'package:pokedex_tracker/services/storage_service.dart';
import 'package:pokedex_tracker/services/dex_bundle_service.dart';
import 'package:pokedex_tracker/services/pokedex_data_service.dart';
import 'package:pokedex_tracker/screens/detail/detail_shared.dart'
    show defaultSpriteNotifier, typeNamePt, typeIconColors;
import 'package:pokedex_tracker/screens/detail/nacional_detail_screen.dart';
import 'package:pokedex_tracker/screens/detail/mainline_detail_screen.dart';
import 'package:pokedex_tracker/screens/go/go_detail_screen.dart';
import 'package:pokedex_tracker/screens/pokopia/pokopia_detail_screen.dart';
import 'package:pokedex_tracker/screens/pokopia/pokopia_hub_screen.dart';
import 'package:pokedex_tracker/screens/go/go_hub_screen.dart';
import 'package:pokedex_tracker/screens/pocket/pocket_hub_screen.dart';
import 'package:pokedex_tracker/screens/menu/moves_list_screen.dart';
import 'package:pokedex_tracker/screens/menu/abilities_list_screen.dart';
import 'package:pokedex_tracker/screens/menu/natures_list_screen.dart';
import 'package:pokedex_tracker/screens/menu/teams_screen.dart';
import 'package:pokedex_tracker/screens/menu/items_list_screen.dart';
import 'package:pokedex_tracker/screens/settings_screen.dart';
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

class _PokedexScreenState extends State<PokedexScreen>
    with SingleTickerProviderStateMixin {
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
  Set<String> _filterTypes = {};        // vazio = todos; até 2 tipos
  Set<String> _filterSpecialties = {};  // vazio = todos (só Pokopia)
  String _sortBy  = 'numero';
  String _sortDir = 'asc';              // 'asc' | 'desc'
  String _searchQuery = '';
  bool _searchOpen = false;
  final TextEditingController _searchController = TextEditingController();

  bool get _isNacional => widget.pokedexId == 'nacional';
  bool get _isPokopia  => widget.pokedexId == 'pokopia' || widget.pokedexId == 'pokopia_event';
  bool get _isPokopiaBase => widget.pokedexId == 'pokopia';

  // ── Navegação principal ──────────────────────────────────────
  // Controla qual tab do bottom nav está ativa (apenas visual)
  int _navIndex = 0;

  // Aba ativa quando é pokopia base (Standard / Event)
  String _activePokedexId = '';
  TabController? _pokopiaTabController;

  String get _effectivePokedexId =>
      _isPokopiaBase ? _activePokedexId : widget.pokedexId;

  @override
  void dispose() {
    _searchController.dispose();
    _pokopiaTabController?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _sections = _api.getSections(widget.pokedexId);

    if (_isPokopiaBase) {
      _activePokedexId = 'pokopia';
      _pokopiaTabController = TabController(length: 2, vsync: this)
        ..addListener(() {
          if (!_pokopiaTabController!.indexIsChanging) return;
          final newId = _pokopiaTabController!.index == 0 ? 'pokopia' : 'pokopia_event';
          if (newId == _activePokedexId) return;
          setState(() {
            _activePokedexId   = newId;
            _entriesBySection  = {};
            _visibleEntries    = [];
            _currentPage       = 0;
            _caughtMap.clear();
            _filterStatus      = 'todos';
            _filterSpecialties = {};
            _searchQuery       = '';
            _searchController.clear();
            _searchOpen        = false;
          });
          _initPokedex();
        });
    } else {
      _activePokedexId = widget.pokedexId;
    }

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
        // 1. Cache local (SharedPreferences)
        final cached = await _storage.getSectionEntries(_effectivePokedexId, section.apiName);
        if (cached != null) {
          bySection[section.apiName] = cached
              .map((e) => _Entry(entryNumber: e['entryNumber']!, speciesId: e['speciesId']!))
              .toList();
          continue;
        }

        // 2. Bundle local (assets/data/dex/dex_*.json)
        final bundle = await DexBundleService.instance.loadSection(section.apiName);
        if (bundle != null) {
          final entries = bundle
              .map((e) => _Entry(entryNumber: e['entryNumber']!, speciesId: e['speciesId']!))
              .toList();
          bySection[section.apiName] = entries;
          // Persiste no cache para uso futuro sem releitura do bundle
          await _storage.saveSectionEntries(
            _effectivePokedexId,
            section.apiName,
            bundle,
          );
          continue;
        }

        // 3. Fallback: API de rede
        final fromApi = await _api.fetchEntriesBySection(_effectivePokedexId);
        for (final entry in fromApi.entries) {
          final entries = entry.value
              .map((e) => _Entry(entryNumber: e.entryNumber, speciesId: e.speciesId))
              .toList();
          bySection[entry.key] = entries;
          await _storage.saveSectionEntries(
            _effectivePokedexId,
            entry.key,
            entries.map((e) => {'entryNumber': e.entryNumber, 'speciesId': e.speciesId}).toList(),
          );
        }
        break; // fetchEntriesBySection já busca todas as seções de uma vez
      }

      // Fallback para GO / Pokopia (sem seção configurada)
      if (bySection.isEmpty) {
        final isPokopia      = _effectivePokedexId.contains('pokopia');
        final isPokopiaEvent = _effectivePokedexId == 'pokopia_event';
        final isGo           = _effectivePokedexId == 'pokémon_go';

        if (isGo) {
          // Lê do bundle local
          final bundle = await DexBundleService.instance.loadSection('go');
          if (bundle != null) {
            bySection['go'] = bundle
                .map((e) => _Entry(entryNumber: e['entryNumber']!, speciesId: e['speciesId']!))
                .toList();
          }
        }

        if (bySection.isEmpty) {
          final ids = isPokopiaEvent
              ? pokopiaEventSpeciesIds
              : isPokopia
                  ? pokopiaSpeciesIds
                  : List.generate(math.min(widget.totalPokemon, 1025), (i) => i + 1);
          bySection['all'] = ids
              .asMap()
              .entries
              .map((e) => _Entry(entryNumber: e.key + 1, speciesId: e.value))
              .toList();
        }
      }

      _entriesBySection = bySection;


      // Carrega status de captura
      final allSpeciesIds = _allFilteredEntries().map((e) => e.speciesId).toList();
      final caughtMap = await _storage.getCaughtMap(_effectivePokedexId, allSpeciesIds);

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
    final metLabel    = _isPokopia ? 'encontrados'     : 'capturados';
    final notMetLabel = _isPokopia ? 'não encontrados' : 'não capturados';
    if (_filterStatus == metLabel) {
      entries = entries.where((e) => _caughtMap[e.speciesId] == true).toList();
    } else if (_filterStatus == notMetLabel) {
      entries = entries.where((e) => _caughtMap[e.speciesId] != true).toList();
    }

    // Filtro tipo — mostra Pokémon que tenham TODOS os tipos selecionados
    if (_filterTypes.isNotEmpty) {
      entries = entries.where((e) {
        final pokemonTypes = PokedexDataService.instance.getTypes(e.speciesId).toSet();
        return _filterTypes.every((t) => pokemonTypes.contains(t));
      }).toList();
    }

    // Filtro especialidade (só Pokopia) — mostra quem tem a especialidade
    if (_filterSpecialties.isNotEmpty && _isPokopia) {
      entries = entries.where((e) {
        final sp = pokopiaSpecialtyMap[e.speciesId];
        if (sp == null) return false;
        return _filterSpecialties.any((f) => sp.contains(f));
      }).toList();
    }

    // Ordenação
    if (_sortBy == 'nome') {
      entries.sort((a, b) {
        final nameA = PokedexDataService.instance.getName(a.speciesId);
        final nameB = PokedexDataService.instance.getName(b.speciesId);
        return _sortDir == 'asc' ? nameA.compareTo(nameB) : nameB.compareTo(nameA);
      });
    } else {
      // Número
      if (_sortDir == 'desc') {
        entries = entries.reversed.toList();
      }
    }

    // Filtro de busca — nome, número e tipo
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      entries = entries.where((e) {
        final svc = PokedexDataService.instance;
        // Por número (#007 ou "7")
        final numStr    = e.speciesId.toString();
        final numPadded = e.speciesId.toString().padLeft(3, '0');
        if (numStr.contains(q) || numPadded.contains(q)) return true;
        // Por nome
        final name = svc.getName(e.speciesId).toLowerCase();
        if (name.contains(q)) return true;
        // Por tipo (EN ou PT)
        for (final t in svc.getTypes(e.speciesId)) {
          if (t.toLowerCase().contains(q)) return true;
          if ((_typesPt[t] ?? '').toLowerCase().contains(q)) return true;
        }
        return false;
      }).toList();
    }

    return entries;
  }

  // ─── PAGINAÇÃO ────────────────────────────────────────────────────

  /// Monta o mapa local de dados de um pokémon sem chamada de rede.
  /// Substitui a resposta da PokeAPI com dados do bundle + URL de sprite gerada.
  Map<String, dynamic> _localPokemonData(int id) {
    final svc    = PokedexDataService.instance;
    final types  = svc.getTypes(id);
    final name   = _pokemonNameFromId(id);
    return {
      'id':    id,
      'name':  name,
      'types': types.map((t) => {'type': {'name': t}}).toList(),
      'sprites': {
        'front_default': _buildSpriteUrl(id, 'pixel'),
        'other': {
          'official-artwork': {'front_default': _buildSpriteUrl(id, 'artwork')},
          'home':             {'front_default': _buildSpriteUrl(id, 'home')},
        },
      },
    };
  }

  /// Monta a URL do sprite a partir do ID e do tipo preferido.
  String _buildSpriteUrl(int id, String type) {
    const base = 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon';
    switch (type) {
      case 'pixel': return '$base/$id.png';
      case 'home':  return '$base/other/home/$id.png';
      case 'artwork':
      default:      return '$base/other/official-artwork/$id.png';
    }
  }

  /// Retorna o nome do pokémon no formato "Bulbasaur" a partir do ID.
  String _pokemonNameFromId(int id) => PokedexDataService.instance.getName(id);

  Future<void> _loadPage(int page) async {
    if (_loadingPage) return;

    final filtered = _allFilteredEntries();
    final start = page * _pageSize;
    if (start >= filtered.length) return;

    // Preenche _pokemonData — operação síncrona, sem I/O
    final toFill = filtered
        .skip(start)
        .take(_pageSize)
        .where((e) => !_pokemonData.containsKey(e.speciesId))
        .map((e) => e.speciesId)
        .toList();

    for (final id in toFill) {
      _pokemonData[id] = _localPokemonData(id);
    }

    // Pré-decodifica as imagens antes de montar a grid
    // Evita o jank de 2-3s ao abrir pela primeira vez
    if (toFill.isNotEmpty && mounted) {
      final spriteType = defaultSpriteNotifier.value;
      await Future.wait(
        toFill.map((id) {
          final path = _assetPathFor(id, spriteType);
          return precacheImage(AssetImage(path), context)
              .catchError((_) {});
        }),
      );
    }

    if (!mounted) return;
    setState(() {
      _currentPage = page;
      _visibleEntries = filtered.take((page + 1) * _pageSize).toList();
      _loadingPage = false;
      _loadingIds  = false;
    });
  }

  String _assetPathFor(int id, String type) => pokemonSpriteAsset(id, type);

  // ─── CAPTURA ──────────────────────────────────────────────────────

  Future<void> _toggleCatch(int speciesId) async {
    final current = _caughtMap[speciesId] ?? false;
    final newVal = !current;
    HapticFeedback.mediumImpact();
    setState(() => _caughtMap[speciesId] = newVal);
    await _storage.setCaught(_effectivePokedexId, speciesId, newVal);

    if (!mounted) return;
    final name = PokedexDataService.instance.getName(speciesId);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(newVal
          ? (_isPokopia ? '$name encontrado!' : '$name capturado!')
          : '$name removido'),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ─── DETALHE ──────────────────────────────────────────────────────

  /// Constrói um Pokemon a partir do speciesId — usa dados locais do bundle.
  Pokemon? _buildPokemon(int speciesId) {
    final data = _pokemonData[speciesId];
    if (data == null) return null;

    final rawName = data['name'] as String;
    final baseName = rawName.startsWith('#') ? rawName : rawName.split('-').first;
    final displayName = baseName.startsWith('#')
        ? baseName
        : baseName[0].toUpperCase() + baseName.substring(1);

    final types = _api.extractTypes(data);

    // Sprites — montadas localmente
    final spriteType = defaultSpriteNotifier.value;
    final spriteUrl      = _buildSpriteUrl(speciesId, spriteType);
    final pixelUrl       = _buildSpriteUrl(speciesId, 'pixel');
    final homeUrl        = _buildSpriteUrl(speciesId, 'home');
    final artworkUrl     = _buildSpriteUrl(speciesId, 'artwork');
    // Shiny segue o mesmo padrão com /shiny/
    const base = 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon';
    final shinyUrl       = '$base/other/official-artwork/shiny/$speciesId.png';
    final pixelShinyUrl  = '$base/shiny/$speciesId.png';
    final homeShinyUrl   = '$base/other/home/shiny/$speciesId.png';

    // Stats — lidos da API se disponíveis, senão zero
    final rawStats = data['stats'] as List<dynamic>?;
    int statVal(String name) {
      if (rawStats == null) return 0;
      final s = rawStats.firstWhere(
        (s) => s['stat']['name'] == name,
        orElse: () => null,
      );
      return (s?['base_stat'] as int?) ?? 0;
    }

    return Pokemon(
      id:                  speciesId,
      name:                displayName,
      types:               types,
      baseHp:              statVal('hp'),
      baseAttack:          statVal('attack'),
      baseDefense:         statVal('defense'),
      baseSpAttack:        statVal('special-attack'),
      baseSpDefense:       statVal('special-defense'),
      baseSpeed:           statVal('speed'),
      spriteUrl:           spriteType == 'pixel' ? pixelUrl : spriteType == 'home' ? homeUrl : artworkUrl,
      spriteShinyUrl:      shinyUrl,
      spritePixelUrl:      pixelUrl,
      spritePixelShinyUrl: pixelShinyUrl,
      spritePixelFemaleUrl:null,
      spriteHomeUrl:       homeUrl,
      spriteHomeShinyUrl:  homeShinyUrl,
      spriteHomeFemaleUrl: null,
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

    // Garante dados locais básicos
    if (!_pokemonData.containsKey(entry.speciesId)) {
      _pokemonData[entry.speciesId] = _localPokemonData(entry.speciesId);
    }

    // Busca stats se ainda não temos — aguarda com timeout para não bloquear
    if (_pokemonData[entry.speciesId]!['stats'] == null) {
      final apiData = await _api.fetchPokemon(entry.speciesId)
          .timeout(const Duration(seconds: 4), onTimeout: () => null);
      if (apiData != null && mounted) {
        _pokemonData[entry.speciesId] = {
          ..._pokemonData[entry.speciesId]!,
          'stats': apiData['stats'],
        };
      }
    }

    final pokemon = _buildPokemon(entry.speciesId);
    if (pokemon == null) return;

    bool isCaught = _caughtMap[entry.speciesId] ?? false;

    // Vizinhos — pré-carrega localmente
    final prevEntry = idx > 0 ? filtered[idx - 1] : null;
    final nextEntry = idx < filtered.length - 1 ? filtered[idx + 1] : null;

    if (prevEntry != null && !_pokemonData.containsKey(prevEntry.speciesId)) {
      _pokemonData[prevEntry.speciesId] = _localPokemonData(prevEntry.speciesId);
    }
    if (nextEntry != null && !_pokemonData.containsKey(nextEntry.speciesId)) {
      _pokemonData[nextEntry.speciesId] = _localPokemonData(nextEntry.speciesId);
    }

    // Pré-carrega stats dos vizinhos em background (sem await)
    for (final neighbor in [prevEntry, nextEntry]) {
      if (neighbor != null && _pokemonData[neighbor.speciesId]?['stats'] == null) {
        _api.fetchPokemon(neighbor.speciesId).then((apiData) {
          if (apiData != null && mounted) {
            _pokemonData[neighbor.speciesId] = {
              ..._pokemonData[neighbor.speciesId]!,
              'stats': apiData['stats'],
            };
          }
        });
      }
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
      await _storage.setCaught(_effectivePokedexId, entry.speciesId, isCaught);
      if (mounted) setState(() => _caughtMap[entry.speciesId] = isCaught);
    };

    final isNacional = _effectivePokedexId == 'nacional';
    final isGo = _effectivePokedexId.contains('pokémon_go') || _effectivePokedexId.contains('pokemon_go');
    final isPokopia = _effectivePokedexId.contains('pokopia');

    if (!mounted) return;
    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (routeContext, __, ___) {
          // Ao navegar para prev/next: pushReplacement no context da rota atual
          // Isso troca a rota sem revelar o que está atrás → sem piscar
          onPrevCallback() => _navigateFromDetail(routeContext, filtered, idx - 1);
          onNextCallback() => _navigateFromDetail(routeContext, filtered, idx + 1);

          if (isNacional) {
            return NacionalDetailScreen(
              pokemon: pokemon, caught: isCaught, onToggleCaught: onToggle,
              prevName: _prevName, prevId: _prevId,
              nextName: _nextName, nextId: _nextId,
              onPrev: prevEntry != null ? onPrevCallback : null,
              onNext: nextEntry != null ? onNextCallback : null,
            );
          } else if (isGo) {
            return GoDetailScreen(
              pokemon: pokemon, caught: isCaught, onToggleCaught: onToggle,
              prevName: _prevName, prevId: _prevId,
              nextName: _nextName, nextId: _nextId,
              onPrev: prevEntry != null ? onPrevCallback : null,
              onNext: nextEntry != null ? onNextCallback : null,
            );
          } else if (isPokopia) {
            return PokopiaDetailScreen(
              pokemon: pokemon, caught: isCaught, onToggleCaught: onToggle);
          } else {
            return SwitchDetailScreen(
              pokemon: pokemon, caught: isCaught, onToggleCaught: onToggle,
              pokedexId: _effectivePokedexId,
              prevName: _prevName, prevId: _prevId,
              nextName: _nextName, nextId: _nextId,
              onPrev: prevEntry != null ? onPrevCallback : null,
              onNext: nextEntry != null ? onNextCallback : null,
            );
          }
        },
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 180),
      ),
    );

    if (mounted) {
      final updated = await _storage.isCaught(_effectivePokedexId, entry.speciesId);
      setState(() => _caughtMap[entry.speciesId] = updated);
    }
  }

  /// Navega para prev/next a partir da tela de detalhe usando pushReplacement
  /// com fade — evita o piscar da tela anterior.
  Future<void> _navigateFromDetail(
      BuildContext detailContext, List<_Entry> filtered, int newIdx) async {
    if (newIdx < 0 || newIdx >= filtered.length) return;
    final entry = filtered[newIdx];

    if (!_pokemonData.containsKey(entry.speciesId)) {
      final batch = await _api.fetchPokemonBatch([entry.speciesId]);
      if (!mounted) return;
      for (final p in batch) _pokemonData[p['id'] as int] = p;
    }

    final pokemon = _buildPokemon(entry.speciesId);
    if (pokemon == null || !detailContext.mounted) return;

    bool isCaught = _caughtMap[entry.speciesId] ?? false;

    final prevEntry = newIdx > 0 ? filtered[newIdx - 1] : null;
    final nextEntry = newIdx < filtered.length - 1 ? filtered[newIdx + 1] : null;

    for (final e in [prevEntry, nextEntry]) {
      if (e != null && !_pokemonData.containsKey(e.speciesId)) {
        _api.fetchPokemonBatch([e.speciesId]).then((batch) {
          if (mounted) for (final p in batch) _pokemonData[p['id'] as int] = p;
        });
      }
    }

    String? prevName, nextName; int? prevId, nextId;
    if (prevEntry != null) {
      final d = _pokemonData[prevEntry.speciesId];
      if (d != null) { final r = (d['name'] as String).split('-').first; prevName = r[0].toUpperCase() + r.substring(1); prevId = d['id'] as int; }
    }
    if (nextEntry != null) {
      final d = _pokemonData[nextEntry.speciesId];
      if (d != null) { final r = (d['name'] as String).split('-').first; nextName = r[0].toUpperCase() + r.substring(1); nextId = d['id'] as int; }
    }

    final onToggle = () async {
      isCaught = !isCaught;
      await _storage.setCaught(_effectivePokedexId, entry.speciesId, isCaught);
      if (mounted) setState(() => _caughtMap[entry.speciesId] = isCaught);
    };

    final isNacional = _effectivePokedexId == 'nacional';
    final isGo = _effectivePokedexId.contains('pokémon_go') || _effectivePokedexId.contains('pokemon_go');
    final isPokopia = _effectivePokedexId.contains('pokopia');

    Navigator.of(detailContext).pushReplacement(PageRouteBuilder(
      pageBuilder: (rc, __, ___) {
        onP() => _navigateFromDetail(rc, filtered, newIdx - 1);
        onN() => _navigateFromDetail(rc, filtered, newIdx + 1);
        if (isNacional) {
          return NacionalDetailScreen(
            pokemon: pokemon, caught: isCaught, onToggleCaught: onToggle,
            prevName: prevName, prevId: prevId, nextName: nextName, nextId: nextId,
            onPrev: prevEntry != null ? onP : null, onNext: nextEntry != null ? onN : null,
          );
        } else if (isGo) {
          return GoDetailScreen(
            pokemon: pokemon, caught: isCaught, onToggleCaught: onToggle,
            prevName: prevName, prevId: prevId, nextName: nextName, nextId: nextId,
            onPrev: prevEntry != null ? onP : null, onNext: nextEntry != null ? onN : null,
          );
        } else if (isPokopia) {
          return PokopiaDetailScreen(pokemon: pokemon, caught: isCaught, onToggleCaught: onToggle);
        } else {
          return SwitchDetailScreen(
            pokemon: pokemon, caught: isCaught, onToggleCaught: onToggle,
            pokedexId: _effectivePokedexId,
            prevName: prevName, prevId: prevId, nextName: nextName, nextId: nextId,
            onPrev: prevEntry != null ? onP : null, onNext: nextEntry != null ? onN : null,
          );
        }
      },
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 200),
    ));
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
        automaticallyImplyLeading: false,
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
                onChanged: (v) {
                  setState(() => _searchQuery = v);
                  _loadPage(0);
                },
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.pokedexName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  Text(
                    '$caught / ${_entriesBySection.values.fold(0, (s, l) => s + l.length) == 0 ? widget.totalPokemon : _entriesBySection.values.fold(0, (s, l) => s + l.length)} ${_isPokopia ? 'encontrados' : 'capturados'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
        actions: [
          if (_searchOpen)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                _searchOpen = false;
                _searchQuery = '';
                _searchController.clear();
                _loadPage(0);
              }),
            )
          else ...[
            IconButton(icon: const Icon(Icons.search), onPressed: () => setState(() => _searchOpen = true)),
            IconButton(icon: const Icon(Icons.filter_list), onPressed: _showFilterSheet),
            Builder(builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
            )),
          ],
        ],
      ),
      endDrawer: _buildDrawer(),
      bottomNavigationBar: _buildBottomNav(),
      body: Column(
        children: [
          // Filtro de jogo — aparece abaixo do AppBar
          if (!_searchOpen) _buildGameFilterBar(),
          // Abas Standard / Event (só Pokopia base)
          if (_isPokopiaBase && _pokopiaTabController != null)
            _buildPokopiaTabBar(),
          // Chips de seção (jogos com DLC ou Nacional com gens)
          if (_sections.length > 1) _buildSectionChips(),
          if (_isNacional) _buildGenChips(),
          Expanded(child: _buildBody(filtered)),
        ],
      ),
    );
  }

  Widget _buildPokopiaTabBar() {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 0,
      color: scheme.surface,
      child: TabBar(
        controller: _pokopiaTabController,
        tabs: const [
          Tab(text: 'Standard'),
          Tab(text: 'Event'),
        ],
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: scheme.primary,
        tabAlignment: TabAlignment.fill,
        dividerColor: scheme.outlineVariant,
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
            return ValueListenableBuilder<String>(
              valueListenable: defaultSpriteNotifier,
              builder: (_, sprite, __) => _PokemonCard(
                entry: entry,
                data: data,
                caught: _caughtMap[entry.speciesId] ?? false,
                defaultSprite: sprite,
                onLongPress: () => _toggleCatch(entry.speciesId),
                onTap: () => _openDetail(entry),
              ),
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
        currentTypes: _filterTypes,
        currentSpecialties: _filterSpecialties,
        currentSort: _sortBy,
        currentDir: _sortDir,
        isPokopia: _isPokopia,
        onApply: (status, types, specialties, sort, dir) {
          setState(() {
            _filterStatus     = status;
            _filterTypes      = types;
            _filterSpecialties = specialties;
            _sortBy           = sort;
            _sortDir          = dir;
            _currentPage      = 0;
            _visibleEntries   = [];
          });
          _loadPage(0);
          Navigator.pop(ctx);
        },
      ),
    );
  }
  // ── Dados de jogos (para filtro) ────────────────────────────
  static const _gameGenerations = {
    'Red / Blue': [1], 'Yellow': [1],
    'Gold / Silver': [1,2], 'Crystal': [1,2],
    'Ruby / Sapphire': [1,2,3], 'FireRed / LeafGreen (GBA)': [1], 'Emerald': [1,2,3],
    'Diamond / Pearl': [1,2,3,4], 'Platinum': [1,2,3,4], 'HeartGold / SoulSilver': [1,2,3,4],
    'Black / White': [1,2,3,4,5], 'Black 2 / White 2': [1,2,3,4,5],
    'X / Y': [1,2,3,4,5,6], 'Omega Ruby / Alpha Sapphire': [1,2,3,4,5,6],
    'Sun / Moon': [1,2,3,4,5,6,7], 'Ultra Sun / Ultra Moon': [1,2,3,4,5,6,7],
    "Let\'s Go Pikachu / Eevee": [1],
    'Sword / Shield': [1,2,3,4,5,6,7,8],
    'Brilliant Diamond / Shining Pearl': [1,2,3,4],
    'Legends: Arceus': [1,2,3,4,8],
    'Scarlet / Violet': [1,2,3,4,5,6,7,8,9],
    'Legends: Z-A': [1,2,3,4,5,6,7,8,9],
    'FireRed / LeafGreen': [1],
    'Nacional': [1,2,3,4,5,6,7,8,9],
    'Pokémon GO': [1,2,3,4,5,6,7,8,9],
  };

  static const _gameColors = {
    'Nacional':                             [0xFFE8524A, 0xFFB71C1C],
    'Pokémon GO':                           [0xFF4285F4, 0xFF0D47A1],
    'Red / Blue':                           [0xFFE53935, 0xFF1565C0],
    'Yellow':                               [0xFFFDD835, 0xFFFF8F00],
    'Gold / Silver':                        [0xFFFFCA28, 0xFFB0BEC5],
    'Crystal':                              [0xFF29B6F6, 0xFFE1F5FE],
    'Ruby / Sapphire':                      [0xFFE53935, 0xFF1E88E5],
    'FireRed / LeafGreen (GBA)':            [0xFFEF5350, 0xFF43A047],
    'Emerald':                              [0xFF43A047, 0xFF00BCD4],
    'Diamond / Pearl':                      [0xFF90CAF9, 0xFFF48FB1],
    'Platinum':                             [0xFF78909C, 0xFFCFD8DC],
    'HeartGold / SoulSilver':               [0xFFFFCA28, 0xFFB0BEC5],
    'Black / White':                        [0xFF424242, 0xFFBDBDBD],
    'Black 2 / White 2':                    [0xFF1A237E, 0xFFE0E0E0],
    'X / Y':                                [0xFF1565C0, 0xFFE53935],
    'Omega Ruby / Alpha Sapphire':          [0xFFE53935, 0xFF1E88E5],
    'Sun / Moon':                           [0xFFFF8F00, 0xFF7B1FA2],
    'Ultra Sun / Ultra Moon':               [0xFFFF6F00, 0xFF4A148C],
    "Let\'s Go Pikachu / Eevee":           [0xFFFDD835, 0xFF8D6E63],
    'Sword / Shield':                       [0xFF42A5F5, 0xFFEF5350],
    'Brilliant Diamond / Shining Pearl':    [0xFF42A5F5, 0xFFEC407A],
    'Legends: Arceus':                      [0xFFFFCA28, 0xFFFFFDE7],
    'Scarlet / Violet':                     [0xFFEF6C00, 0xFF7B1FA2],
    'Legends: Z-A':                         [0xFF546E7A, 0xFFFFD54F],
    'FireRed / LeafGreen':                  [0xFFEF5350, 0xFF43A047],
  };

  // Filtro de jogo — estado
  String? _selectedGameName; // null = jogo atual do widget

  String get _activeGameName => _selectedGameName ?? widget.pokedexName;

  static final List<String> _allGameNames = [
    'Nacional', 'Pokémon GO',
    'Red / Blue', 'Yellow',
    'Gold / Silver', 'Crystal',
    'Ruby / Sapphire', 'FireRed / LeafGreen (GBA)', 'Emerald',
    'Diamond / Pearl', 'Platinum', 'HeartGold / SoulSilver',
    'Black / White', 'Black 2 / White 2',
    'X / Y', 'Omega Ruby / Alpha Sapphire',
    'Sun / Moon', 'Ultra Sun / Ultra Moon',
    "Let's Go Pikachu / Eevee",
    'Sword / Shield', 'Brilliant Diamond / Shining Pearl',
    'Legends: Arceus', 'Scarlet / Violet', 'Legends: Z-A',
    'FireRed / LeafGreen',
  ];

  static final Map<String, String> _gameToPokedexId = {
    'Nacional':                           'nacional',
    'Pokémon GO':                         'pokémon_go',
    'Red / Blue':                         'red___blue',
    'Yellow':                             'yellow',
    'Gold / Silver':                      'gold___silver',
    'Crystal':                            'crystal',
    'Ruby / Sapphire':                    'ruby___sapphire',
    'FireRed / LeafGreen (GBA)':          'firered___leafgreen_(gba)',
    'Emerald':                            'emerald',
    'Diamond / Pearl':                    'diamond___pearl',
    'Platinum':                           'platinum',
    'HeartGold / SoulSilver':             'heartgold___soulsilver',
    'Black / White':                      'black___white',
    'Black 2 / White 2':                  'black_2___white_2',
    'X / Y':                              'x___y',
    'Omega Ruby / Alpha Sapphire':        'omega_ruby___alpha_sapphire',
    'Sun / Moon':                         'sun___moon',
    'Ultra Sun / Ultra Moon':             'ultra_sun___ultra_moon',
    "Let's Go Pikachu / Eevee":          "let's_go_pikachu___eevee",
    'Sword / Shield':                     'sword___shield',
    'Brilliant Diamond / Shining Pearl':  'brilliant_diamond___shining_pearl',
    'Legends: Arceus':                    'legends:_arceus',
    'Scarlet / Violet':                   'scarlet___violet',
    'Legends: Z-A':                       'legends:_z-a',
    'FireRed / LeafGreen':                'firered___leafgreen',
  };

  static final Map<String, int> _gameTotal = {
    'Nacional': 1025, 'Pokémon GO': 941,
    'Red / Blue': 151, 'Yellow': 151,
    'Gold / Silver': 251, 'Crystal': 251,
    'Ruby / Sapphire': 386, 'FireRed / LeafGreen (GBA)': 386, 'Emerald': 386,
    'Diamond / Pearl': 493, 'Platinum': 493, 'HeartGold / SoulSilver': 493,
    'Black / White': 649, 'Black 2 / White 2': 649,
    'X / Y': 721, 'Omega Ruby / Alpha Sapphire': 721,
    'Sun / Moon': 807, 'Ultra Sun / Ultra Moon': 807,
    "Let's Go Pikachu / Eevee": 153,
    'Sword / Shield': 400, 'Brilliant Diamond / Shining Pearl': 493,
    'Legends: Arceus': 242, 'Scarlet / Violet': 400,
    'Legends: Z-A': 132, 'FireRed / LeafGreen': 386,
  };

  // ── Filtro de jogo ────────────────────────────────────────────

  Widget _buildGameFilterBar() {
    final scheme = Theme.of(context).colorScheme;
    final gameName = _activeGameName;
    final colors = _gameColors[gameName];
    final c1 = colors != null ? Color(colors[0]) : scheme.primary;
    final c2 = colors != null ? Color(colors[1]) : scheme.primary;
    final gens = _gameGenerations[gameName];
    final genLabel = gens != null ? 'Gen ${gens.first}${gens.length > 1 ? "–${gens.last}" : ""}' : '';

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(
          color: scheme.outlineVariant, width: 0.5))),
      child: GestureDetector(
        onTap: _showGamePicker,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [c1.withOpacity(0.15), c2.withOpacity(0.15)]),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: c1.withOpacity(0.4), width: 1),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 10, height: 10,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [c1, c2]),
                shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(gameName,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
            if (genLabel.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(genLabel,
                style: TextStyle(fontSize: 10,
                  color: scheme.onSurfaceVariant)),
            ],
            const SizedBox(width: 6),
            Icon(Icons.keyboard_arrow_down, size: 16,
              color: scheme.onSurfaceVariant),
          ]),
        ),
      ),
    );
  }

  void _showGamePicker() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _GamePickerSheet(
        games: _allGameNames,
        gameColors: _gameColors,
        gameGenerations: _gameGenerations,
        selected: _activeGameName,
      ),
    );
    if (result == null || !mounted) return;
    if (result == _activeGameName) return;

    final newPokedexId = _gameToPokedexId[result] ?? result
        .toLowerCase().replaceAll(' ', '_').replaceAll('/', '_').replaceAll("'", '');
    final newTotal = _gameTotal[result] ?? 0;

    await StorageService().setLastPokedexId(newPokedexId);

    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (_) => PokedexScreen(
        pokedexId: newPokedexId,
        pokedexName: result,
        totalPokemon: newTotal,
      ),
    ));
  }

  // ── Bottom Nav ────────────────────────────────────────────────

  Widget _buildBottomNav() {
    const items = [
      (0, Icons.home_outlined,         'Início'),
      (1, Icons.style_outlined,        'Pocket'),
      (2, Icons.public_outlined,       'GO'),
      (3, Icons.nature_people_outlined,'Pokopia'),
    ];
    return SafeArea(child: Container(
      height: 62,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant, width: 0.5))),
      child: Row(children: items.map((item) {
        final isActive = _navIndex == item.$1;
        final color = isActive
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurfaceVariant;
        return Expanded(child: InkWell(
          onTap: () {
            if (item.$1 == 0) { setState(() => _navIndex = 0); return; }
            if (item.$1 == 1) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PocketHubScreen()));
              return;
            }
            if (item.$1 == 2) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const GoHubScreen()));
              return;
            }
            if (item.$1 == 3) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PokopiaHubScreen()));
              return;
            }
          },
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(item.$2, size: 22, color: color),
            const SizedBox(height: 2),
            Text(item.$3, style: TextStyle(fontSize: 10,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: color)),
          ]),
        ));
      }).toList()),
    ));
  }

  // ── Drawer ────────────────────────────────────────────────────

  Widget _buildDrawer() {
    final scheme = Theme.of(context).colorScheme;
    return Drawer(child: SafeArea(child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Text('Menu', style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700, fontSize: 18))),
        Divider(color: scheme.outlineVariant),
        ListTile(leading: const Icon(Icons.sports_martial_arts_outlined, size: 22),
          title: const Text('Golpes', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20), dense: true,
          onTap: () { Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const MovesListScreen())); }),
        ListTile(leading: const Icon(Icons.auto_awesome_outlined, size: 22),
          title: const Text('Habilidades', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20), dense: true,
          onTap: () { Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const AbilitiesListScreen())); }),
        ListTile(leading: const Icon(Icons.psychology_outlined, size: 22),
          title: const Text('Naturezas', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20), dense: true,
          onTap: () { Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const NaturesListScreen())); }),
        Divider(color: scheme.outlineVariant),
        ListTile(leading: const Icon(Icons.groups_2_outlined, size: 22),
          title: const Text('Times', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20), dense: true,
          onTap: () { Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const TeamsScreen())); }),
        ListTile(leading: const Icon(Icons.inventory_2_outlined, size: 22),
          title: const Text('Itens', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20), dense: true,
          onTap: () { Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ItemsListScreen())); }),
        const Spacer(),
        Divider(color: scheme.outlineVariant),
        ListTile(leading: const Icon(Icons.settings_outlined, size: 22),
          title: const Text('Configurações', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20), dense: true,
          onTap: () async { Navigator.pop(context);
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())); }),
        const SizedBox(height: 8),
      ],
    )));
  }

}

// ─── CARD DE POKÉMON ─────────────────────────────────────────────

String pokemonSpriteAsset(int id, String type) {
  switch (type) {
    case 'pixel':   return 'assets/sprites/pixel/$id.webp';
    case 'home':    return 'assets/sprites/home/$id.webp';
    case 'artwork':
    default:        return 'assets/sprites/artwork/$id.webp';
  }
}

class _PokemonCard extends StatelessWidget {
  final _Entry entry;
  final Map<String, dynamic>? data;
  final bool caught;
  final String defaultSprite;
  final VoidCallback onLongPress;
  final VoidCallback onTap;

  const _PokemonCard({
    required this.entry,
    required this.data,
    required this.caught,
    required this.defaultSprite,
    required this.onLongPress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (data == null) return _SkeletonCard();

    final rawName = data!['name'] as String;
    final baseName = rawName.split('-').first;
    final displayName = baseName[0].toUpperCase() + baseName.substring(1);

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
                      child: Image.asset(
                        pokemonSpriteAsset(entry.speciesId, defaultSprite),
                        fit: BoxFit.contain,
                        errorBuilder: (_, error, ___) {
                          debugPrint('SPRITE FAIL: ${pokemonSpriteAsset(entry.speciesId, defaultSprite)} — $error');
                          return const Icon(Icons.catching_pokemon, size: 40);
                        },
                      ),
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
  final Set<String> currentTypes;
  final Set<String> currentSpecialties;
  final String currentSort;
  final String currentDir;
  final bool isPokopia;
  final void Function(String, Set<String>, Set<String>, String, String) onApply;

  const _FilterSheet({
    required this.currentStatus,
    required this.currentTypes,
    required this.currentSpecialties,
    required this.currentSort,
    required this.currentDir,
    required this.isPokopia,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String _status;
  late Set<String> _types;
  late Set<String> _specialties;
  late String _sort;
  late String _dir;

  @override
  void initState() {
    super.initState();
    _status      = widget.currentStatus;
    _types       = Set.from(widget.currentTypes);
    _specialties = Set.from(widget.currentSpecialties);
    _sort        = widget.currentSort;
    _dir         = widget.currentDir;
  }

  void _toggleType(String typeKey) {
    setState(() {
      if (_types.contains(typeKey)) {
        _types.remove(typeKey);
      } else if (_types.length < 2) {
        _types.add(typeKey);
      } else {
        _types.remove(_types.first);
        _types.add(typeKey);
      }
    });
  }

  List<String> get _statusOptions => widget.isPokopia
      ? ['todos', 'encontrados', 'não encontrados']
      : ['todos', 'capturados', 'não capturados'];

  bool get _hasActiveFilter =>
      _specialties.isNotEmpty ||
      _types.isNotEmpty ||
      _status != 'todos' ||
      _sort != 'numero' ||
      _dir != 'asc';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Cabeçalho
          Row(children: [
            Expanded(child: Text('Filtros',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600))),
            if (_hasActiveFilter)
              TextButton(
                onPressed: () => setState(() {
                  _status      = 'todos';
                  _types       = {};
                  _specialties = {};
                  _sort        = 'numero';
                  _dir         = 'asc';
                }),
                child: const Text('Limpar'),
              ),
          ]),
          const SizedBox(height: 16),

          // ── Status ──────────────────────────────────────────────
          Text('Status', style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 0.8)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, children: [
            for (final s in _statusOptions)
              ChoiceChip(
                label: Text(s[0].toUpperCase() + s.substring(1)),
                selected: _status == s,
                onSelected: (_) => setState(() => _status = s),
              ),
          ]),
          const SizedBox(height: 20),

          // ── Especialidade (só Pokopia) ───────────────────────────
          if (widget.isPokopia) ...[
            Row(children: [
              Expanded(child: Text('Especialidade',
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 0.8))),
              if (_specialties.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() => _specialties = {}),
                  child: Text('Limpar',
                    style: TextStyle(fontSize: 12, color: scheme.primary)),
                ),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final sp in _allSpecialties)
                _buildSpecialtyChip(sp, scheme),
            ]),
            const SizedBox(height: 20),
          ],

          // ── Tipo (só não-Pokopia) ────────────────────────────────
          if (!widget.isPokopia) ...[
            Row(children: [
              Expanded(child: Text('Tipo',
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 0.8))),
              if (_types.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() => _types = {}),
                  child: Text('Limpar',
                    style: TextStyle(fontSize: 12, color: scheme.primary)),
                ),
            ]),
            const SizedBox(height: 4),
            Text('Selecione até 2 tipos',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final e in _typesPt.entries)
                _buildTypeChip(e.key, e.value),
            ]),
            const SizedBox(height: 20),
          ],

          // ── Ordenar por ──────────────────────────────────────────
          Text('Ordenar por', style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 0.8)),
          const SizedBox(height: 8),
          Row(children: [
            for (final s in [('numero', 'Número'), ('nome', 'Nome')])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(s.$2),
                  selected: _sort == s.$1,
                  onSelected: (_) => setState(() => _sort = s.$1),
                ),
              ),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() => _dir = _dir == 'asc' ? 'desc' : 'asc'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    _dir == 'asc' ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(_dir == 'asc' ? 'Crescente' : 'Decrescente',
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 24),

          // ── Aplicar ──────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => widget.onApply(_status, _types, _specialties, _sort, _dir),
              child: const Text('Aplicar'),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildSpecialtyChip(String specialty, ColorScheme scheme) {
    final selected = _specialties.contains(specialty);
    return GestureDetector(
      onTap: () => setState(() {
        if (selected) {
          _specialties.remove(specialty);
        } else {
          _specialties.add(specialty);
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 0 : 1,
          ),
        ),
        child: Text(specialty,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
          )),
      ),
    );
  }

  Widget _buildTypeChip(String typeKey, String typePt) {
    final selected = _types.contains(typeKey);
    final color    = TypeColors.fromType(typePt);
    return GestureDetector(
      onTap: () => _toggleType(typeKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color : color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: selected ? color : color.withOpacity(0.3),
            width: selected ? 0 : 1,
          ),
        ),
        child: Text(
          typePt,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}


// Lista de todas as especialidades para o filtro Pokopia
const _allSpecialties = [
  'Appraise', 'Build', 'Bulldoze', 'Burn', 'Chop', 'Collect',
  'Crush', 'DJ', 'Dream Island', 'Eat', 'Engineer', 'Explode',
  'Fly', 'Gather', 'Gather Honey', 'Generate', 'Grow', 'Hype',
  'Illuminate', 'Litter', 'Paint', 'Party', 'Rarify', 'Recycle',
  'Search', 'Storage', 'Teleport', 'Trade', 'Transform', 'Water', 'Yawn',
];

// ─── GAME PICKER SHEET ───────────────────────────────────────────

class _GamePickerSheet extends StatelessWidget {
  final List<String> games;
  final Map<String, List<int>> gameColors;
  final Map<String, List<int>> gameGenerations;
  final String selected;
  const _GamePickerSheet({
    required this.games, required this.gameColors,
    required this.gameGenerations, required this.selected});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.65, minChildSize: 0.4, maxChildSize: 0.92, expand: false,
      builder: (_, ctrl) => Column(children: [
        const SizedBox(height: 8),
        Container(width: 40, height: 4, decoration: BoxDecoration(
          color: scheme.outlineVariant, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 12),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('Selecionar Jogo',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
        const SizedBox(height: 8),
        Divider(height: 1, color: scheme.outlineVariant),
        Expanded(child: ListView.builder(
          controller: ctrl,
          itemCount: games.length,
          itemBuilder: (_, i) {
            final name = games[i];
            final colors = gameColors[name];
            final c1 = colors != null ? Color(colors[0]) : scheme.primary;
            final c2 = colors != null ? Color(colors[1]) : scheme.primary;
            final gens = gameGenerations[name];
            final genStr = gens != null
                ? 'Gen ${gens.first}${gens.length > 1 ? "–${gens.last}" : ""}'
                : '';
            final isSelected = name == selected;
            return ListTile(
              leading: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [c1.withOpacity(0.9), c2.withOpacity(0.9)]),
                  borderRadius: BorderRadius.circular(6)),
              ),
              title: Text(name, style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? scheme.primary : null)),
              subtitle: genStr.isNotEmpty
                  ? Text(genStr, style: const TextStyle(fontSize: 11)) : null,
              trailing: isSelected
                  ? Icon(Icons.check, color: scheme.primary, size: 18) : null,
              onTap: () => Navigator.pop(context, name),
            );
          },
        )),
      ]),
    );
  }
}