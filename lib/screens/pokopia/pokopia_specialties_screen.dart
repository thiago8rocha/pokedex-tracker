import 'package:flutter/material.dart';
import 'package:dexcurator/screens/detail/detail_shared.dart' show specialtyIconPath;

class PokopiaSpecialtiesScreen extends StatefulWidget {
  const PokopiaSpecialtiesScreen({super.key});

  @override
  State<PokopiaSpecialtiesScreen> createState() =>
      _PokopiaSpecialtiesScreenState();
}

class _PokopiaSpecialtiesScreenState extends State<PokopiaSpecialtiesScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _specialties
        .where((s) =>
            s.name.toLowerCase().contains(_search.toLowerCase()) ||
            s.description.toLowerCase().contains(_search.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Especialidades'),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(children: [
        // ── Busca ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Buscar especialidade...',
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
              isDense: true,
            ),
          ),
        ),

        // ── Lista ──────────────────────────────────────────────
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text('Nenhuma especialidade encontrada.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) =>
                      _SpecialtyTile(data: filtered[i]),
                ),
        ),
      ]),
    );
  }
}

// ─── WIDGETS ─────────────────────────────────────────────────────

class _SpecialtyTile extends StatelessWidget {
  final _SpecialtyData data;
  const _SpecialtyTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isUnique = data.exclusive != null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant, width: 1),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Ícone da especialidade sem caixa
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.asset(
            specialtyIconPath(data.name),
            width: 44, height: 44,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(
              Icons.auto_awesome_outlined,
              size: 22, color: scheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: 12),

        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nome + badge exclusivo
            Row(children: [
              Text(data.name,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600)),
              if (isUnique) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Exclusivo',
                    style: TextStyle(
                      fontSize: 9, fontWeight: FontWeight.w600,
                      color: scheme.onPrimaryContainer)),
                ),
              ],
            ]),
            const SizedBox(height: 3),

            // Descrição
            Text(data.description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant, height: 1.4)),

            // Pokémon exclusivo (se único)
            if (isUnique) ...[
              const SizedBox(height: 4),
              Text('Apenas: ${data.exclusive}',
                style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w500,
                  color: scheme.onSurface)),
            ],
          ])),
      ]),
    );
  }
}

// ─── DADOS ───────────────────────────────────────────────────────

class _SpecialtyData {
  final String name;
  final String asset;       // nome do arquivo em assets/pokopia/specialties/
  final String description;
  final String? exclusive;  // Pokémon exclusivo, se houver

  const _SpecialtyData({
    required this.name,
    required this.asset,
    required this.description,
    this.exclusive,
  });
}

const _specialties = [
  _SpecialtyData(
    name: 'Appraise',
    asset: 'appraise',
    description: 'Avalia Relíquias Perdidas encontradas durante a jornada.',
    exclusive: 'Professor Tangrowth',
  ),
  _SpecialtyData(
    name: 'Build',
    asset: 'build',
    description: 'Ajuda na construção de estruturas e objetos que exigem blueprint. Geralmente aplicado a Pokémon com golpes do tipo Lutador.',
  ),
  _SpecialtyData(
    name: 'Bulldoze',
    asset: 'bulldoze',
    description: 'Derruba construções existentes, reconstrói casas danificadas ou realoca edifícios para novas posições.',
  ),
  _SpecialtyData(
    name: 'Burn',
    asset: 'burn',
    description: 'Acende objetos como fogueiras e fornalhas. Ligado a Pokémon do tipo Fogo.',
  ),
  _SpecialtyData(
    name: 'Chop',
    asset: 'chop',
    description: 'Transforma troncos pequenos em madeira enquanto você faz outras tarefas.',
  ),
  _SpecialtyData(
    name: 'Collect',
    asset: 'collect',
    description: 'Esses Pokémon são comerciantes — oferecem itens raros em troca de moedas ou pedidos específicos.',
  ),
  _SpecialtyData(
    name: 'Crush',
    asset: 'crush',
    description: 'Quebra itens transformando-os em novos materiais.',
  ),
  _SpecialtyData(
    name: 'DJ',
    asset: 'DJ',
    description: 'Toca os CDs que você colecionar, alterando a música ambiente da cidade.',
    exclusive: 'DJ Rotom',
  ),
  _SpecialtyData(
    name: 'Dream Island',
    asset: 'dream island',
    description: 'Carrega Ditto até as Dream Islands para explorar e encontrar Pokémon lendários.',
    exclusive: 'Drifloon',
  ),
  _SpecialtyData(
    name: 'Eat',
    asset: 'eat',
    description: 'Aceita alimentos oferecidos e concede efeitos especiais para o jogo até o fim do dia. Cada sabor gera um efeito diferente.',
    exclusive: 'Mosslax',
  ),
  _SpecialtyData(
    name: 'Engineer',
    asset: 'Engineer',
    description: 'Comanda grandes projetos de construção, agilizando o trabalho quando designado como líder.',
    exclusive: 'Tinkmaster',
  ),
  _SpecialtyData(
    name: 'Explode',
    asset: 'explode',
    description: 'Pode ser lançado contra objetos como uma aríete Pokémon.',
  ),
  _SpecialtyData(
    name: 'Fly',
    asset: 'fly',
    description: 'Carrega Ditto até outros Pokémon que ele estiver procurando na cidade.',
  ),
  _SpecialtyData(
    name: 'Gather',
    asset: 'gather',
    description: 'Coleta itens espalhados pela cidade e os deposita nas Community Boxes.',
  ),
  _SpecialtyData(
    name: 'Gather Honey',
    asset: 'gather honey',
    description: 'Coleta mel de flores e arbustos, um ingrediente raro para receitas do Chef Dente.',
  ),
  _SpecialtyData(
    name: 'Generate',
    asset: 'generate',
    description: 'Alimenta geradores elétricos para manter construções e dispositivos funcionando.',
  ),
  _SpecialtyData(
    name: 'Grow',
    asset: 'grow',
    description: 'Acelera o crescimento de flores, árvores, plantas e colheitas nas proximidades.',
  ),
  _SpecialtyData(
    name: 'Hype',
    asset: 'hype',
    description: 'Anima outros Pokémon ao redor, aumentando temporariamente a velocidade deles.',
  ),
  _SpecialtyData(
    name: 'Illuminate',
    asset: 'illuminate',
    description: 'Alimenta a rede elétrica da cidade inteira com sua energia.',
    exclusive: 'Peakychu',
  ),
  _SpecialtyData(
    name: 'Litter',
    asset: 'litter',
    description: 'Ao passar por ali, pode largar itens úteis — ou transformar lixo em minério de ferro.',
  ),
  _SpecialtyData(
    name: 'Paint',
    asset: 'paint',
    description: 'Repinta móveis e estruturas específicas, contanto que você forneça os materiais necessários.',
    exclusive: 'Smearguru',
  ),
  _SpecialtyData(
    name: 'Party',
    asset: 'party',
    description: 'Ajuda a preparar refeições em grande quantidade para festas.',
    exclusive: 'Chef Dente',
  ),
  _SpecialtyData(
    name: 'Rarify',
    asset: 'rarify',
    description: 'Aumenta a chance de aparecerem Pokémon raros nos habitats próximos.',
  ),
  _SpecialtyData(
    name: 'Recycle',
    asset: 'recycle',
    description: 'Transforma lixo em minério de ferro, usado em várias receitas de construção.',
  ),
  _SpecialtyData(
    name: 'Search',
    asset: 'search',
    description: 'Localiza tesouros enterrados na terra que você não encontraria sozinho.',
  ),
  _SpecialtyData(
    name: 'Storage',
    asset: 'storage',
    description: 'Guarda itens dentro de si como um baú portátil, liberando espaço no inventário de Ditto.',
  ),
  _SpecialtyData(
    name: 'Teleport',
    asset: 'teleport',
    description: 'Permite viagens instantâneas entre diferentes áreas da cidade.',
  ),
  _SpecialtyData(
    name: 'Trade',
    asset: 'trade',
    description: 'Oferece trocas especiais de itens por outros recursos difíceis de conseguir.',
  ),
  _SpecialtyData(
    name: 'Transform',
    asset: 'Transform',
    description: 'Permite que Ditto se transforme nesse Pokémon para usar suas habilidades temporariamente.',
  ),
  _SpecialtyData(
    name: 'Water',
    asset: 'water',
    description: 'Rega plantas, encharca campos secos e umidifica habitats que precisam de água.',
  ),
  _SpecialtyData(
    name: 'Yawn',
    asset: 'yawn',
    description: 'Faz outros Pokémon ao redor ficarem com sono, diminuindo o barulho e aumentando a tranquilidade da área.',
  ),
];