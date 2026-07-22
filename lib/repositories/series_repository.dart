import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/serie_comunicada.dart';

/// Leitura das séries comunicadas à AT (`series_comunicadas`).
///
/// Só leitura no Control: quem escreve é a Edge Function `comunicar-serie`
/// (service_role). O RLS deixa `authenticated` + `is_admin()` ler.
class SeriesRepository {
  SupabaseClient get _client => Supabase.instance.client;

  /// Séries de uma licença, da mais recente para a mais antiga.
  Future<List<SerieComunicada>> porLicenca(String licencaId) async {
    final rows = await _client
        .from('series_comunicadas')
        .select()
        .eq('licenca_id', licencaId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((e) => SerieComunicada.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
