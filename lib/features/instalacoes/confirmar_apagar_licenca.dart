import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_spacing.dart';

/// Pergunta antes de apagar uma licença, com os números à frente.
///
/// A tabela é partilhada pelas duas apps e as consequências não são as mesmas.
/// Uma licença do Fist é uma linha solta: apagá-la não arrasta nada, e o
/// terminal volta a registar-se no arranque seguinte. Uma do POS pode ter
/// cadeia fiscal pendurada — e é por isso que a caixa mostra contagens em vez
/// de um aviso genérico que ninguém lê.
///
/// Com guias comunicadas à AT não há botão de apagar nenhum: o servidor recusa
/// na mesma, e oferecer o botão para ele falhar é fazer perder o tempo a quem
/// carrega. Nesse caso a caixa explica-se e aponta o caminho — desactivar.
Future<bool> confirmarApagarLicenca(
  BuildContext context, {
  required Map<String, dynamic> dependentes,

  /// Cliente e série, para o título dizer *qual* licença se apaga.
  String? quem,
}) async {
  int conta(String chave) =>
      int.tryParse('${dependentes[chave] ?? 0}') ?? 0;

  final guias = conta('guias');
  final series = conta('series');
  final credenciais = conta('credenciais');
  final nome = (dependentes['nome'] as String?)?.trim();
  final maquina = '${dependentes['machine_id'] ?? ''}';

  final resposta = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      scrollable: true,
      title: Text(
        guias > 0
            ? 'Esta não se apaga'
            : quem == null
            ? 'Apagar esta licença?'
            : 'Apagar a licença de $quem?',
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            nome == null || nome.isEmpty ? 'Sem nome' : nome,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            // O identificador do terminal por inteiro não cabe nem ajuda; o
            // princípio chega para distinguir duas linhas parecidas.
            '${dependentes['app'] ?? ''} · '
            '${maquina.length > 12 ? '${maquina.substring(0, 12)}…' : maquina}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (guias > 0)
            Text(
              'Tem $guias guia(s) comunicada(s) à AT. Isso é registo fiscal e '
              'não se apaga para arrumar uma lista. Se o terminal já não '
              'existe, desactiva a licença — deixa de contar e o histórico '
              'fica.',
              style: const TextStyle(color: AppColors.vermelho),
            )
          else ...[
            const Text('Some do servidor e não há como a trazer de volta.'),
            if (series > 0 || credenciais > 0) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'Vai junto com ela: '
                '${[
                  if (series > 0) '$series série(s) comunicada(s)',
                  if (credenciais > 0) '$credenciais credencial(is) WSE',
                ].join(' e ')}.',
                style: const TextStyle(
                  color: AppColors.vermelho,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Se o terminal ainda existir, volta a registar-se sozinho no '
              'arranque seguinte.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(guias > 0 ? 'Fechar' : 'Voltar'),
        ),
        if (guias == 0)
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.vermelho),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Apagar licença'),
          ),
      ],
    ),
  );
  return resposta ?? false;
}
