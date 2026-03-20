import 'package:flutter/material.dart';

class PokopiaHabitatsScreen extends StatefulWidget {
  const PokopiaHabitatsScreen({super.key});

  @override
  State<PokopiaHabitatsScreen> createState() =>
      _PokopiaHabitatsScreenState();
}

class _PokopiaHabitatsScreenState extends State<PokopiaHabitatsScreen> {
  String _search = '';
  String? _selectedArea;

  List<String> get _areas => [
        'Todos',
        'Withered Wasteland',
        'Bleak Beach',
        'Rocky Ridges',
        'Sparkling Skylands',
        'Palette Town',
        'Dream Islands',
      ];

  List<_HabitatData> get _filtered {
    return _habitats.where((h) {
      final matchSearch = _search.isEmpty ||
          h.name.toLowerCase().contains(_search.toLowerCase()) ||
          h.nameEn.toLowerCase().contains(_search.toLowerCase());
      final matchArea = _selectedArea == null ||
          _selectedArea == 'Todos' ||
          h.area == _selectedArea;
      return matchSearch && matchArea;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Habitats'),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(children: [
        // ── Filtros ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Buscar habitat...',
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: scheme.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: scheme.outlineVariant),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              isDense: true,
            ),
          ),
        ),

        // Filtro de área (chips horizontais)
        SizedBox(
          height: 44,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            scrollDirection: Axis.horizontal,
            itemCount: _areas.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) {
              final area = _areas[i];
              final selected = (_selectedArea ?? 'Todos') == area;
              return GestureDetector(
                onTap: () => setState(() =>
                    _selectedArea = area == 'Todos' ? null : area),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: selected
                        ? scheme.primary
                        : scheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? scheme.primary
                          : scheme.outlineVariant,
                    ),
                  ),
                  child: Text(area,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: selected
                          ? scheme.onPrimary
                          : scheme.onSurfaceVariant,
                    )),
                ),
              );
            },
          ),
        ),

        // ── Lista ──────────────────────────────────────────────
        Expanded(
          child: _filtered.isEmpty
              ? Center(
                  child: Text('Nenhum habitat encontrado.',
                    style: TextStyle(
                        color: scheme.onSurfaceVariant)))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) =>
                      _HabitatTile(data: _filtered[i]),
                ),
        ),
      ]),
    );
  }
}

// ─── TILE ─────────────────────────────────────────────────────────

class _HabitatTile extends StatelessWidget {
  final _HabitatData data;
  const _HabitatTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant, width: 1),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Ícone do bioma
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: data.color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(data.icon, size: 20, color: data.color),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(data.name,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600))),
              Text(data.area,
                style: TextStyle(
                  fontSize: 10, color: scheme.onSurfaceVariant)),
            ]),
            const SizedBox(height: 1),
            Text(data.nameEn,
              style: TextStyle(
                fontSize: 10, color: scheme.onSurfaceVariant)),
            if (data.notes != null) ...[
              const SizedBox(height: 5),
              Text(data.notes!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant, height: 1.4)),
            ],
          ],
        )),
      ]),
    );
  }
}

// ─── DADOS ────────────────────────────────────────────────────────

class _HabitatData {
  final String name;
  final String nameEn;
  final String area;
  final Color color;
  final IconData icon;
  final String? notes;
  const _HabitatData({
    required this.name,
    required this.nameEn,
    required this.area,
    required this.color,
    required this.icon,
    this.notes,
  });
}

const _habitats = [
  // Withered Wasteland
  _HabitatData(
    name: 'Campo Seco',
    nameEn: 'Dry Field',
    area: 'Withered Wasteland',
    color: Color(0xFFA1887F),
    icon: Icons.landscape_outlined,
    notes: 'Terra árida e rachada. Atrai Pokémon do tipo Terra e Normal resistentes.',
  ),
  _HabitatData(
    name: 'Ruínas Antigas',
    nameEn: 'Ancient Ruins',
    area: 'Withered Wasteland',
    color: Color(0xFF78909C),
    icon: Icons.account_balance_outlined,
    notes: 'Estruturas abandonadas. Pokémon do tipo Psíquico e Fantasma aparecem aqui.',
  ),
  _HabitatData(
    name: 'Rio Seco',
    nameEn: 'Dry Riverbed',
    area: 'Withered Wasteland',
    color: Color(0xFF8D6E63),
    icon: Icons.water_outlined,
    notes: 'Leito de rio sem água. Pode ser revitalizado com Pokémon de Water specialty.',
  ),

  // Bleak Beach
  _HabitatData(
    name: 'Costa Rochosa',
    nameEn: 'Rocky Shore',
    area: 'Bleak Beach',
    color: Color(0xFF0288D1),
    icon: Icons.waves_outlined,
    notes: 'Pedras e conchas na beira-mar. Boa para Pokémon do tipo Água e Pedra.',
  ),
  _HabitatData(
    name: 'Areia Fina',
    nameEn: 'Sandy Beach',
    area: 'Bleak Beach',
    color: Color(0xFFF9A825),
    icon: Icons.beach_access_outlined,
    notes: 'Praia de areia suave. Pokémon do tipo Normal e Voador aparecem de manhã.',
  ),
  _HabitatData(
    name: 'Recife de Coral',
    nameEn: 'Coral Reef',
    area: 'Bleak Beach',
    color: Color(0xFFE91E63),
    icon: Icons.blur_on_outlined,
    notes: 'Vida marinha abundante. Pokémon raros do tipo Água aparecem aqui à noite.',
  ),
  _HabitatData(
    name: 'Caverna Costeira',
    nameEn: 'Coastal Cave',
    area: 'Bleak Beach',
    color: Color(0xFF546E7A),
    icon: Icons.brightness_2_outlined,
    notes: 'Interior escuro e úmido. Pokémon do tipo Fantasma e Caverna habitam este local.',
  ),

  // Rocky Ridges
  _HabitatData(
    name: 'Encosta Vulcânica',
    nameEn: 'Volcanic Slope',
    area: 'Rocky Ridges',
    color: Color(0xFFD84315),
    icon: Icons.local_fire_department_outlined,
    notes: 'Próximo à lava. Apenas Pokémon do tipo Fogo conseguem sobreviver aqui.',
  ),
  _HabitatData(
    name: 'Vale Pedregoso',
    nameEn: 'Boulder Valley',
    area: 'Rocky Ridges',
    color: Color(0xFF795548),
    icon: Icons.terrain_outlined,
    notes: 'Rochas gigantes por toda parte. Pokémon do tipo Pedra e Luta vivem aqui.',
  ),
  _HabitatData(
    name: 'Floresta de Pedra',
    nameEn: 'Stone Forest',
    area: 'Rocky Ridges',
    color: Color(0xFF5D4037),
    icon: Icons.forest_outlined,
    notes: 'Árvores petrificadas. Pokémon do tipo Dragão e Pedra exploram este bioma.',
  ),
  _HabitatData(
    name: 'Grutas Profundas',
    nameEn: 'Deep Caves',
    area: 'Rocky Ridges',
    color: Color(0xFF263238),
    icon: Icons.nightlight_outlined,
    notes: 'Túneis escuros e profundos. Pokémon do tipo Veneno e Inseto se escondem aqui.',
  ),

  // Sparkling Skylands
  _HabitatData(
    name: 'Ilha Flutuante',
    nameEn: 'Floating Island',
    area: 'Sparkling Skylands',
    color: Color(0xFF7986CB),
    icon: Icons.cloud_outlined,
    notes: 'Ilhas no ar cobertas de grama e construções. Pokémon do tipo Voador e Fada vivem aqui.',
  ),
  _HabitatData(
    name: 'Canteiro de Obras',
    nameEn: 'Construction Site',
    area: 'Sparkling Skylands',
    color: Color(0xFFFF8F00),
    icon: Icons.construction_outlined,
    notes: 'Área em reconstrução. Pokémon com Build e Engineer specialty aparecem aqui.',
  ),
  _HabitatData(
    name: 'Jardim Aéreo',
    nameEn: 'Sky Garden',
    area: 'Sparkling Skylands',
    color: Color(0xFF43A047),
    icon: Icons.eco_outlined,
    notes: 'Jardim cultivado no ar. Pokémon de tipo Planta e Fada preferem este habitat.',
  ),
  _HabitatData(
    name: 'Lixão das Alturas',
    nameEn: 'Sky Junkyard',
    area: 'Sparkling Skylands',
    color: Color(0xFF757575),
    icon: Icons.delete_outline,
    notes: 'Repleto de entulho. Pokémon com Recycle e Litter specialty aparecem com mais frequência.',
  ),

  // Palette Town
  _HabitatData(
    name: 'Parques e Jardins',
    nameEn: 'Parks & Gardens',
    area: 'Palette Town',
    color: Color(0xFF4CAF50),
    icon: Icons.local_florist_outlined,
    notes: 'Vegetação densa e flores coloridas. Um dos habitats mais ricos em variedade.',
  ),
  _HabitatData(
    name: 'Áreas Urbanas',
    nameEn: 'Urban Areas',
    area: 'Palette Town',
    color: Color(0xFF607D8B),
    icon: Icons.location_city_outlined,
    notes: 'Ruas e construções restauradas. Pokémon do tipo Normal e Elétrico se adaptaram bem.',
  ),
  _HabitatData(
    name: 'Campos Abertos',
    nameEn: 'Open Fields',
    area: 'Palette Town',
    color: Color(0xFF8BC34A),
    icon: Icons.grass_outlined,
    notes: 'Extensas planícies verdes. Pokémon de tipo Planta, Normal e Terra aparecem aqui.',
  ),
  _HabitatData(
    name: 'Floresta Nativa',
    nameEn: 'Native Forest',
    area: 'Palette Town',
    color: Color(0xFF388E3C),
    icon: Icons.park_outlined,
    notes: 'Floresta densa nas proximidades da cidade. Rica em Pokémon de tipo Inseto, Planta e Voador.',
  ),

  // Dream Islands
  _HabitatData(
    name: 'Dream Island',
    nameEn: 'Dream Island',
    area: 'Dream Islands',
    color: Color(0xFF9C27B0),
    icon: Icons.auto_awesome_outlined,
    notes: 'Ilhas oníricas acessíveis pelo Drifloon. Lendários aparecem aqui de forma aleatória.',
  ),
];