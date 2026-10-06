import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/acoes.dart';
import '../../core/app_colors.dart';
import '../../core/app_radius.dart';
import '../../core/app_spacing.dart';
import '../../core/app_theme.dart';
import '../../core/config.dart';
import '../../core/erros.dart';
import '../../core/supabase_config.dart';
import '../../core/widgets/widgets.dart';
import '../../repositories/providers.dart';
import '../../services/fcm_service.dart';
import '../auth/login_screen.dart';
import '../backup/backup_screen.dart';

/// Ecrã Sobre/Sistema: identifica a app, o ambiente Supabase, o utilizador
/// autenticado e a última actividade recebida. Inclui terminar sessão.
class SobreScreen extends ConsumerStatefulWidget {
  const SobreScreen({super.key});

  @override
  ConsumerState<SobreScreen> createState() => _SobreScreenState();
}

class _SobreData {
  final PackageInfo packageInfo;
  final DateTime? ultimoPing;
  _SobreData(this.packageInfo, this.ultimoPing);
}

class _SobreScreenState extends ConsumerState<SobreScreen> {
  late Future<_SobreData> _future;
  bool _aVerificar = false;

  @override
  void initState() {
    super.initState();
    _future = _carregar();
  }

  /// Check on-demand contra a Edge Function `versao-mais-recente`. Complementa
  /// o safety net diário (main.dart:_verificadorActualizacaoProvider) para
  /// quem quer saber já se há build novo, sem esperar 24h. Se houver, o
  /// banner/modal em HomeShell aparecem sozinhos ao observar
  /// `actualizacaoDisponivelProvider`.
  Future<void> _verificarActualizacao() async {
    if (_aVerificar) return;
    setState(() => _aVerificar = true);
    try {
      final info = await ref.read(actualizacaoServiceProvider).verificar();
      if (!mounted) return;
      if (info != null) {
        ref.read(actualizacaoDisponivelProvider.notifier).state = info;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Actualização disponível: ${info.versaoActual}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Já estás na versão mais recente.')),
        );
      }
    } catch (e) {
      if (mounted) mostrarErro(e);
    } finally {
      if (mounted) setState(() => _aVerificar = false);
    }
  }

  Future<_SobreData> _carregar() async {
    final info = await PackageInfo.fromPlatform();
    DateTime? ultimo;
    try {
      final ping = await ref.read(pingsRepoProvider).ultimoGlobal();
      ultimo = ping?.criadoEm;
    } catch (_) {
      ultimo = null;
    }
    return _SobreData(info, ultimo);
  }

  String get _prefixoProjeto {
    final host = Uri.parse(SupabaseConfig.url).host;
    return host.split('.').first;
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _mudarPalavraPasse() async {
    final novaCtrl = TextEditingController();
    final confirmaCtrl = TextEditingController();
    var oculta = true;
    final novaFinal = await showDialog<String?>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) => AlertDialog(
        title: const Text('Mudar palavra-passe'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: novaCtrl,
              obscureText: oculta,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Nova palavra-passe',
                helperText: 'Pelo menos 8 caracteres.',
                suffixIcon: IconButton(
                  icon: Icon(oculta ? Icons.visibility : Icons.visibility_off),
                  tooltip: oculta
                      ? 'Mostrar palavra-passe'
                      : 'Ocultar palavra-passe',
                  onPressed: () => setSt(() => oculta = !oculta),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmaCtrl,
              obscureText: oculta,
              decoration: const InputDecoration(labelText: 'Confirmar'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final n = novaCtrl.text;
              final c = confirmaCtrl.text;
              if (n.length < 8) { ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Pelo menos 8 caracteres.'))); return; }
              if (n != c) { ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('As palavras-passe nao coincidem.'))); return; }
              Navigator.pop(ctx, n);
            },
            child: const Text('Guardar'),
          ),
        ],
      )),
    );
    novaCtrl.dispose();
    confirmaCtrl.dispose();
    if (novaFinal == null || novaFinal.isEmpty) return;
    try {
      await Supabase.instance.client.auth.updateUser(UserAttributes(password: novaFinal));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Palavra-passe actualizada.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nao foi possivel: ${e.toString().split("\n").first}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = Supabase.instance.client.auth.currentUser?.email;
    return Scaffold(
      appBar: AppBar(title: const Text('Sobre / Sistema')),
      body: FutureBuilder<_SobreData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErroView(
              erro: snapshot.error!,
              onRetry: () => setState(() { _future = _carregar(); }),
            );
          }
          final data = snapshot.data!;
          final v = data.packageInfo;
          final ano = DateTime.now().year;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              const _BlocoIdentidade(),
              const SizedBox(height: AppSpacing.xl),

              _CardSeccao(
                icone: Icons.info_outline,
                titulo: 'Aplicação',
                children: [
                  WiLinhaKV(
                      rotulo: 'Versão',
                      valor: '${v.version} (build ${v.buildNumber})'),
                  WiLinhaKV(rotulo: 'Pacote', valor: v.packageName, mono: true),
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonalIcon(
                      onPressed: _aVerificar ? null : _verificarActualizacao,
                      icon: _aVerificar
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.system_update_alt, size: 18),
                      label: Text(_aVerificar
                          ? 'A verificar...'
                          : 'Verificar actualização'),
                    ),
                  ),
                  // #222: se ja ha actualizacao disponivel, meter tambem o botao
                  // Descarregar inline (em vez de so o banner do HomeShell).
                  if (ref.watch(actualizacaoDisponivelProvider) != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed: () async {
                          final info = ref.read(actualizacaoDisponivelProvider);
                          if (info == null) return;
                          final url = Uri.parse(info.urlDownload);
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        },
                        icon: const Icon(Icons.download),
                        label: Text('Descarregar v${ref.watch(actualizacaoDisponivelProvider)?.versaoActual}'),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              _CardSeccao(
                icone: Icons.contact_page_outlined,
                titulo: 'Contactos',
                children: [
                  const WiLinhaKV(rotulo: 'Nome', valor: Config.nomeContacto),
                  _LinhaLink(
                    rotulo: 'Email',
                    valor: Config.emailContacto,
                    onTap: () => Acoes.enviarEmail(Config.emailContacto),
                  ),
                  _LinhaLink(
                    rotulo: 'Telefone',
                    valor: Config.telefoneContacto,
                    onTap: () => Acoes.ligarPara(Config.telefoneContacto),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              _CardSeccao(
                icone: Icons.storage,
                titulo: 'Supabase',
                children: [
                  WiLinhaKV(rotulo: 'Projeto', valor: _prefixoProjeto, mono: true),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: Row(
                      children: [
                        const SizedBox(
                            width: 100,
                            child: Text('Estado', style: AppText.label)),
                        const Icon(Icons.check_circle,
                            size: 16, color: AppColors.verde700),
                        const SizedBox(width: 6),
                        Text('Ligado',
                            style: AppText.bodyStrong
                                .copyWith(color: AppColors.verde900)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              _CardSeccao(
                icone: Icons.person_outline,
                titulo: 'Sessão',
                children: [
                  WiLinhaKV(rotulo: 'Utilizador', valor: email ?? '—'),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _mudarPalavraPasse,
                        icon: const Icon(Icons.password, size: 16),
                        label: const Text('Mudar palavra-passe'),
                      ),
                    ),
                  ),
                  WiLinhaKV(
                    rotulo: 'Último ping',
                    valor: data.ultimoPing == null
                        ? '—'
                        : timeago.format(data.ultimoPing!, locale: 'pt'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              _CardSeccao(
                icone: Icons.notifications_none,
                titulo: 'Notificações push',
                children: [
                  WiLinhaKV(
                    rotulo: 'Estado',
                    valor: FcmService.tokenRegistado != null
                        ? 'Registado'
                        : 'Sem token',
                  ),
                  WiLinhaKV(
                    rotulo: 'Token',
                    valor: FcmService.tokenRegistado == null
                        ? '—'
                        : '${FcmService.tokenRegistado!.substring(0, 12)}…',
                    mono: true,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Exportar dados'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.azul700,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BackupScreen()),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text('Terminar sessão'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.vermelho,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _logout,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: Text('${Config.marca} · $ano', style: AppText.caption),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BlocoIdentidade extends StatelessWidget {
  const _BlocoIdentidade();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.azul500,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.local_laundry_service,
              color: Colors.white, size: 30),
        ),
        const SizedBox(height: AppSpacing.md),
        const Text('Control',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text('GESTOR DE LICENÇAS',
            style: AppText.caption.copyWith(letterSpacing: 1)),
      ],
    );
  }
}

class _CardSeccao extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final List<Widget> children;
  const _CardSeccao({
    required this.icone,
    required this.titulo,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return WiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                Icon(icone, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: AppSpacing.sm),
                Text(titulo, style: AppText.h2),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _LinhaLink extends StatelessWidget {
  final String rotulo;
  final String valor;
  final VoidCallback onTap;
  const _LinhaLink(
      {required this.rotulo, required this.valor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.smAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            SizedBox(width: 100, child: Text(rotulo, style: AppText.label)),
            Expanded(
              child: Text(valor,
                  style: AppText.bodyStrong.copyWith(color: AppColors.azul700)),
            ),
          ],
        ),
      ),
    );
  }
}
