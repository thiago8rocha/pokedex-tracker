import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pokedex_tracker/services/tcg_pocket_service.dart';
import 'package:pokedex_tracker/services/translation_warmup.dart';
import 'package:pokedex_tracker/screens/pocket/pocket_card_detail_screen.dart';
import 'package:pokedex_tracker/screens/pocket/pocket_rarity_widget.dart';

// ─── FILTRO DE COLEÇÃO ────────────────────────────────────────────

enum _CollectionFilter { all, owned, missing }

// ─── TELA DE LISTA ────────────────────────────────────────────────

class PocketCardListScreen extends StatefulWidget {
  final String setId;
  final String setName;

  const PocketCardListScreen({
    super.key,
    required this.setId,
    required this.setName,
  });

  @override
  State<PocketCardListScreen> createState() => _PocketCardListScreenState();
}

class _PocketCardListScreenState extends State<PocketCardListScreen> {
  PocketSet? _set;
  bool    _loading = true;
  String? _error;

  final Map<String, bool> _owned = {};

  bool              _isGrid    = false;
  bool              _searching = false;
  _CollectionFilter _filter    = _CollectionFilter.all;
  String            _search    = '';
  final _searchCtrl  = TextEditingController();
  final _searchFocus = FocusNode();

  String _prefKey(String cardId) => 'pocket_owned_${widget.setId}_$cardId';

  @override
  void initState() {
    super.initState();
    _loadSet();
    // Pré-traduzir todas as cartas do set em background
    TranslationWarmup.warmupSet(widget.setId);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadSet() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Tentar cache local primeiro — elimina rede no segundo acesso
      final prefs    = await SharedPreferences.getInstance();
      final cacheKey = '_pocket_set_' + widget.setId;
      final cached   = prefs.getString(cacheKey);

      PocketSet? set;
      if (cached != null) {
        try {
          set = PocketSet.fromJson(
            jsonDecode(cached) as Map<String, dynamic>,
            overrideName: kPocketSetMeta[widget.setId]?.namePt,
          );
        } catch (_) {}
      }

      if (set == null) {
        // Cache miss — busca na rede e persiste
        set = await TcgPocketService.fetchSet(widget.setId);
        if (set != null) {
          prefs.setString(cacheKey, jsonEncode({
            'id': set.id,
            'name': set.name,
            'totalCards': set.totalCards,
            'cards': set.cards.map((c) => {
              'id': c.id,
              'localId': c.localId,
              'name': c.name,
              'image': c.imageUrlLow?.replaceAll('/low.webp', ''),
              'rarity': c.rarity,
            }).toList(),
          }));
        }
      }

      if (mounted) {
        setState(() {
          _set     = set;
          _loading = false;
          if (set == null) _error = 'Erro ao carregar coleção';
        });
        if (set != null) await _loadOwned(set.cards);
      }
    } catch (_) {
      if (mounted) setState(() { _error = 'Erro ao carregar coleção'; _loading = false; });
    }
  }

  Future<void> _loadOwned(List<PocketCardBrief> cards) async {
    final prefs = await SharedPreferences.getInstance();
    final map   = <String, bool>{};
    for (final c in cards) {
      map[c.id] = prefs.getBool(_prefKey(c.id)) ?? false;
    }
    if (mounted) setState(() => _owned.addAll(map));
  }

  Future<void> _toggleOwned(String cardId) async {
    final next = !(_owned[cardId] ?? false);
    setState(() => _owned[cardId] = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey(cardId), next);
  }

  // Marcar/desmarcar todas as cartas visíveis de uma vez
  Future<void> _toggleAll() async {
    final cards = _filteredCards;
    if (cards.isEmpty) return;

    // Se todas marcadas → desmarcar; senão → marcar todas
    final allOwned = cards.every((c) => _owned[c.id] == true);
    final next = !allOwned;

    final prefs   = await SharedPreferences.getInstance();
    final updates = <String, bool>{};
    for (final c in cards) {
      updates[c.id] = next;
      await prefs.setBool(_prefKey(c.id), next);
    }
    if (mounted) setState(() => _owned.addAll(updates));
  }

  List<PocketCardBrief> get _filteredCards {
    if (_set == null) return [];
    var list = _set!.cards;

    if (_filter == _CollectionFilter.owned) {
      list = list.where((c) => _owned[c.id] == true).toList();
    } else if (_filter == _CollectionFilter.missing) {
      list = list.where((c) => _owned[c.id] != true).toList();
    }

    final q = _search.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((c) =>
        c.name.toLowerCase().contains(q) ||
        c.localId.toLowerCase().contains(q)
      ).toList();
    }

    return list;
  }

  // Conta apenas cartas com número ≤ total oficial (exclui secret rares / variantes)
  int get _collectibleTotal {
    if (_set == null) return 0;
    final official = _set!.totalCards;
    if (official <= 0) return _set!.cards.length;
    return _set!.cards.where((c) {
      final n = int.tryParse(c.localId);
      return n != null && n <= official;
    }).length;
  }

  int get _ownedCount {
    if (_set == null) return 0;
    final official = _set!.totalCards;
    return _owned.entries.where((e) {
      if (!e.value) return false;
      final card = _set!.cards.where((c) => c.id == e.key).firstOrNull;
      if (card == null) return false;
      if (official > 0) {
        final n = int.tryParse(card.localId);
        return n != null && n <= official;
      }
      return true;
    }).length;
  }

  void _openSearch() {
    setState(() => _searching = true);
    Future.delayed(
      const Duration(milliseconds: 50),
      () => _searchFocus.requestFocus(),
    );
  }

  void _closeSearch() {
    _searchCtrl.clear();
    _searchFocus.unfocus();
    setState(() { _searching = false; _search = ''; });
  }

  @override
  Widget build(BuildContext context) {
    final scheme     = Theme.of(context).colorScheme;
    final cards      = _filteredCards;
    final allMarked  = cards.isNotEmpty && cards.every((c) => _owned[c.id] == true);

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchCtrl,
                focusNode:  _searchFocus,
                onChanged:  (v) => setState(() => _search = v),
                decoration: const InputDecoration(
                  hintText: 'Buscar por nome ou número...',
                  border: InputBorder.none,
                ),
                style: const TextStyle(fontSize: 16),
              )
            : Text(widget.setName),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          // Botão busca — ao lado do toggle de visualização
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            tooltip: _searching ? 'Fechar busca' : 'Buscar',
            onPressed: _searching ? _closeSearch : _openSearch,
          ),
          // Toggle lista / grid
          IconButton(
            icon: Icon(_isGrid ? Icons.view_list_outlined : Icons.grid_view_outlined),
            tooltip: _isGrid ? 'Ver em lista' : 'Ver em grid',
            onPressed: () => setState(() => _isGrid = !_isGrid),
          ),
        ],
      ),
      body: _loading
          ? const _ListSkeleton()
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _loadSet)
              : Column(
                  children: [
                    // ── Filtros + progresso + adicionar todas ──────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      child: Row(
                        children: [
                          _FilterBtn(
                            label: 'Todas',
                            count: _collectibleTotal,
                            active: _filter == _CollectionFilter.all,
                            onTap: () => setState(() => _filter = _CollectionFilter.all),
                          ),
                          const SizedBox(width: 6),
                          _FilterBtn(
                            label: 'Tenho',
                            count: _ownedCount,
                            active: _filter == _CollectionFilter.owned,
                            onTap: () => setState(() => _filter = _CollectionFilter.owned),
                          ),
                          const SizedBox(width: 6),
                          _FilterBtn(
                            label: 'Faltam',
                            count: _collectibleTotal - _ownedCount,
                            active: _filter == _CollectionFilter.missing,
                            onTap: () => setState(() => _filter = _CollectionFilter.missing),
                          ),
                          const Spacer(),
                          // Contador
                          Text(
                            '$_ownedCount/$_collectibleTotal',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Botão "Adicionar / remover todas"
                          Tooltip(
                            message: allMarked ? 'Remover todas' : 'Adicionar todas',
                            child: GestureDetector(
                              onTap: cards.isEmpty ? null : _toggleAll,
                              child: Icon(
                                allMarked
                                    ? Icons.catching_pokemon
                                    : Icons.catching_pokemon_outlined,
                                size: 22,
                                color: cards.isEmpty
                                    ? scheme.onSurfaceVariant.withOpacity(0.25)
                                    : allMarked
                                        ? const Color(0xFFE53935)
                                        : scheme.onSurfaceVariant.withOpacity(0.55),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Grid ou Lista ──────────────────────────────
                    Expanded(
                      child: cards.isEmpty
                          ? Center(
                              child: Text(
                                _search.isNotEmpty
                                    ? 'Nenhuma carta encontrada'
                                    : _filter == _CollectionFilter.owned
                                        ? 'Nenhuma carta registrada ainda'
                                        : 'Coleção completa!',
                                style: TextStyle(color: scheme.onSurfaceVariant),
                              ),
                            )
                          : _isGrid
                              ? _CardGrid(
                                  cards:      cards,
                                  setId:      widget.setId,
                                  owned:      _owned,
                                  totalCards: _set?.totalCards,
                                  onToggle: _toggleOwned,
                                )
                              : _CardList(
                                  cards:      cards,
                                  setId:      widget.setId,
                                  owned:      _owned,
                                  totalCards: _set?.totalCards,
                                  onToggle: _toggleOwned,
                                ),
                    ),
                  ],
                ),
    );
  }
}

// ─── Botão de filtro ──────────────────────────────────────────────

class _FilterBtn extends StatelessWidget {
  final String label;
  final int    count;
  final bool   active;
  final VoidCallback onTap;

  const _FilterBtn({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color  = active ? scheme.primary : scheme.onSurfaceVariant;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: active ? scheme.primary : scheme.outlineVariant,
            width: active ? 2 : 1,
          ),
          color: active ? scheme.primary.withOpacity(0.08) : Colors.transparent,
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            fontSize: 11,
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
            color: color,
          ),
        ),
      ),
    );
  }
}

// ─── Grid 3 colunas ───────────────────────────────────────────────

class _CardGrid extends StatelessWidget {
  final List<PocketCardBrief>    cards;
  final String                   setId;
  final Map<String, bool>        owned;
  final void Function(String id) onToggle;
  final int?                     totalCards;

  const _CardGrid({
    required this.cards,
    required this.setId,
    required this.owned,
    required this.onToggle,
    this.totalCards,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      cacheExtent: 1500,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:   3,
        childAspectRatio: 0.60,
        crossAxisSpacing: 8,
        mainAxisSpacing:  8,
      ),
      itemCount: cards.length,
      itemBuilder: (context, i) => _CardGridTile(
        card:       cards[i],
        setId:      setId,
        isOwned:    owned[cards[i].id] ?? false,
        onToggle:   () => onToggle(cards[i].id),
        totalCards: totalCards,
      ),
    );
  }
}

class _CardGridTile extends StatelessWidget {
  final PocketCardBrief card;
  final String          setId;
  final bool            isOwned;
  final VoidCallback    onToggle;
  final int?            totalCards;

  const _CardGridTile({
    required this.card,
    required this.setId,
    required this.isOwned,
    required this.onToggle,
    this.totalCards,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PocketCardDetailScreen(
            card:       card,
            setId:      setId,
            totalCards: totalCards,
          ),
        ),
      ),
      child: Container(
        // Sem highlight quando possuída — visual neutro
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: scheme.outlineVariant, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Imagem: proporção carta TCG (63×88 ≈ 0.716) ──────
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                child: card.imageUrlLow != null
                    ? Image.network(
                        card.imageUrlLow!,
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, p) => p == null
                            ? child
                            : Container(color: scheme.surfaceContainerHighest),
                        errorBuilder: (_, __, ___) => _CardPlaceholder(scheme: scheme),
                      )
                    : _CardPlaceholder(scheme: scheme),
              ),
            ),

            // ── Rodapé: nome + número (esq) | pokébola (dir) ─────
            Padding(
              padding: const EdgeInsets.fromLTRB(5, 4, 5, 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Nome + número
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          card.name,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '#${card.localId}',
                          style: TextStyle(
                            fontSize: 8,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Pokébola — vermelha quando possuída, cinza quando não
                  GestureDetector(
                    onTap: onToggle,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(
                        isOwned
                            ? Icons.catching_pokemon
                            : Icons.catching_pokemon_outlined,
                        size: 16,
                        color: isOwned
                            ? const Color(0xFFE53935)
                            : scheme.onSurfaceVariant.withOpacity(0.4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Lista linear ─────────────────────────────────────────────────

class _CardList extends StatelessWidget {
  final List<PocketCardBrief>    cards;
  final String                   setId;
  final Map<String, bool>        owned;
  final void Function(String id) onToggle;
  final int?                     totalCards;

  const _CardList({
    required this.cards,
    required this.setId,
    required this.owned,
    required this.onToggle,
    this.totalCards,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      // cacheExtent alto: pré-carrega imagens 1500px além da viewport
      // elimina o carregamento visível ao scrollar
      cacheExtent: 1500,
      itemCount: cards.length,
      itemBuilder: (context, i) => _CardListTile(
        card:       cards[i],
        setId:      setId,
        isOwned:    owned[cards[i].id] ?? false,
        onToggle:   () => onToggle(cards[i].id),
        totalCards: totalCards,
      ),
    );
  }
}

class _CardListTile extends StatelessWidget {
  final PocketCardBrief card;
  final String          setId;
  final bool            isOwned;
  final VoidCallback    onToggle;
  final int?            totalCards;

  const _CardListTile({
    required this.card,
    required this.setId,
    required this.isOwned,
    required this.onToggle,
    this.totalCards,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PocketCardDetailScreen(
            card:       card,
            setId:      setId,
            totalCards: totalCards,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        // Sem highlight — visual neutro independente de posse
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: scheme.outlineVariant, width: 0.5),
        ),
        child: Row(
          children: [
            // Miniatura
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 52, height: 72,
                child: card.imageUrlLow != null
                    ? Image.network(
                        card.imageUrlLow!,
                        fit: BoxFit.cover,
                        cacheWidth: 104, // 52px × 2x — reduz decode em memória
                        loadingBuilder: (_, child, p) => p == null
                            ? child
                            : Container(color: scheme.surfaceContainerHighest),
                        errorBuilder: (_, __, ___) => _CardPlaceholder(scheme: scheme),
                      )
                    : _CardPlaceholder(scheme: scheme),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '#${card.localId}',
                    style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
                  ),
                  if (card.rarity != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        PocketRarityBadge(rarity: card.rarity!, expanded: true),
                        const SizedBox(width: 6),
                        Text(
                          card.rarity!,
                          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Pokébola — vermelha quando possuída
            GestureDetector(
              onTap: onToggle,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  isOwned
                      ? Icons.catching_pokemon
                      : Icons.catching_pokemon_outlined,
                  size: 26,
                  color: isOwned
                      ? const Color(0xFFE53935)
                      : scheme.onSurfaceVariant.withOpacity(0.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Placeholder de carta ─────────────────────────────────────────

class _CardPlaceholder extends StatelessWidget {
  final ColorScheme scheme;
  const _CardPlaceholder({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Icon(Icons.style_outlined, size: 22,
            color: scheme.onSurfaceVariant.withOpacity(0.3)),
      ),
    );
  }
}

// ─── Skeleton ─────────────────────────────────────────────────────

class _ListSkeleton extends StatefulWidget {
  const _ListSkeleton();
  @override State<_ListSkeleton> createState() => _ListSkeletonState();
}

class _ListSkeletonState extends State<_ListSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>    _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, childAspectRatio: 0.60,
          crossAxisSpacing: 8, mainAxisSpacing: 8,
        ),
        itemCount: 18,
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(
            color: scheme.onSurface.withOpacity(_anim.value * 0.12),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

// ─── Error view ───────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message; final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(message),
          const SizedBox(height: 16),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
            onPressed: onRetry,
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }
}
