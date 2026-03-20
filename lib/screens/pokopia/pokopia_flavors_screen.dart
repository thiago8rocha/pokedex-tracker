import 'package:flutter/material.dart';

class PokopiaFlavorsScreen extends StatefulWidget {
  const PokopiaFlavorsScreen({super.key});

  @override
  State<PokopiaFlavorsScreen> createState() => _PokopiaFlavorsScreenState();
}

class _PokopiaFlavorsScreenState extends State<PokopiaFlavorsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sabores e Mosslax'),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Efeitos no Mosslax'),
            Tab(text: 'Receitas do Chef Dente'),
          ],
          labelColor: scheme.primary,
          unselectedLabelColor: scheme.onSurfaceVariant,
          indicatorColor: scheme.primary,
          tabAlignment: TabAlignment.fill,
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _MosslaxTab(),
          _ChefDenteTab(),
        ],
      ),
    );
  }
}

// ─── ABA MOSSLAX ─────────────────────────────────────────────────

class _MosslaxTab extends StatelessWidget {
  const _MosslaxTab();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Intro
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: scheme.outlineVariant, width: 0.5),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline, size: 16,
                color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'Alimentar o Mosslax com diferentes sabores gera efeitos que duram até o fim do dia. '
              'Apenas um efeito pode estar ativo por vez.',
              style: TextStyle(fontSize: 12,
                  color: scheme.onSurfaceVariant, height: 1.4))),
          ]),
        ),
        const SizedBox(height: 16),

        // Sabores
        ..._flavors.map((f) => _FlavorCard(data: f)),
      ]),
    );
  }
}

class _FlavorCard extends StatelessWidget {
  final _FlavorData data;
  const _FlavorCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant, width: 1),
      ),
      child: Column(children: [
        // Cabeçalho com nome e cor do sabor
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12)),
          ),
          child: Row(children: [
            Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                color: data.color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(data.name,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600)),
          ]),
        ),
        // Efeito
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Efeito  ',
              style: TextStyle(fontSize: 12,
                  color: scheme.onSurfaceVariant)),
            Expanded(child: Text(data.effect,
              style: const TextStyle(fontSize: 12,
                  fontWeight: FontWeight.w500, height: 1.4))),
          ]),
        ),
        // Itens aceitos
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Alimentos  ',
              style: TextStyle(fontSize: 12,
                  color: scheme.onSurfaceVariant)),
            Expanded(child: Wrap(
              spacing: 5, runSpacing: 5,
              children: data.foods.map((f) => Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: scheme.outlineVariant, width: 0.5),
                ),
                child: Text(f,
                  style: TextStyle(fontSize: 10,
                      color: scheme.onSurface)),
              )).toList(),
            )),
          ]),
        ),
      ]),
    );
  }
}

// ─── ABA CHEF DENTE ───────────────────────────────────────────────

class _ChefDenteTab extends StatelessWidget {
  const _ChefDenteTab();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Intro Chef Dente
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: scheme.outlineVariant, width: 0.5),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline, size: 16,
                color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'Chef Dente usa a especialidade Party para preparar refeições em massa. '
              'Cada receita exige ingredientes específicos e gera efeitos para festas.',
              style: TextStyle(fontSize: 12,
                  color: scheme.onSurfaceVariant, height: 1.4))),
          ]),
        ),
        const SizedBox(height: 16),

        ..._recipes.map((r) => _RecipeCard(data: r)),
      ]),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final _RecipeData data;
  const _RecipeCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant, width: 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(data.name,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(data.effect,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant, height: 1.4)),
        const SizedBox(height: 8),
        // Ingredientes
        Wrap(spacing: 6, runSpacing: 6,
          children: data.ingredients.map((i) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: scheme.outlineVariant, width: 0.5),
            ),
            child: Text(i,
              style: TextStyle(fontSize: 10, color: scheme.onSurface)),
          )).toList()),
      ]),
    );
  }
}

// ─── DADOS ───────────────────────────────────────────────────────

class _FlavorData {
  final String name;
  final Color color;
  final String effect;
  final List<String> foods;
  const _FlavorData({
    required this.name,
    required this.color,
    required this.effect,
    required this.foods,
  });
}

const _flavors = [
  _FlavorData(
    name: 'Doce',
    color: Color(0xFFE8517A),
    effect: 'Aumenta a taxa de aparição de Pokémon do tipo Fada e Normal nos habitats próximos.',
    foods: ['Salada de frutas', 'Bolo de mel', 'Suco de Pecha Berry', 'Doce de Mago'],
  ),
  _FlavorData(
    name: 'Picante',
    color: Color(0xFFE85E30),
    effect: 'Aumenta a taxa de aparição de Pokémon em todos os habitats até o fim do dia.',
    foods: ['Curry de Tamato', 'Pimenta Figy', 'Chili especial', 'Ensopado picante'],
  ),
  _FlavorData(
    name: 'Azedo',
    color: Color(0xFF5CB85C),
    effect: 'Aumenta a chance de encontrar Pokémon raros em habitats já construídos.',
    foods: ['Suco de Wiki Berry', 'Salada cítrica', 'Smoothie de Iapapa', 'Geleia ácida'],
  ),
  _FlavorData(
    name: 'Amargo',
    color: Color(0xFF8D6E63),
    effect: 'Reduz o tempo necessário para atrair Pokémon lendários nas Dream Islands.',
    foods: ['Chá Rawst', 'Bolo de Nomel', 'Extrato de Lum', 'Infusão escura'],
  ),
  _FlavorData(
    name: 'Seco',
    color: Color(0xFF5B8DD9),
    effect: 'Aumenta a velocidade de regeneração dos recursos de materiais no mapa.',
    foods: ['Biscoito de Chesto', 'Pão de Bluk', 'Snack crocante', 'Mix seco'],
  ),
];

class _RecipeData {
  final String name;
  final String effect;
  final List<String> ingredients;
  const _RecipeData({
    required this.name,
    required this.effect,
    required this.ingredients,
  });
}

const _recipes = [
  _RecipeData(
    name: 'Banquete de Festa',
    effect: 'Dobra a velocidade de todos os Pokémon por 1 hora. Ideal para construções urgentes.',
    ingredients: ['Carne assada', 'Legumes frescos', 'Mel', 'Sal grosso'],
  ),
  _RecipeData(
    name: 'Sopa Nutritiva',
    effect: 'Restaura a energia de todos os Pokémon cansados, permitindo que trabalhem novamente mais cedo.',
    ingredients: ['Osso de Cubone', 'Ervas medicinais', 'Água de nascente'],
  ),
  _RecipeData(
    name: 'Torta de Frutas Silvestres',
    effect: 'Atrai Pokémon do tipo Fada e Voador para habitats próximos por 2 horas.',
    ingredients: ['Pecha Berry', 'Oran Berry', 'Farinha', 'Açúcar'],
  ),
  _RecipeData(
    name: 'Grelhado Especial',
    effect: 'Aumenta o nível ambiental da área em 1 ponto temporariamente.',
    ingredients: ['Peixe fresco', 'Tamato Berry', 'Erva-limão', 'Carvão vegetal'],
  ),
  _RecipeData(
    name: 'Bebida Energizante',
    effect: 'Pokémon construtores (Build e Engineer) ficam 50% mais rápidos por 30 minutos.',
    ingredients: ['Nectarina', 'Suco de Sitrus', 'Pólen de Roseli'],
  ),
];