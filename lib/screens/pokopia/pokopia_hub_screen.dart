import 'package:flutter/material.dart';
import 'package:pokedex_tracker/screens/pokedex_screen.dart';
import 'package:pokedex_tracker/screens/pokopia/pokopia_specialties_screen.dart';
import 'package:pokedex_tracker/screens/pokopia/pokopia_flavors_screen.dart';
import 'package:pokedex_tracker/screens/pokopia/pokopia_relics_screen.dart';
import 'package:pokedex_tracker/screens/pokopia/pokopia_habitats_screen.dart';

class PokopiaHubScreen extends StatelessWidget {
  const PokopiaHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pokopia'),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 4),

          _HubCard(
            icon: Icons.people_outline,
            title: 'Pokedex de Amigos',
            subtitle: 'Registre os 311 Pokémon que você conheceu em Pokopia',
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const PokedexScreen(
                pokedexId: 'pokopia',
                pokedexName: 'Pokopia',
                totalPokemon: 311,
              ),
            )),
          ),
          const SizedBox(height: 12),

          _HubCard(
            icon: Icons.forest_outlined,
            title: 'Habitats',
            subtitle: 'Todos os 200 habitats e quais Pokémon aparecem em cada um',
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const PokopiaHabitatsScreen(),
            )),
          ),
          const SizedBox(height: 12),

          _HubCard(
            icon: Icons.auto_awesome_outlined,
            title: 'Especialidades',
            subtitle: 'Todas as 31 especialidades e o que cada Pokémon pode fazer',
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const PokopiaSpecialtiesScreen(),
            )),
          ),
          const SizedBox(height: 12),

          _HubCard(
            icon: Icons.restaurant_outlined,
            title: 'Sabores e Mosslax',
            subtitle: 'Efeitos de cada sabor no Mosslax e receitas do Chef Dente',
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const PokopiaFlavorsScreen(),
            )),
          ),
          const SizedBox(height: 12),

          _HubCard(
            icon: Icons.inventory_2_outlined,
            title: 'Relíquias e Fósseis',
            subtitle: 'Itens raros avaliados pelo Professor Tangrowth',
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const PokopiaRelicsScreen(),
            )),
          ),

          const SizedBox(height: 20),
          _SectionLabel('POKÉMON PECULIARES'),
          const SizedBox(height: 8),
          ..._peculiarPokemon.map((p) => _PeculiarCard(data: p)),
        ],
      ),
    );
  }
}

// ─── DADOS ───────────────────────────────────────────────────────

class _PeculiarData {
  final String name;
  final String base;
  final String specialtyAsset; // nome do arquivo sem .png
  final String specialtyLabel;
  final String description;
  final String location;
  const _PeculiarData({
    required this.name,
    required this.base,
    required this.specialtyAsset,
    required this.specialtyLabel,
    required this.description,
    required this.location,
  });
}

const _peculiarPokemon = [
  _PeculiarData(
    name: 'Professor Tangrowth',
    base: 'Tangrowth',
    specialtyAsset: 'appraise',
    specialtyLabel: 'Appraise',
    description:
        'Seu guia em Pokopia. Avalia todas as Relíquias Perdidas que você encontrar durante a jornada.',
    location: 'Withered Wasteland',
  ),
  _PeculiarData(
    name: 'Mosslax',
    base: 'Snorlax',
    specialtyAsset: 'eat',
    specialtyLabel: 'Eat',
    description:
        'Snorlax coberto de musgo e flores após séculos dormindo. Aceita comidas para conceder efeitos especiais até o fim do dia.',
    location: 'Bleak Beach',
  ),
  _PeculiarData(
    name: 'Smearguru',
    base: 'Smeargle',
    specialtyAsset: 'paint',
    specialtyLabel: 'Paint',
    description:
        'Coberto de manchas coloridas. Pode repintar móveis e estruturas usando materiais específicos.',
    location: 'Bleak Beach',
  ),
  _PeculiarData(
    name: 'Peakychu',
    base: 'Pikachu',
    specialtyAsset: 'illuminate',
    specialtyLabel: 'Illuminate',
    description:
        'Pikachu pálida que doou toda sua eletricidade para curar amigos. Quando se recupera, consegue alimentar a cidade inteira.',
    location: 'Rocky Ridges',
  ),
  _PeculiarData(
    name: 'DJ Rotom',
    base: 'Rotom',
    specialtyAsset: 'DJ',
    specialtyLabel: 'DJ',
    description:
        'Rotom habitando um aparelho de som. Toca os CDs que você colecionar, alterando a música ambiente da cidade.',
    location: 'Rocky Ridges',
  ),
  _PeculiarData(
    name: 'Chef Dente',
    base: 'Greedent',
    specialtyAsset: 'party',
    specialtyLabel: 'Party',
    description:
        'Cheia de utensílios de cozinha presos no corpo. Ajuda a preparar refeições em grande quantidade para festas.',
    location: 'Rocky Ridges',
  ),
  _PeculiarData(
    name: 'Tinkmaster',
    base: 'Tinkaton',
    specialtyAsset: 'Engineer',
    specialtyLabel: 'Engineer',
    description:
        'Passou anos construindo sua própria cidade. Lidera grandes projetos de construção e cria tecnologia de transporte.',
    location: 'Sparkling Skylands',
  ),
];

// ─── WIDGETS ─────────────────────────────────────────────────────

class _HubCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HubCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant, width: 1),
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: scheme.outlineVariant, width: 0.5),
            ),
            child: Icon(icon, size: 22, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant, height: 1.4)),
            ])),
          Icon(Icons.chevron_right, size: 18, color: scheme.onSurfaceVariant),
        ]),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: Theme.of(context).colorScheme.onSurfaceVariant));
  }
}

class _PeculiarCard extends StatelessWidget {
  final _PeculiarData data;
  const _PeculiarCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant, width: 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(data.name,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600))),
          // chip de especialidade com ícone real
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: scheme.outlineVariant, width: 0.5),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Image.asset(
                'assets/pokopia/${data.specialtyAsset}.png',
                width: 14, height: 14,
                errorBuilder: (_, __, ___) =>
                    Icon(Icons.star_outline, size: 14,
                        color: scheme.onSurfaceVariant),
              ),
              const SizedBox(width: 4),
              Text(data.specialtyLabel,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500,
                    color: scheme.onSurfaceVariant)),
            ]),
          ),
        ]),
        const SizedBox(height: 4),
        Text(
          'Base: ${data.base}  •  ${data.location}',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant, fontSize: 10)),
        const SizedBox(height: 6),
        Text(data.description,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant, height: 1.4)),
      ]),
    );
  }
}