import 'package:flutter/material.dart';

/// As duas respostas que o César pode dar a uma sugestão.
const respostasSugestao = <String>[
  'Muito obrigado pela sua sugestão! Vamos tê-la em conta.',
  'Muito obrigado pela sua sugestão. Infelizmente não vai ser possível desta vez.',
];

/// Pergunta que resposta enviar ao cliente. Devolve o texto escolhido, `''`
/// para «Só marcar» (sem resposta) ou `null` se cancelou.
Future<String?> escolherRespostaSugestao(BuildContext context) =>
    showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                'Responder ao cliente?',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('A resposta aparece dentro da app dele.'),
            ),
            for (final t in respostasSugestao)
              ListTile(
                leading: const Icon(Icons.reply),
                title: Text(t),
                onTap: () => Navigator.pop(ctx, t),
              ),
            ListTile(
              leading: const Icon(Icons.done),
              title: const Text('Só marcar'),
              onTap: () => Navigator.pop(ctx, ''),
            ),
          ],
        ),
      ),
    );
