import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_colors.dart';
import '../../core/app_radius.dart';
import '../../core/app_spacing.dart';
import '../../core/erros.dart';

// Credenciais: ver Supabase Dashboard → Authentication → Users
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nomeCtrl = TextEditingController();
  final _organizacaoCtrl = TextEditingController();
  final _conviteCtrl = TextEditingController();
  bool _aEntrar = false;
  bool _ocultarPass = true;
  bool _criarConta = false;
  String _cargo = 'funcionario';
  String? _erro;
  String _versao = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _versao = info.version);
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nomeCtrl.dispose();
    _organizacaoCtrl.dispose();
    _conviteCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _aEntrar = true;
      _erro = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      // Sinaliza ao SO que o login teve sucesso — dispara o "guardar palavra-passe"
      // do Google Password Manager.
      TextInput.finishAutofillContext();
      // O ecrã raiz observa a sessão e só abre a app quando o pedido tiver
      // sido aprovado manualmente.
    } catch (e) {
      setState(() => _erro = descreverErro(e));
    } finally {
      if (mounted) setState(() => _aEntrar = false);
    }
  }

  Future<void> _registar() async {
    if (_nomeCtrl.text.trim().isEmpty || _organizacaoCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty || _passwordCtrl.text.length < 6) {
      setState(() => _erro = 'Preenche nome, organização, email e uma palavra-passe com pelo menos 6 caracteres.');
      return;
    }
    setState(() { _aEntrar = true; _erro = null; });
    try {
      await Supabase.instance.client.auth.signUp(
        email: _emailCtrl.text.trim(), password: _passwordCtrl.text,
        data: {
          'nome': _nomeCtrl.text.trim(),
          'organizacao': _organizacaoCtrl.text.trim(),
          'cargo': _cargo,
          'codigo_convite': _conviteCtrl.text.trim(),
        },
      );
      if (!mounted) return;
      setState(() => _erro = 'Conta criada. Confirma o email, se solicitado, e aguarda a aprovação manual do acesso.');
    } catch (e) {
      setState(() => _erro = descreverErro(e));
    } finally { if (mounted) setState(() => _aEntrar = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.azul900,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: Column(
                    children: [
                      SizedBox(height: constraints.maxHeight * 0.12),
                      const _Identidade(),
                      const SizedBox(height: AppSpacing.xxxl),
                      _cartao(),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        _versao.isEmpty ? '' : 'v$_versao',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _cartao() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _criarConta ? 'Criar conta' : 'Acesso restrito',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: AppSpacing.lg),
            const _Rotulo('EMAIL'),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [
                AutofillHints.username,
                AutofillHints.email,
              ],
              decoration: _decoracao(),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_criarConta) ...[
              const _Rotulo('NOME'),
              TextField(controller: _nomeCtrl, decoration: _decoracao()),
              const SizedBox(height: AppSpacing.md),
              const _Rotulo('ORGANIZAÇÃO'),
              TextField(controller: _organizacaoCtrl, decoration: _decoracao()),
              const SizedBox(height: AppSpacing.md),
              const _Rotulo('CARGO PRETENDIDO'),
              DropdownButtonFormField<String>(value: _cargo, decoration: _decoracao(),
                items: const [
                  DropdownMenuItem(value: 'funcionario', child: Text('Funcionário')),
                  DropdownMenuItem(value: 'admin', child: Text('Administrador')),
                ], onChanged: (v) => setState(() => _cargo = v ?? 'funcionario')),
              const SizedBox(height: AppSpacing.md),
              const _Rotulo('CÓDIGO DE CONVITE (OPCIONAL)'),
              TextField(controller: _conviteCtrl, decoration: _decoracao()),
              const SizedBox(height: AppSpacing.md),
            ],
            const _Rotulo('PALAVRA-PASSE'),
            TextField(
              controller: _passwordCtrl,
              obscureText: _ocultarPass,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => _aEntrar
                  ? null
                  : (_criarConta ? _registar() : _login()),
              decoration: _decoracao().copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _ocultarPass ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () => setState(() => _ocultarPass = !_ocultarPass),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _aEntrar ? null : (_criarConta ? _registar : _login),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.azul700,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
              ),
              child: _aEntrar
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_criarConta ? 'Pedir acesso' : 'Entrar'),
                        SizedBox(width: AppSpacing.sm),
                        Icon(Icons.arrow_forward, size: 18),
                      ],
                    ),
            ),
            if (_erro != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _erro!,
                style: const TextStyle(color: AppColors.vermelho, fontSize: 12),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: _aEntrar ? null : () => setState(() { _criarConta = !_criarConta; _erro = null; }),
              child: Text(_criarConta ? 'Já tenho conta' : 'Criar conta'),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoracao() => InputDecoration(
    isDense: true,
    border: OutlineInputBorder(borderRadius: AppRadius.mdAll),
    enabledBorder: OutlineInputBorder(
      borderRadius: AppRadius.mdAll,
      borderSide: const BorderSide(color: AppColors.borda),
    ),
  );
}

class _Identidade extends StatelessWidget {
  const _Identidade();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.local_laundry_service,
            size: 40,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const Text(
          'WashInvoice',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        Text(
          'CONTROL',
          style: TextStyle(
            fontSize: 13,
            letterSpacing: 3,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

class _Rotulo extends StatelessWidget {
  final String texto;
  const _Rotulo(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
