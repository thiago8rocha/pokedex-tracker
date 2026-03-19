import 'package:flutter/material.dart';
import 'package:pokedex_tracker/models/pokemon.dart';
import 'package:pokedex_tracker/screens/detail/detail_shared.dart';

class PokopiaDetailScreen extends StatefulWidget {
  final Pokemon pokemon;
  final bool caught; // aqui = "amigo"
  final VoidCallback onToggleCaught;

  const PokopiaDetailScreen({
    super.key,
    required this.pokemon,
    required this.caught,
    required this.onToggleCaught,
  });

  @override
  State<PokopiaDetailScreen> createState() => _PokopiaDetailScreenState();
}

class _PokopiaDetailScreenState extends State<PokopiaDetailScreen>
    with SingleTickerProviderStateMixin {

  late bool _caught;
  late TabController _tabController;

  static const _tabs = ['Amigos', 'Habitats'];

  @override
  void initState() {
    super.initState();
    _caught = widget.caught;
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          DetailHeader(
            pokemon: widget.pokemon,
            caught: _caught,
            caughtLabel: 'Amigo',
            onToggleCaught: () { setState(() => _caught = !_caught); widget.onToggleCaught(); },
          ),
        ],
        body: Column(children: [
          Material(
            elevation: 0,
            child: TabBar(
              controller: _tabController,
              tabs: _tabs.map((t) => Tab(text: t)).toList(),
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
              indicatorColor: Theme.of(context).colorScheme.primary,
              tabAlignment: TabAlignment.fill,
            ),
          ),
          Expanded(child: TabBarView(
            controller: _tabController,
            children: [
              _AmigosTab(pokemon: widget.pokemon),
              const _HabitatsTab(),
            ],
          )),
        ]),
      ),
    );
  }
}

// ─── ABA AMIGOS ──────────────────────────────────────────────────

class _AmigosTab extends StatelessWidget {
  final Pokemon pokemon;
  const _AmigosTab({required this.pokemon});

  @override
  Widget build(BuildContext context) {
    final bg = neutralBg(context);
    final border = neutralBorder(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        secTitle(context, 'APARIÇÃO'),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: border, width: 0.5),
            borderRadius: BorderRadius.circular(10)),
          child: Column(children: [
            _row(context, 'Raridade', border,
              widget: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFEAF3DE), borderRadius: BorderRadius.circular(10)),
                child: const Text('Comum', style: TextStyle(color: Color(0xFF3B6D11), fontSize: 10, fontWeight: FontWeight.w500)),
              )),
            _row(context, 'Horário', border, value: 'Manhã / Dia'),
            _row(context, 'Clima', border, value: 'Ensolarado / Nublado', isLast: true),
          ]),
        ),
        const SizedBox(height: 16),

        secTitle(context, 'HABITAT IDEAL'),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: const Color(0xFFFAEEDA), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.wb_sunny_outlined, color: Color(0xFFc8a020), size: 20),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Text('Iluminado', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(width: 5),
                Text('(Bright)', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ]),
              Text('Prefere habitats ao ar livre ou bem iluminados',
                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ]),
          ]),
        ),
        const SizedBox(height: 16),

        secTitle(context, 'SABOR FAVORITO'),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Doce', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6,
              children: ['Salada de frutas', 'Bolo de mel', 'Suco de Pecha Berry'].map((s) =>
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: border, width: 0.5)),
                  child: Text(s, style: TextStyle(fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
                )).toList()),
          ]),
        ),
        const SizedBox(height: 16),

        secTitle(context, 'COISAS FAVORITAS'),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: border, width: 0.5),
            borderRadius: BorderRadius.circular(10)),
          child: Column(children: [
            ['Muita natureza', 'Lots of nature'],
            ['Coisas macias', 'Soft stuff'],
            ['Coisas fofas', 'Cute stuff'],
            ['Muita água', 'Lots of water'],
            ['Atividades em grupo', 'Group activities'],
          ].asMap().entries.map((e) {
            final isLast = e.key == 4;
            return Container(
              decoration: isLast ? null : BoxDecoration(
                border: Border(bottom: BorderSide(color: border, width: 0.5))),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(e.value[0], style: const TextStyle(fontSize: 13)),
                Text(e.value[1], style: TextStyle(fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ]),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        secTitle(context, 'ESPECIALIDADES'),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: bg, borderRadius: BorderRadius.circular(8),
              border: Border.all(color: border, width: 0.5)),
            child: const Icon(Icons.eco_outlined, color: Color(0xFF4a9020), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Grow', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 3),
            Text('Acelera o crescimento de flores, árvores, plantas e colheitas nas proximidades.',
              style: TextStyle(fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4)),
          ])),
        ]),
      ]),
    );
  }

  Widget _row(BuildContext ctx, String label, Color border,
      {String? value, Widget? widget, bool isLast = false}) {
    return Container(
      decoration: isLast ? null : BoxDecoration(
        border: Border(bottom: BorderSide(color: border, width: 0.5))),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 13, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
        widget ?? Text(value ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

// ─── ABA HABITATS ────────────────────────────────────────────────

class _HabitatsTab extends StatelessWidget {
  const _HabitatsTab();

  static const _habitats = [
    {'name': 'Parques e jardins', 'nameEn': 'Parks & gardens', 'color': Color(0xFF4a9020)},
    {'name': 'Áreas urbanas',     'nameEn': 'Urban areas',     'color': Color(0xFF607D8B)},
    {'name': 'Campos abertos',    'nameEn': 'Open fields',     'color': Color(0xFF8BC34A)},
    {'name': 'Florestas',         'nameEn': 'Forests',         'color': Color(0xFF388E3C)},
  ];

  @override
  Widget build(BuildContext context) {
    final bg = neutralBg(context);
    final border = neutralBorder(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        secTitle(context, 'HABITATS'),
        Text('Locais onde este Pokémon pode ser encontrado em Pokopia.',
          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        ..._habitats.map((h) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: (h['color'] as Color).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.place_outlined, color: h['color'] as Color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(h['name'] as String,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              Text(h['nameEn'] as String, style: TextStyle(fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ]),
          ]),
        )),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: border, width: 0.5),
            borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            Icon(Icons.info_outline, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'Dados completos de habitat serão carregados do arquivo JSON local de curadoria.',
              style: TextStyle(fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4))),
          ]),
        ),
      ]),
    );
  }
}