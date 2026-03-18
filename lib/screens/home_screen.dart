import 'package:flutter/material.dart';
import 'package:pokedex_tracker/services/storage_service.dart';
import 'package:pokedex_tracker/screens/pokedex_screen.dart';

class _DlcInfo {
  final String name;
  final int total;
  final String sectionApiName;
  const _DlcInfo({required this.name, required this.total, required this.sectionApiName});
}

class _PokedexEntry {
  final String name;
  final String year;
  final int totalBase;
  final List<_DlcInfo> dlcs;
  final bool isMobile;
  final String iconBg;

  const _PokedexEntry({
    required this.name,
    required this.year,
    required this.totalBase,
    this.dlcs = const [],
    this.isMobile = false,
    this.iconBg = '#F1EFE8',
  });

  int get totalAll => totalBase + dlcs.fold(0, (s, d) => s + d.total);
  bool get hasDlc => dlcs.isNotEmpty;
  String get pokedexId =>
      name.toLowerCase().replaceAll(' ', '_').replaceAll('/', '_').replaceAll("'", '');
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StorageService _storage = StorageService();
  final Map<String, int> _caughtCounts = {};

  static const List<_PokedexEntry> _entries = [
    _PokedexEntry(name: "Let's Go Pikachu / Eevee", year: '2018', totalBase: 153, iconBg: '#EAF3DE'),
    _PokedexEntry(
      name: 'Sword / Shield', year: '2019', totalBase: 400, iconBg: '#E6F1FB',
      dlcs: [
        _DlcInfo(name: 'Isle of Armor', total: 210, sectionApiName: 'isle-of-armor'),
        _DlcInfo(name: 'Crown Tundra', total: 210, sectionApiName: 'crown-tundra'),
      ],
    ),
    _PokedexEntry(name: 'Brilliant Diamond / Shining Pearl', year: '2021', totalBase: 493, iconBg: '#FBEAF0'),
    _PokedexEntry(name: 'Legends: Arceus', year: '2022', totalBase: 242, iconBg: '#EEEDFE'),
    _PokedexEntry(
      name: 'Scarlet / Violet', year: '2022', totalBase: 400, iconBg: '#FAECE7',
      dlcs: [
        _DlcInfo(name: 'Teal Mask', total: 200, sectionApiName: 'kitakami'),
        _DlcInfo(name: 'Indigo Disk', total: 243, sectionApiName: 'blueberry'),
      ],
    ),
    _PokedexEntry(
      name: 'Legends: Z-A', year: '2025', totalBase: 132, iconBg: '#F1EFE8',
      dlcs: [_DlcInfo(name: 'Mega Dimension', total: 132, sectionApiName: 'mega-dimension')],
    ),
    _PokedexEntry(name: 'FireRed / LeafGreen', year: '2026', totalBase: 386, iconBg: '#EAF3DE'),
    _PokedexEntry(name: 'Pokopia', year: '2026', totalBase: 311, iconBg: '#E1F5EE'),
  ];

  static const _PokedexEntry _goEntry = _PokedexEntry(
    name: 'Pokémon GO', year: '2016', totalBase: 941, isMobile: true, iconBg: '#FCEBEB',
  );

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    final all = [..._entries, _goEntry,
      const _PokedexEntry(name: 'Nacional', year: '', totalBase: 1025)];
    for (final e in all) {
      final c = await _storage.getCaughtCount(e.pokedexId);
      if (mounted) setState(() => _caughtCounts[e.pokedexId] = c);
    }
  }

  void _openPokedex(_PokedexEntry entry, {String? sectionFilter}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PokedexScreen(
          pokedexId: entry.pokedexId,
          pokedexName: entry.name,
          totalPokemon: entry.totalAll,
          initialSectionFilter: sectionFilter,
        ),
      ),
    );
    _loadCounts();
  }

  @override
  Widget build(BuildContext context) {
    final nacEntry = const _PokedexEntry(name: 'Nacional', year: '', totalBase: 1025);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pokedex'),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () {}),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadCounts,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _NacionalCard(
                caught: _caughtCounts[nacEntry.pokedexId] ?? 0,
                total: 1025,
                onTap: () => _openPokedex(nacEntry),
              ),
              const SizedBox(height: 14),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.25,
                ),
                itemCount: _entries.length,
                itemBuilder: (context, i) {
                  final entry = _entries[i];
                  return _PokedexCard(
                    entry: entry,
                    caught: _caughtCounts[entry.pokedexId] ?? 0,
                    onTap: () => _openPokedex(entry),
                    onTapDlc: (apiName) => _openPokedex(entry, sectionFilter: apiName),
                  );
                },
              ),
              const SizedBox(height: 12),
              Text('MOBILE', style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                letterSpacing: 1.1,
              )),
              const SizedBox(height: 8),
              _GoCard(
                entry: _goEntry,
                caught: _caughtCounts[_goEntry.pokedexId] ?? 0,
                onTap: () => _openPokedex(_goEntry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── CARD DA POKEDEX ─────────────────────────────────────────────

class _PokedexCard extends StatelessWidget {
  final _PokedexEntry entry;
  final int caught;
  final VoidCallback onTap;
  final void Function(String) onTapDlc;

  const _PokedexCard({
    required this.entry, required this.caught,
    required this.onTap, required this.onTapDlc,
  });

  @override
  Widget build(BuildContext context) {
    final complete = caught >= entry.totalBase;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: complete ? const Color(0xFF34C759).withOpacity(0.5)
                           : Theme.of(context).colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ícone + coroa
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _iconBox(context, entry.iconBg),
                if (complete) const Text('👑', style: TextStyle(fontSize: 14)),
              ],
            ),
            const SizedBox(height: 8),
            // Nome
            Text(
              entry.name,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600, fontSize: 11, height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            // Contador jogo base
            Text(
              '$caught / ${entry.totalBase}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 11, fontWeight: FontWeight.w500,
                color: complete ? const Color(0xFF34C759) : null,
              ),
            ),
            // DLC rows — mesma estrutura do protótipo
            if (entry.hasDlc) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant, width: 0.5,
                  )),
                ),
                child: Column(
                  children: entry.dlcs.map((dlc) => Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: GestureDetector(
                      onTap: () => onTapDlc(dlc.sectionApiName),
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              dlc.name,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                fontSize: 9.5,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '— / ${dlc.total}',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontSize: 9.5, fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _iconBox(BuildContext context, String hexColor) {
    Color color;
    try {
      color = Color(int.parse(hexColor.replaceAll('#', '0xFF')));
    } catch (_) {
      color = const Color(0xFFF1EFE8);
    }
    return Container(
      width: 30, height: 30,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: const Icon(Icons.catching_pokemon, size: 16),
    );
  }
}

// ─── CARD GO ─────────────────────────────────────────────────────

class _GoCard extends StatelessWidget {
  final _PokedexEntry entry;
  final int caught;
  final VoidCallback onTap;
  const _GoCard({required this.entry, required this.caught, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final complete = caught >= entry.totalBase;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: complete ? const Color(0xFF34C759).withOpacity(0.5)
                           : Theme.of(context).colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFFCEBEB), borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.catching_pokemon, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.name, style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                )),
                Text(
                  '$caught / ${entry.totalBase}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: complete ? const Color(0xFF34C759) : null,
                  ),
                ),
              ],
            )),
            if (complete) const Text('👑', style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

// ─── CARD NACIONAL ───────────────────────────────────────────────

class _NacionalCard extends StatelessWidget {
  final int caught;
  final int total;
  final VoidCallback onTap;
  const _NacionalCard({required this.caught, required this.total, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final complete = caught >= total;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant, width: 0.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Nacional', style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w500,
              )),
              Text('$caught / $total', style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: complete ? const Color(0xFF34C759)
                                : Theme.of(context).colorScheme.onSurfaceVariant,
              )),
            ]),
            if (complete) const Text('👑', style: TextStyle(fontSize: 16))
            else const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}