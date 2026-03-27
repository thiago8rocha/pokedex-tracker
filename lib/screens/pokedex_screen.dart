import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pokedex_tracker/services/pokeapi_service.dart';
import 'package:pokedex_tracker/services/storage_service.dart';
import 'package:pokedex_tracker/services/dex_bundle_service.dart';
import 'package:pokedex_tracker/services/pokedex_data_service.dart';
import 'package:pokedex_tracker/screens/detail/detail_shared.dart'
    show defaultSpriteNotifier, typeNamePt, typeIconColors, TypeBadge;
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

  String get _pokedexDisplayTitle {
    final name = widget.pokedexName;
    final display = name == 'Nacional' ? 'National'
        : name == 'Pokémon GO' ? 'GO'
        : name;
    return 'Pokédex - $display';
  }
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
      // _selectedGens usa números ("1","2"...) — converter para labels ("Gen I","Gen II"...)
      final genLabels = _selectedGens.map((n) {
        const m = {'1':'Gen I','2':'Gen II','3':'Gen III','4':'Gen IV','5':'Gen V',
                   '6':'Gen VI','7':'Gen VII','8':'Gen VIII','9':'Gen IX'};
        return m[n] ?? n;
      }).toSet();
      final genRanges = nationalGens.where((g) => genLabels.contains(g.label)).toList();
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
      final qIsNumeric = RegExp(r'^\d+$').hasMatch(q);
      entries = entries.where((e) {
        final svc = PokedexDataService.instance;

        if (qIsNumeric) {
          // Busca numérica: match exato ignorando zeros à esquerda
          // "1" == "001", "007" == "7", "025" == "25"
          final qNum = int.tryParse(q);
          if (qNum != null && e.entryNumber == qNum) return true;
          return false;
        }

        // Busca por nome (substring no nome em inglês)
        final name = svc.getName(e.speciesId).toLowerCase();
        if (name.contains(q)) return true;

        // Busca por tipo — apenas no nome PT traduzido (não no slug EN interno)
        for (final t in svc.getTypes(e.speciesId)) {
          final namePt = (_typesPt[t] ?? '').toLowerCase();
          if (namePt.isNotEmpty && namePt.contains(q)) return true;
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
  /// Retorna o path do asset local para o sprite do pokémon.
  /// Shiny ainda vem da rede pois não está bundlado localmente.
  String _buildSpriteUrl(int id, String type) {
    switch (type) {
      case 'pixel':   return 'assets/sprites/pixel/$id.webp';
      case 'home':    return 'assets/sprites/home/$id.webp';
      case 'artwork':
      default:        return 'assets/sprites/artwork/$id.webp';
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
  }

  // ─── DETALHE ──────────────────────────────────────────────────────

  /// Constrói um Pokemon a partir do speciesId — usa dados locais do bundle.
  Pokemon? _buildPokemon(int speciesId, {required int entryNumber}) {
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
      entryNumber:         entryNumber,
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

    final pokemon = _buildPokemon(entry.speciesId, entryNumber: entry.entryNumber);
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
      _prevId = prevEntry.entryNumber;
      final d = _pokemonData[prevEntry.speciesId];
      if (d != null) {
        final raw = (d['name'] as String).split('-').first;
        _prevName = raw[0].toUpperCase() + raw.substring(1);
      } else {
        _prevName = PokedexDataService.instance.getName(prevEntry.speciesId);
      }
    }
    if (nextEntry != null) {
      _nextId = nextEntry.entryNumber;
      final d = _pokemonData[nextEntry.speciesId];
      if (d != null) {
        final raw = (d['name'] as String).split('-').first;
        _nextName = raw[0].toUpperCase() + raw.substring(1);
      } else {
        _nextName = PokedexDataService.instance.getName(nextEntry.speciesId);
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

    // Captura o NavigatorState antes do push — permanece válido mesmo após pushReplacement
    final nav = Navigator.of(context);

    // Closures capturando filtered e idx — não dependem do routeContext
    final onPrevCallback = prevEntry != null
        ? () => _navigateFromDetail(nav, filtered, idx - 1)
        : null;
    final onNextCallback = nextEntry != null
        ? () => _navigateFromDetail(nav, filtered, idx + 1)
        : null;

    await nav.push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) {
          if (isNacional) {
            return NacionalDetailScreen(
              pokemon: pokemon, caught: isCaught, onToggleCaught: onToggle,
              prevName: _prevName, prevId: _prevId,
              nextName: _nextName, nextId: _nextId,
              onPrev: onPrevCallback, onNext: onNextCallback,
            );
          } else if (isGo) {
            return GoDetailScreen(
              pokemon: pokemon, caught: isCaught, onToggleCaught: onToggle,
              prevName: _prevName, prevId: _prevId,
              nextName: _nextName, nextId: _nextId,
              onPrev: onPrevCallback, onNext: onNextCallback,
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
              onPrev: onPrevCallback, onNext: onNextCallback,
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
      NavigatorState nav, List<_Entry> filtered, int newIdx) async {
    if (newIdx < 0 || newIdx >= filtered.length) return;
    final entry = filtered[newIdx];

    if (!_pokemonData.containsKey(entry.speciesId)) {
      final batch = await _api.fetchPokemonBatch([entry.speciesId]);
      if (!mounted) return;
      for (final p in batch) _pokemonData[p['id'] as int] = p;
    }

    final pokemon = _buildPokemon(entry.speciesId, entryNumber: entry.entryNumber);
    if (pokemon == null) return;

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
      prevId = prevEntry.entryNumber;
      if (d != null) { final r = (d['name'] as String).split('-').first; prevName = r[0].toUpperCase() + r.substring(1); }
      else { prevName = PokedexDataService.instance.getName(prevEntry.speciesId); }
    }
    if (nextEntry != null) {
      final d = _pokemonData[nextEntry.speciesId];
      nextId = nextEntry.entryNumber;
      if (d != null) { final r = (d['name'] as String).split('-').first; nextName = r[0].toUpperCase() + r.substring(1); }
      else { nextName = PokedexDataService.instance.getName(nextEntry.speciesId); }
    }

    final onToggle = () async {
      isCaught = !isCaught;
      await _storage.setCaught(_effectivePokedexId, entry.speciesId, isCaught);
      if (mounted) setState(() => _caughtMap[entry.speciesId] = isCaught);
    };

    final isNacional = _effectivePokedexId == 'nacional';
    final isGo = _effectivePokedexId.contains('pokémon_go') || _effectivePokedexId.contains('pokemon_go');
    final isPokopia = _effectivePokedexId.contains('pokopia');

    nav.pushReplacement(PageRouteBuilder(
      pageBuilder: (rc, __, ___) {
        final onP = newIdx > 0
            ? () => _navigateFromDetail(nav, filtered, newIdx - 1)
            : null;
        final onN = newIdx < filtered.length - 1
            ? () => _navigateFromDetail(nav, filtered, newIdx + 1)
            : null;
        if (isNacional) {
          return NacionalDetailScreen(
            pokemon: pokemon, caught: isCaught, onToggleCaught: onToggle,
            prevName: prevName, prevId: prevId, nextName: nextName, nextId: nextId,
            onPrev: onP, onNext: onN,
          );
        } else if (isGo) {
          return GoDetailScreen(
            pokemon: pokemon, caught: isCaught, onToggleCaught: onToggle,
            prevName: prevName, prevId: prevId, nextName: nextName, nextId: nextId,
            onPrev: onP, onNext: onN,
          );
        } else if (isPokopia) {
          return PokopiaDetailScreen(pokemon: pokemon, caught: isCaught, onToggleCaught: onToggle);
        } else {
          return SwitchDetailScreen(
            pokemon: pokemon, caught: isCaught, onToggleCaught: onToggle,
            pokedexId: _effectivePokedexId,
            prevName: prevName, prevId: prevId, nextName: nextName, nextId: nextId,
            onPrev: onP, onNext: onN,
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
                  Text(_pokedexDisplayTitle,
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
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
          ],
        ],
      ),
      endDrawer: _buildDrawer(),
      bottomNavigationBar: _buildBottomNav(),
      body: Column(
        children: [
          // Filtro de jogo — aparece abaixo do AppBar
          if (!_searchOpen) _buildAllFiltersBar(),
          // Abas Standard / Event (só Pokopia base)
          if (_isPokopiaBase && _pokopiaTabController != null)
            _buildPokopiaTabBar(),
          // Chips de seção (jogos com DLC ou Nacional com gens)
          if (_sections.length > 1) _buildSectionChips(),
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
                onToggle: () => _toggleCatch(entry.speciesId),
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
            _filterStatus      = status;
            _filterTypes       = types;
            _filterSpecialties = specialties;
            _sortBy            = sort;
            _sortDir           = dir;
            _currentPage       = 0;
            _visibleEntries    = [];
          });
          _loadPage(0);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  // ── Barra de Geração + Tipo ──────────────────────────────────

  Widget _buildGenTypeFilterBar() {
    final scheme = Theme.of(context).colorScheme;
    final hasGen  = _selectedGens.isNotEmpty;
    final hasType = _filterTypes.isNotEmpty;

    String genLabel = hasGen
        ? _selectedGens.map((g) => 'Gen $g').join(', ')
        : 'Geração';
    if (genLabel.length > 20) genLabel = '${_selectedGens.length} gerações';

    String typeLabel = hasType
        ? _filterTypes.map((t) => typeNamePt[t] ?? t).join(' + ')
        : 'Tipo';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(
          color: scheme.outlineVariant, width: 0.5))),
      child: Row(children: [
        _FilterDropBtn(
          label: genLabel, active: hasGen,
          onTap: _showGenPicker,
          onClear: hasGen ? () {
            setState(() { _selectedGens.clear(); _currentPage = 0; _visibleEntries = []; });
            _loadPage(0);
          } : null,
        ),
        const SizedBox(width: 8),
        _FilterDropBtn(
          label: typeLabel, active: hasType,
          onTap: _showTypePicker,
          onClear: hasType ? () {
            setState(() { _filterTypes.clear(); _currentPage = 0; _visibleEntries = []; });
            _loadPage(0);
          } : null,
        ),
      ]),
    );
  }

  void _showGenPicker() async {
    // Gerações disponíveis para o jogo atual
    final gameName = _activeGameName;
    final availableInts = _gameGenerations[gameName] ?? [1,2,3,4,5,6,7,8,9];
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _GenDropSheet(
        available: availableInts.map((g) => g.toString()).toSet(),
        selected: Set.from(_selectedGens),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _selectedGens.clear();
      _selectedGens.addAll(result);
      _currentPage = 0;
      _visibleEntries = [];
    });
    _loadPage(0);
  }

  void _showTypePicker() async {
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _TypeDropSheet(selected: Set.from(_filterTypes)),
    );
    if (result == null || !mounted) return;
    setState(() {
      _filterTypes = result;
      _currentPage = 0;
      _visibleEntries = [];
    });
    _loadPage(0);
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
    'National': [1,2,3,4,5,6,7,8,9],
    'Pokémon GO': [1,2,3,4,5,6,7,8,9],
  };

  static const _gameColors = {
    'National':                             [0xFFE8524A, 0xFFB71C1C],
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

  String get _activeGameName {
    final n = _selectedGameName ?? widget.pokedexName;
    return n == 'Nacional' ? 'National' : n;
  }

  static final List<String> _allGameNames = [
    'National', 'Pokémon GO',
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
    'National':                           'nacional',
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
    'National': 1025, 'Pokémon GO': 941,
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

  Widget _buildAllFiltersBar() {
    final scheme = Theme.of(context).colorScheme;
    final gameName = _activeGameName;
    final colors = _gameColors[gameName];
    final c1 = colors != null ? Color(colors[0]) : scheme.primary;
    final c2 = colors != null ? Color(colors[1]) : scheme.primary;

    // Rótulo geração do jogo (a gen em que saiu, não as gens dos pokémon)
    // _gamesByGen contém a gen de lançamento de cada jogo
    int? launchGen;
    for (final entry in _gamesByGen.entries) {
      if (entry.value.any((g) => g['name'] == gameName)) {
        launchGen = entry.key; break;
      }
    }
    final genSuffix = launchGen != null ? '  Gen $launchGen' : '';

    final hasGen  = _selectedGens.isNotEmpty;
    final hasType = _filterTypes.isNotEmpty;

    String genLabel = hasGen
        ? _selectedGens.map((g) => 'Gen $g').join(', ')
        : 'Geração';
    if (genLabel.length > 14) genLabel = '${_selectedGens.length} gens';

    String typeLabel = hasType
        ? _filterTypes.map((t) => typeNamePt[t] ?? t).join(' + ')
        : 'Tipo';

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(
          color: scheme.outlineVariant, width: 0.5))),
      child: Row(children: [
        // ── Filtro de Jogo ──
        Expanded(
          flex: 5,
          child: GestureDetector(
            onTap: _showGamePicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [c1.withOpacity(0.15), c2.withOpacity(0.15)]),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: c1.withOpacity(0.45), width: 1)),
              child: Row(children: [
                Expanded(child: Text(
                  gameName + genSuffix,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                Icon(Icons.keyboard_arrow_down, size: 15,
                  color: scheme.onSurfaceVariant),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 6),
        // ── Filtro de Geração ──
        Expanded(
          flex: 3,
          child: _FilterDropBtn(
            label: genLabel, active: hasGen,
            onTap: _showGenPicker,
            onClear: hasGen ? () {
              setState(() { _selectedGens.clear(); _currentPage = 0; _visibleEntries = []; });
              _loadPage(0);
            } : null,
          ),
        ),
        const SizedBox(width: 6),
        // ── Filtro de Tipo ──
        Expanded(
          flex: 3,
          child: _FilterDropBtn(
            label: typeLabel, active: hasType,
            onTap: _showTypePicker,
            onClear: hasType ? () {
              setState(() { _filterTypes.clear(); _currentPage = 0; _visibleEntries = []; });
              _loadPage(0);
            } : null,
          ),
        ),
      ]),
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
      child: Builder(builder: (ctx) {
        final menuColor = Theme.of(context).colorScheme.onSurfaceVariant;
        return Row(children: [
          ...items.map((item) {
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
          }),
          // Menu (≡) após Pokopia — mesmo Expanded para alinhar igual
          Expanded(child: InkWell(
            onTap: () => Scaffold.of(ctx).openEndDrawer(),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.menu, size: 22, color: menuColor),
              const SizedBox(height: 2),
              Text('Menu', style: TextStyle(fontSize: 10, color: menuColor)),
            ]),
          )),
        ]);
      }),
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
  final VoidCallback onToggle;
  final VoidCallback onTap;

  const _PokemonCard({
    required this.entry,
    required this.data,
    required this.caught,
    required this.defaultSprite,
    required this.onLongPress,
    required this.onToggle,
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
          borderRadius: BorderRadius.circular(4),
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
                  // Badges com ícone — largura fixa para todos os tipos
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: types.map((type) {
                      final typeKey = type.toLowerCase();
                      final color = TypeColors.fromType(_pt(type));
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        width: 52,
                        height: 14,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.zero,
                        ),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Image.asset(
                            'assets/types/$typeKey.png',
                            width: 12, height: 12,
                            errorBuilder: (_, __, ___) => const SizedBox(width: 12),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            _pt(type),
                            style: const TextStyle(
                              fontSize: 8,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ]),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: onToggle,
                  child: Opacity(
                    opacity: caught ? 1.0 : 0.25,
                    child: CustomPaint(
                      size: const Size(16, 16),
                      painter: _PokeballPainter(),
                    ),
                  ),
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
          Row(children: [
            for (final s in _statusOptions)
              Expanded(child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => setState(() => _status = s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: _status == s
                          ? scheme.primary.withOpacity(0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _status == s ? scheme.primary : scheme.outlineVariant,
                        width: 1)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      if (_status == s) ...[
                        Icon(Icons.check, size: 13, color: scheme.primary),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        s == 'todos' ? 'Todos'
                            : s == 'capturados' ? 'Capturados'
                            : 'Não capturados',
                        style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w500,
                          color: _status == s ? scheme.primary : scheme.onSurface)),
                    ]),
                  ),
                ),
              )),
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



          // ── Ordenar por ──────────────────────────────────────────
          Text('Ordenar por', style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 0.8)),
          const SizedBox(height: 8),
          Row(children: [
            for (final s in [('numero', 'Número'), ('nome', 'Nome')])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _sort = s.$1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      color: _sort == s.$1
                          ? scheme.primary.withOpacity(0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _sort == s.$1 ? scheme.primary : scheme.outlineVariant,
                        width: 1)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (_sort == s.$1) ...[
                        Icon(Icons.check, size: 13, color: scheme.primary),
                        const SizedBox(width: 4),
                      ],
                      Text(s.$2, style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500,
                        color: _sort == s.$1 ? scheme.primary : scheme.onSurface)),
                    ]),
                  ),
                ),
              ),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() => _dir = _dir == 'asc' ? 'desc' : 'asc'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: scheme.outlineVariant, width: 1),
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
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
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

// ─── FILTER DROP BUTTON ──────────────────────────────────────────

class _FilterDropBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  const _FilterDropBtn({required this.label, required this.active,
    required this.onTap, this.onClear});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = active ? scheme.primary : scheme.onSurfaceVariant;
    final bg = active ? scheme.primary.withOpacity(0.10) : Colors.transparent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(10, 7, onClear != null ? 4 : 10, 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: active ? scheme.primary : scheme.outlineVariant, width: 1)),
        child: Row(children: [
          Expanded(child: Text(label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: fg))),
          if (onClear != null)
            GestureDetector(onTap: onClear,
              child: Icon(Icons.close, size: 13, color: fg))
          else
            Icon(Icons.keyboard_arrow_down, size: 14, color: fg),
        ]),
      ),
    );
  }
}

// ─── GAME PICKER SHEET ───────────────────────────────────────────

// Agrupamento de jogos por geração (a gen em que o jogo foi lançado)
const _gamesByGen = <int, List<Map<String, dynamic>>>{
  1: [
    {'name': 'Red / Blue',            'c1': 0xFFE53935, 'c2': 0xFF1565C0},
    {'name': 'Yellow',                'c1': 0xFFFDD835, 'c2': 0xFFFF8F00},
  ],
  2: [
    {'name': 'Gold / Silver',         'c1': 0xFFFFCA28, 'c2': 0xFFB0BEC5},
    {'name': 'Crystal',               'c1': 0xFF29B6F6, 'c2': 0xFFE1F5FE},
  ],
  3: [
    {'name': 'Ruby / Sapphire',       'c1': 0xFFE53935, 'c2': 0xFF1E88E5},
    {'name': 'FireRed / LeafGreen (GBA)', 'c1': 0xFFEF5350, 'c2': 0xFF43A047},
    {'name': 'Emerald',               'c1': 0xFF43A047, 'c2': 0xFF00BCD4},
  ],
  4: [
    {'name': 'Diamond / Pearl',       'c1': 0xFF90CAF9, 'c2': 0xFFF48FB1},
    {'name': 'Platinum',              'c1': 0xFF78909C, 'c2': 0xFFCFD8DC},
    {'name': 'HeartGold / SoulSilver','c1': 0xFFFFCA28, 'c2': 0xFFB0BEC5},
  ],
  5: [
    {'name': 'Black / White',         'c1': 0xFF424242, 'c2': 0xFFBDBDBD},
    {'name': 'Black 2 / White 2',     'c1': 0xFF1A237E, 'c2': 0xFFE0E0E0},
  ],
  6: [
    {'name': 'X / Y',                 'c1': 0xFF1565C0, 'c2': 0xFFE53935},
    {'name': 'Omega Ruby / Alpha Sapphire', 'c1': 0xFFE53935, 'c2': 0xFF1E88E5},
  ],
  7: [
    {'name': 'Sun / Moon',            'c1': 0xFFFF8F00, 'c2': 0xFF7B1FA2},
    {'name': 'Ultra Sun / Ultra Moon','c1': 0xFFFF6F00, 'c2': 0xFF4A148C},
    {'name': "Let's Go Pikachu / Eevee", 'c1': 0xFFFDD835, 'c2': 0xFF8D6E63},
  ],
  8: [
    {'name': 'Sword / Shield',        'c1': 0xFF42A5F5, 'c2': 0xFFEF5350},
    {'name': 'Brilliant Diamond / Shining Pearl', 'c1': 0xFF42A5F5, 'c2': 0xFFEC407A},
    {'name': 'Legends: Arceus',       'c1': 0xFFFFCA28, 'c2': 0xFFFFFDE7},
  ],
  9: [
    {'name': 'Scarlet / Violet',      'c1': 0xFFEF6C00, 'c2': 0xFF7B1FA2},
    {'name': 'Legends: Z-A',          'c1': 0xFF546E7A, 'c2': 0xFFFFD54F},
    {'name': 'FireRed / LeafGreen',   'c1': 0xFFEF5350, 'c2': 0xFF43A047},
  ],
};

const _specialGames = <Map<String, dynamic>>[
  {'name': 'National',   'c1': 0xFFE8524A, 'c2': 0xFFB71C1C},
  {'name': 'Pokémon GO', 'c1': 0xFF4285F4, 'c2': 0xFF0D47A1},
];

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final opacity = isDark ? 0.45 : 0.28;

    Widget gameCard(Map<String, dynamic> g) {
      final name = g['name'] as String;
      final c1 = Color(g['c1'] as int);
      final c2 = Color(g['c2'] as int);
      final isSelected = name == selected;
      return GestureDetector(
        onTap: () => Navigator.pop(context, name),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [c1.withOpacity(opacity), c2.withOpacity(opacity)]),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? scheme.primary : scheme.outlineVariant,
              width: isSelected ? 2 : 1)),
          child: Row(children: [
            Expanded(child: Text(name,
              style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: isSelected ? scheme.primary : scheme.onSurface))),
            if (isSelected)
              Icon(Icons.check_circle, size: 16, color: scheme.primary),
          ]),
        ),
      );
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.75, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
      builder: (_, ctrl) => Column(children: [
        const SizedBox(height: 8),
        Container(width: 40, height: 4, decoration: BoxDecoration(
          color: scheme.outlineVariant, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 12),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('Selecionar Jogo',
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700))),
        const SizedBox(height: 8),
        Divider(height: 1, color: scheme.outlineVariant),
        Expanded(child: ListView(controller: ctrl, padding: const EdgeInsets.all(12),
          children: [
            // Jogos especiais (Nacional + GO)
            ...(_specialGames.map((g) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: gameCard(g)))),
            const SizedBox(height: 4),
            // Grupos por geração
            ..._gamesByGen.entries.map((entry) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 6),
                  child: Text('Geração ${entry.key}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant, letterSpacing: 0.5))),
                ...entry.value.map((g) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: gameCard(g))),
              ],
            )),
          ],
        )),
      ]),
    );
  }
}

// ─── GEN PICKER SHEET ────────────────────────────────────────────

class _GenDropSheet extends StatefulWidget {
  final Set<String> available;
  final Set<String> selected;
  const _GenDropSheet({required this.available, required this.selected});
  @override State<_GenDropSheet> createState() => _GenDropSheetState();
}

class _GenDropSheetState extends State<_GenDropSheet> {
  late Set<String> _sel;
  @override void initState() { super.initState(); _sel = Set.from(widget.selected); }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final gens = widget.available.map(int.parse).toList()..sort();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        Container(width: 40, height: 4, decoration: BoxDecoration(
          color: scheme.outlineVariant, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 12),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Geração', style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
            TextButton(onPressed: () => Navigator.pop(context, <String>{}),
              child: const Text('Limpar')),
          ])),
        Divider(height: 1, color: scheme.outlineVariant),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(spacing: 8, runSpacing: 8,
            children: gens.map((g) {
              final gs = g.toString();
              final on = _sel.contains(gs);
              return GestureDetector(
                onTap: () => setState(() => on ? _sel.remove(gs) : _sel.add(gs)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: on ? scheme.primary : scheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: on ? scheme.primary : scheme.outlineVariant)),
                  child: Text('Geração $g', style: TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: on ? scheme.onPrimary : scheme.onSurface))),
              );
            }).toList()),
        ),
        const SizedBox(height: 16),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              onPressed: () => Navigator.pop(context, _sel),
              child: const Text('Aplicar')))),
        const SizedBox(height: 16),
      ]),
    );
  }
}

// ─── TYPE PICKER SHEET ────────────────────────────────────────────

class _TypeDropSheet extends StatefulWidget {
  final Set<String> selected;
  const _TypeDropSheet({required this.selected});
  @override State<_TypeDropSheet> createState() => _TypeDropSheetState();
}

class _TypeDropSheetState extends State<_TypeDropSheet> {
  late Set<String> _sel;
  @override void initState() { super.initState(); _sel = Set.from(widget.selected); }

  static const _types = ['normal','fire','water','electric','grass','ice',
    'fighting','poison','ground','flying','psychic','bug',
    'rock','ghost','dragon','dark','steel','fairy'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4, decoration: BoxDecoration(
            color: scheme.outlineVariant, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Selecione até dois tipos diferentes',
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
              TextButton(onPressed: () => Navigator.pop(context, <String>{}),
                child: const Text('Limpar')),
            ])),
          if (_sel.isNotEmpty)
            Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Align(alignment: Alignment.centerLeft,
                child: Text('${_sel.length}/2 selecionado(s)',
                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)))),
          Divider(height: 1, color: scheme.outlineVariant),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _types.map((t) {
                final on = _sel.contains(t);
                final disabled = !on && _sel.length >= 2;
                return GestureDetector(
                  onTap: disabled ? null
                      : () => setState(() => on ? _sel.remove(t) : _sel.add(t)),
                  child: Opacity(
                    opacity: disabled ? 0.35 : 1.0,
                    child: SizedBox(width: 118, child: TypeBadge(type: t)),
                  ),
                );
              }).toList(),
            ),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SizedBox(width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: () => Navigator.pop(context, _sel),
                child: const Text('Aplicar')))),
        ]),
      ),
    );
  }
}