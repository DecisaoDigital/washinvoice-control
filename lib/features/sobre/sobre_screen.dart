import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/app_colors.dart';
import '../../core/config.dart';
import '../../core/erros.dart';
import '../../core/supabase_config.dart';
import '../../repositories/providers.dart';
import '../../services/fcm_service.dart';
import '../auth/login_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _future = _carregar();
  }

  Future<_SobreData> _carregar() async {
    final info = await PackageInfo.fromPlatform();
    // Último ping é opcional/barato — se falhar, não estraga o ecrã.
    DateTime? ultimo;
    try {
      final ping = await ref.read(pingsRepoProvider).ultimoGlobal();
      ultimo = ping?.criadoEm;
    } catch (_) {
      ultimo = null;
    }
    return _SobreData(info, ultimo);
  }

  /// Prefixo do projeto Supabase, extraído do subdomínio da URL
  /// (ex.: https://oefqbkhioncakojipqyx.supabase.co → oefqbkhioncakojipqyx).
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
              onRetry: () => setState(() => _future = _carregar()),
            );
          }
          final data = snapshot.data!;
          final v = data.packageInfo;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Seccao('Aplicação'),
              _Card([
                _Linha('Nome', v.appName),
                _Linha('Versão', '${v.version} (build ${v.buildNumber})'),
                _Linha('Pacote', v.packageName),
              ]),
              const SizedBox(height: 12),
              _Seccao('Contactos'),
              _Card([
                _Linha('Nome', Config.nomeContacto),
                _Linha('Email', Config.emailContacto),
                _Linha('Telefone', Config.telefoneContacto),
              ]),
              const SizedBox(height: 12),
              _Seccao('Supabase'),
              _Card([
                _Linha('Projeto', _prefixoProjeto),
                _Linha('URL', SupabaseConfig.url, monospace: true),
              ]),
              const SizedBox(height: 12),
              _Seccao('Sessão'),
              _Card([
                _Linha('Utilizador', email ?? '—'),
                _Linha(
                  'Último ping recebido',
                  data.ultimoPing == null
                      ? '—'
                      : timeago.format(data.ultimoPing!, locale: 'pt'),
                ),
              ]),
              const SizedBox(height: 12),
              _Seccao('Notificações push'),
              _Card([
                _Linha(
                  'Estado',
                  FcmService.tokenRegistado != null
                      ? 'Registado neste dispositivo'
                      : 'Sem token — abre a app depois de login para registar',
                ),
                _Linha(
                  'Token',
                  FcmService.tokenRegistado == null
                      ? '—'
                      : '${FcmService.tokenRegistado!.substring(0, 12)}…',
                  monospace: true,
                ),
              ]),
              const SizedBox(height: 24),
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
            ],
          );
        },
      ),
    );
  }
}

class _Seccao extends StatelessWidget {
  final String texto;
  const _Seccao(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        texto,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> linhas;
  const _Card(this.linhas);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: linhas,
        ),
      ),
    );
  }
}

class _Linha extends StatelessWidget {
  final String rotulo;
  final String valor;
  final bool monospace;
  const _Linha(this.rotulo, this.valor, {this.monospace = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              rotulo,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: monospace
                ? SelectableText(
                    valor,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  )
                : Text(valor, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
