import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class GoRaidsScreen extends StatefulWidget {
  const GoRaidsScreen({super.key});
  @override State<GoRaidsScreen> createState() => _GoRaidsScreenState();
}

class _GoRaidsScreenState extends State<GoRaidsScreen> {
  List<_RaidBoss> _raids = [];
  bool   _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _loadRaids(); }

  Future<void> _loadRaids() async {
    setState(() { _loading = true; _error = null; });
    try {
      // pogoapi.net: formato { "current": { "1": [...], "5": [...] }, "previous": {...} }
      final res = await http.get(
        Uri.parse('https://pogoapi.net/api/v1/raid_bosses.json'),
        headers: {'User-Agent': 'Mozilla/5.0 (Android; PokopiaTracker)'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final body    = jsonDecode(res.body) as Map<String, dynamic>;
        final current = body['current'] as Map<String, dynamic>? ?? {};
        final raids   = <_RaidBoss>[];

        for (final tierKey in current.keys) {
          final tier  = int.tryParse(tierKey) ?? 0;
          final bosses = current[tierKey] as List<dynamic>? ?? [];
          for (final b in bosses) {
            final m = b as Map<String, dynamic>;
            raids.add(_RaidBoss(
              id:           (m['id']   as num?)?.toInt() ?? 0,
              name:          m['name'] as String? ?? '',
              tier:          tier,
              form:          m['form'] as String? ?? 'Normal',
              possibleShiny: m['possible_shiny'] as bool? ?? false,
              maxCp:         (m['max_unboosted_cp'] as num?)?.toInt() ?? 0,
              minCp:         (m['min_unboosted_cp'] as num?)?.toInt() ?? 0,
              types:         (m['type'] as List<dynamic>?)
                                 ?.map((t) => t.toString()).toList() ?? [],
            ));
          }
        }

        raids.sort((a, b) => b.tier.compareTo(a.tier));
        if (mounted) setState(() { _raids = raids; _loading = false; });
      } else {
        if (mounted) setState(() { _error = 'Erro ${res.statusCode}'; _loading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Sem conexão'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Raids Ativos'),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _loadRaids,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _raids.isEmpty
              ? _EmptyState(
                  message: _error ?? 'Nenhum raid ativo no momento',
                  onRetry: _loadRaids,
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: _buildTierSections(scheme),
                ),
    );
  }

  List<Widget> _buildTierSections(ColorScheme scheme) {
    final widgets = <Widget>[];
    // Mega primeiro (tier 6), depois 5 → 1
    for (final tier in [6, 5, 4, 3, 2, 1]) {
      final bosses = _raids.where((r) => r.tier == tier).toList();
      if (bosses.isEmpty) continue;

      widgets.add(_TierHeader(tier: tier, count: bosses.length));
      widgets.add(const SizedBox(height: 8));
      for (final boss in bosses) {
        widgets.add(_RaidTile(boss: boss, scheme: scheme));
      }
      widgets.add(const SizedBox(height: 16));
    }
    return widgets;
  }
}

// ─── Modelo ───────────────────────────────────────────────────────

class _RaidBoss {
  final int      id;
  final String   name;
  final int      tier;
  final String   form;
  final bool     possibleShiny;
  final int      maxCp;
  final int      minCp;
  final List<String> types;

  bool get isMega   => tier == 6 || name.toLowerCase().contains('mega');
  bool get isShadow => name.toLowerCase().contains('shadow');

  const _RaidBoss({
    required this.id, required this.name, required this.tier,
    required this.form, required this.possibleShiny,
    required this.maxCp, required this.minCp, required this.types,
  });
}

// ─── Widgets ──────────────────────────────────────────────────────

class _TierHeader extends StatelessWidget {
  final int tier;
  final int count;
  const _TierHeader({required this.tier, required this.count});

  static const _meta = {
    6: ('Mega / Primal', Color(0xFF9C27B0)),
    5: ('5 Estrelas',    Color(0xFFE65100)),
    4: ('4 Estrelas',    Color(0xFF1565C0)),
    3: ('3 Estrelas',    Color(0xFF2E7D32)),
    2: ('2 Estrelas',    Color(0xFF795548)),
    1: ('1 Estrela',     Color(0xFF546E7A)),
  };

  @override
  Widget build(BuildContext context) {
    final (label, color) = _meta[tier] ?? ('Raid', const Color(0xFF888888));
    return Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(label, style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      ),
      const SizedBox(width: 8),
      Text('$count boss${count > 1 ? 'es' : ''}',
          style: TextStyle(fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
    ]);
  }
}

class _RaidTile extends StatelessWidget {
  final _RaidBoss   boss;
  final ColorScheme scheme;
  const _RaidTile({required this.boss, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final isNotNormal = boss.form != 'Normal' && boss.form.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: scheme.outlineVariant, width: 0.5),
      ),
      child: Row(children: [
        // Sprite
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.asset(
            'assets/sprites/artwork/${boss.id}.webp',
            width: 52, height: 52, fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => SizedBox(width: 52, height: 52,
              child: Icon(Icons.catching_pokemon,
                  color: scheme.onSurfaceVariant.withOpacity(0.4), size: 30)),
          ),
        ),
        const SizedBox(width: 12),

        // Info
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(boss.name,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
            if (boss.possibleShiny)
              const Icon(Icons.star_rounded, color: Color(0xFFFFCC00), size: 16),
          ]),
          if (isNotNormal)
            Text(boss.form, style: TextStyle(
                fontSize: 11, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 3),
          Text('CP: ${boss.minCp} – ${boss.maxCp}',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
        ])),
      ]),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _EmptyState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.event_busy_outlined, size: 64,
          color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4)),
      const SizedBox(height: 16),
      Text(message, style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant)),
      const SizedBox(height: 16),
      OutlinedButton(
        onPressed: onRetry,
        style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6))),
        child: const Text('Tentar novamente'),
      ),
    ]));
  }
}
