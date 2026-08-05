import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_colors.dart';
import '../../core/dates.dart';
import '../../core/erros.dart';
import '../../repositories/acessos_repository.dart';
import '../../repositories/providers.dart';
import 'confirmar_apagar_pedido.dart';

/// Separador Acessos do admin global: aprova/recusa pedidos pendentes e
/// revoga contas já aprovadas. Nada é automático — o admin confirma sempre
/// com o empresário antes de decidir.
class PedidosAcessoScreen extends ConsumerStatefulWidget {
  const PedidosAcessoScreen({super.key});
  @override
  ConsumerState<PedidosAcessoScreen> createState() => _PedidosAcessoScreenState();
}

class _PedidosAcessoScreenState extends ConsumerState<PedidosAcessoScreen> {
  late Future<AcessosVista> _future;
  @override
  void initState() { super.initState(); _recarregar(); }
  // Corpo em bloco de propósito: com `=> _future = _carregar()` o closure
  // devolve um Future e o setState() queixa-se de trabalho assíncrono.
  void _recarregar() {
    _future = _carregar();
  }
  Future<AcessosVista> _carregar() async {
    final repo = ref.read(acessosRepoProvider);
    final r = await Future.wait([
      repo.listarPendentes(),
      repo.listarAprovados(),
      repo.listarOrganizacoes(),
    ]);
    return AcessosVista(
      pendentes: r[0] as List<PedidoAcesso>,
      aprovados: r[1] as List<PedidoAcesso>,
      organizacoes: r[2] as List<OrganizacaoAcesso>,
    );
  }

  Future<void> _decidir(PedidoAcesso p, String decisao, String? org) async {
    try {
      await ref.read(acessosRepoProvider).decidir(p.id, decisao, organizacaoId: org);
      if (mounted) setState(_recarregar);
    } catch (e) { if (mounted) mostrarErro(e); }
  }

  Future<void> _apagar(PedidoAcesso p) async {
    final confirmado = await confirmarApagarPedido(
      context,
      quem: p.nome,
      email: p.email,
      estado: p.estado,
    );
    if (!confirmado || !mounted) return;
    try {
      await ref.read(acessosRepoProvider).apagar(p.id);
      if (!mounted) return;
      messengerKey.currentState
          ?.showSnackBar(SnackBar(content: Text('Pedido de ${p.nome} apagado.')));
      setState(_recarregar);
    } catch (e) {
      if (mounted) mostrarErro(e);
    }
  }

  Future<void> _revogar(PedidoAcesso p) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Revogar acesso'),
        content: Text('${p.nome} (${p.email}) perde o acesso no próximo arranque '
            'e liberta uma vaga na organização. Confirma?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.vermelho),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revogar'),
          ),
        ],
      ),
    );
    if (confirmado == true) await _decidir(p, 'revogado', null);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Acessos')),
    body: FutureBuilder<AcessosVista>(future: _future, builder: (context, snap) {
      if (snap.hasError) {
        return ErroView(erro: snap.error!, onRetry: () => setState(_recarregar));
      }
      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
      final v = snap.data!;
      return RefreshIndicator(
        onRefresh: () async {
          setState(_recarregar);
          await _future;
        },
        child: ListView(padding: const EdgeInsets.all(16), children: [
          _Seccao('Pedidos pendentes (${v.pendentes.length})'),
          if (v.pendentes.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Não há pedidos pendentes.')),
          ...v.pendentes.map((p) => _PedidoCard(
            pedido: p, vista: v, onDecidir: _decidir, onApagar: _apagar)),
          const SizedBox(height: 24),
          _Seccao('Contas aprovadas (${v.aprovados.length})'),
          if (v.aprovados.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Ainda não há contas aprovadas.')),
          ...v.aprovados.map((p) => _AprovadoCard(
            pedido: p, ocupacao: v.ocupacaoTexto(p.organizacaoId), onRevogar: _revogar)),
        ]),
      );
    }),
  );
}

/// Dados do ecrã. Público para poder ser construído nos testes.
class AcessosVista {
  final List<PedidoAcesso> pendentes;
  final List<PedidoAcesso> aprovados;
  final List<OrganizacaoAcesso> organizacoes;

  AcessosVista({
    required this.pendentes,
    required this.aprovados,
    required this.organizacoes,
  });

  /// Contas aprovadas por organização — a ocupação real face ao limite.
  Map<String, int> get ativosPorOrganizacao {
    final contagem = <String, int>{};
    for (final p in aprovados) {
      final id = p.organizacaoId;
      if (id != null) contagem[id] = (contagem[id] ?? 0) + 1;
    }
    return contagem;
  }

  int ativos(String? organizacaoId) =>
      organizacaoId == null ? 0 : (ativosPorOrganizacao[organizacaoId] ?? 0);

  OrganizacaoAcesso? organizacao(String? id) {
    if (id == null) return null;
    for (final o in organizacoes) {
      if (o.id == id) return o;
    }
    return null;
  }

  /// `ativos / limite` para mostrar ao admin. Null quando a organização ainda
  /// não existe (pedido livre por associar).
  String? ocupacaoTexto(String? organizacaoId) {
    final org = organizacao(organizacaoId);
    if (org == null) return null;
    return '${ativos(organizacaoId)} / ${org.limite}';
  }

  /// True quando aprovar mais uma conta ultrapassaria o limite. A base de
  /// dados também recusa; isto serve para avisar antes de tentar.
  bool limiteAtingido(String? organizacaoId) {
    final org = organizacao(organizacaoId);
    if (org == null) return false;
    return ativos(organizacaoId) >= org.limite;
  }
}

class _Seccao extends StatelessWidget {
  final String texto;
  const _Seccao(this.texto);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(texto, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
  );
}

class _PedidoCard extends StatefulWidget {
  final PedidoAcesso pedido;
  final AcessosVista vista;
  final Future<void> Function(PedidoAcesso, String, String?) onDecidir;
  final Future<void> Function(PedidoAcesso) onApagar;
  const _PedidoCard({required this.pedido, required this.vista, required this.onDecidir, required this.onApagar});
  @override
  State<_PedidoCard> createState() => _PedidoCardState();
}

class _PedidoCardState extends State<_PedidoCard> {
  String? _org;
  @override
  void initState() { super.initState(); _org = widget.pedido.organizacaoId; }

  @override
  Widget build(BuildContext context) {
    final p = widget.pedido;
    final v = widget.vista;
    final ocupacao = v.ocupacaoTexto(_org);
    final cheio = v.limiteAtingido(_org);
    return Card(child: Padding(padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(p.nome, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        Text(p.email),
        const SizedBox(height: 8),
        Text('Organização: ${p.organizacao}'),
        Text('Cargo: ${p.cargo == 'admin' ? 'Administrador' : 'Funcionário'}'
            ' · Entrada: ${p.origem == 'convite' ? 'Por convite' : 'Pedido livre'}'),
        Text('Pedido em ${Dates.data(p.criadoEm)}'),
        if (ocupacao != null) Text('Ocupação: $ocupacao'),
        if (p.origem == 'livre') DropdownButtonFormField<String?>(
          value: _org,
          decoration: const InputDecoration(labelText: 'Associar a organização (vazio = nova)'),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('Criar nova organização')),
            ...v.organizacoes.map((o) => DropdownMenuItem(
              value: o.id,
              child: Text('${o.nome} · ${v.ativos(o.id)} / ${o.limite}'))),
          ],
          onChanged: (x) => setState(() => _org = x),
        ),
        if (cheio) Padding(padding: const EdgeInsets.only(top: 8),
          child: Text('Limite de utilizadores atingido. Trate da vaga extra antes de aprovar.',
            style: TextStyle(color: AppColors.vermelho))),
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: [
          FilledButton(
            onPressed: () => widget.onDecidir(p, 'aprovado', _org),
            child: const Text('Aprovar')),
          OutlinedButton(
            onPressed: () => widget.onDecidir(p, 'recusado', null),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.vermelho),
            child: const Text('Recusar')),
          // Apagar não é uma decisão — é tirar a linha do servidor. Fica no
          // fim, com o peso de um ícone e não o de um botão.
          IconButton(
            tooltip: 'Apagar pedido',
            onPressed: () => widget.onApagar(p),
            icon: const Icon(Icons.delete_outline),
            color: AppColors.textSecondary),
        ]),
      ])));
  }
}

class _AprovadoCard extends StatelessWidget {
  final PedidoAcesso pedido;
  final String? ocupacao;
  final Future<void> Function(PedidoAcesso) onRevogar;
  const _AprovadoCard({required this.pedido, required this.ocupacao, required this.onRevogar});

  @override
  Widget build(BuildContext context) {
    final p = pedido;
    return Card(child: Padding(padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(p.nome, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        Text(p.email),
        const SizedBox(height: 8),
        Text('Organização: ${p.organizacao}'),
        Text('Cargo: ${p.cargo == 'admin' ? 'Administrador' : 'Funcionário'}'
            ' · Entrada: ${p.origem == 'convite' ? 'Por convite' : 'Pedido livre'}'),
        if (ocupacao != null) Text('Ocupação: $ocupacao'),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () => onRevogar(p),
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.vermelho),
          child: const Text('Revogar')),
      ])));
  }
}
