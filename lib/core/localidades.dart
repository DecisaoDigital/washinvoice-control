/// Tradução de cidades EN→PT.
///
/// A `ip-api.com` (usada pelo POS quando não há GPS) devolve nomes em inglês.
/// Este helper traduz os casos conhecidos; se não conhecer o nome, devolve
/// o valor original.
///
/// TODO(POS 1.6): mudar a chamada para `?fields=lat,lon,city&lang=pt` no POS —
/// os pings novos passam a chegar já em português; este helper continua a cobrir
/// os pings antigos que já estão na base em inglês.
///
/// Regra: qualquer `pings.cidade` que apareça na UI passa primeiro por
/// [traduzir] (ver `docs/design/tokens.md`).
class Localidades {
  Localidades._();

  static const _traducoes = {
    'Lisbon': 'Lisboa',
    'Oporto': 'Porto',
    'Bragança': 'Bragança',
    'Braga': 'Braga',
    'Coimbra': 'Coimbra',
    'Aveiro': 'Aveiro',
    'Faro': 'Faro',
    'Setúbal': 'Setúbal',
    // Adicionar mais consoante forem aparecendo na base.
  };

  /// Devolve o nome em português (se conhecido) ou o próprio valor.
  /// `null`/vazio → string vazia.
  static String traduzir(String? cidade) {
    if (cidade == null || cidade.trim().isEmpty) return '';
    final t = cidade.trim();
    return _traducoes[t] ?? t;
  }
}
