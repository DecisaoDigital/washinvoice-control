import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/aceite_termo.dart';

class AceitesRepository {
  SupabaseClient get _client => Supabase.instance.client;

  /// Último aceite de termos de um machine_id (o mais recente).
  Future<AceiteTermo?> ultimoPorMachineId(String machineId) async {
    final row = await _client
        .from('aceites_termos')
        .select()
        .eq('machine_id', machineId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    return AceiteTermo.fromJson(row);
  }
}
