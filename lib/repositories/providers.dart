import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/licenca/gerir_licenca_service.dart';
import 'aceites_repository.dart';
import 'audit_licencas_repository.dart';
import 'clientes_repository.dart';
import 'licencas_repository.dart';
import 'pedidos_ajuda_repository.dart';
import 'pedidos_repository.dart';
import 'pings_repository.dart';
import 'sugestoes_repository.dart';

final clientesRepoProvider = Provider((_) => ClientesRepository());
final licencasRepoProvider = Provider((_) => LicencasRepository());
final pingsRepoProvider = Provider((_) => PingsRepository());
final pedidosRepoProvider = Provider((_) => PedidosRepository());
final aceitesRepoProvider = Provider((_) => AceitesRepository());
final pedidosAjudaRepoProvider = Provider((_) => PedidosAjudaRepository());
final sugestoesRepoProvider = Provider((_) => SugestoesRepository());
final auditLicencasRepoProvider = Provider((_) => AuditLicencasRepository());

/// Acções remotas sobre licenças (via Edge Function `gerir-licenca`).
final gerirLicencaProvider =
    Provider((_) => GerirLicencaService(Supabase.instance.client));
