import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_colors.dart';
import '../../core/app_spacing.dart';

/// O ecra que o link do email de recuperacao tem de atravessar.
///
/// Existe porque abrir o link *ja autentica*: sem este ecra pelo meio, quem
/// carregasse no email entrava no Control sem lhe ser pedida palavra-passe
/// nenhuma — a antiga continuava a valer, ele julgava te-la mudado, e no dia
/// seguinte nao entrava. Quem decide quando este ecra aparece e desaparece e o
/// trinco em `modo_de_recuperacao.dart`.
class NovaPalavraPasseScreen extends StatefulWidget {
  const NovaPalavraPasseScreen({
    super.key,
    this.aoGuardar,
    required this.aoDesistir,
  });

  /// Devolve a mensagem de erro a mostrar, ou `null` se correu bem. Injectavel
  /// para os testes nao falarem com o Supabase.
  final Future<String?> Function(String palavraPasse)? aoGuardar;

  /// Sair daqui tem de fechar a sessao que o link abriu.
  final VoidCallback aoDesistir;

  @override
  State<NovaPalavraPasseScreen> createState() => _NovaPalavraPasseScreenState();
}

class _NovaPalavraPasseScreenState extends State<NovaPalavraPasseScreen> {
  final _nova = TextEditingController();
  final _repetida = TextEditingController();
  bool _oculta = true;
  bool _ocupado = false;
  String? _erro;
  bool _feito = false;

  @override
  void dispose() {
    _nova.dispose();
    _repetida.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final nova = _nova.text;
    // Duas vezes e nao uma: um erro de dedos aqui tranca a conta na tentativa
    // seguinte, e ja nao ha segundo link para a destrancar.
    final invalida = nova.length < 8
        ? 'A palavra-passe deve ter pelo menos 8 caracteres.'
        : (nova == _repetida.text ? null : 'As duas nao sao iguais.');
    if (invalida != null) {
      setState(() => _erro = invalida);
      return;
    }
    setState(() {
      _ocupado = true;
      _erro = null;
    });
    final erro = await (widget.aoGuardar ?? _guardarNoSupabase)(nova);
    if (!mounted) return;
    setState(() {
      _ocupado = false;
      _erro = erro;
      _feito = erro == null;
    });
  }

  Future<String?> _guardarNoSupabase(String palavraPasse) async {
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: palavraPasse),
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Nao foi possivel guardar. Confirma a ligacao.';
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.azul900,
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Nova palavra-passe',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  'Escolhe a que vais usar a partir de agora.',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _nova,
                  obscureText: _oculta,
                  autofocus: true,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: InputDecoration(
                    labelText: 'Nova palavra-passe',
                    helperText: 'Pelo menos 8 caracteres.',
                    suffixIcon: IconButton(
                      // Ver o que se escreveu. Numa palavra-passe longa num
                      // teclado de telemovel, escrever as cegas e a diferenca
                      // entre entrar e tentar tres vezes.
                      icon: Icon(
                        _oculta ? Icons.visibility : Icons.visibility_off,
                      ),
                      tooltip: _oculta
                          ? 'Mostrar palavra-passe'
                          : 'Esconder palavra-passe',
                      onPressed: () => setState(() => _oculta = !_oculta),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _repetida,
                  obscureText: _oculta,
                  autofillHints: const [AutofillHints.newPassword],
                  onSubmitted: (_) => _ocupado ? null : _guardar(),
                  decoration: const InputDecoration(labelText: 'Repete'),
                ),
                if (_erro != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _erro!,
                    style: const TextStyle(color: AppColors.vermelho),
                  ),
                ],
                if (_feito) ...[
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    'Palavra-passe alterada.',
                    style: TextStyle(color: AppColors.verde700),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: _ocupado ? null : _guardar,
                  child: const Text('Guardar'),
                ),
                TextButton(
                  onPressed: _ocupado ? null : widget.aoDesistir,
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
