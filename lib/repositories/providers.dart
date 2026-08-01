import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/actualizacao_info.dart';
import '../services/actualizacao/actualizacao_service.dart';
import '../services/licenca/comunicar_serie_service.dart';
import '../services/licenca/assinar_licenca_service.dart';
import '../services/licenca/gerir_licenca_service.dart';
import 'aceites_repository.dart';
import 'acessos_repository.dart';
import 'audit_licencas_repository.dart';
import 'clientes_repository.dart';
import 'licencas_repository.dart';
import 'pedidos_ajuda_repository.dart';
import 'pedidos_repository.dart';
import 'pings_repository.dart';
import 'punho_admin_repository.dart';
import 'series_repository.dart';
import 'sugestoes_repository.dart';

final clientesRepoProvider = Provider((_) => ClientesRepository());
final licencasRepoProvider = Provider((_) => LicencasRepository());
final pingsRepoProvider = Provider((_) => PingsRepository());
final pedidosRepoProvider = Provider((_) => PedidosRepository());
final aceitesRepoProvider = Provider((_) => AceitesRepository());
final pedidosAjudaRepoProvider = Provider((_) => PedidosAjudaRepository());
final sugestoesRepoProvider = Provider((_) => SugestoesRepository());
final auditLicencasRepoProvider = Provider((_) => AuditLicencasRepository());
final seriesRepoProvider = Provider((_) => SeriesRepository());
final acessosRepoProvider = Provider((_) => AcessosRepository());

/// Administração dos pedidos de acesso ao **Punho** (RPCs `punho_*_admin`).
/// Separado do [acessosRepoProvider], que trata dos acessos ao próprio Control.
final punhoAdminRepoProvider = Provider((_) => PunhoAdminRepository());

/// Acções remotas sobre licenças (via Edge Function `gerir-licenca`).
final gerirLicencaProvider =
    Provider((_) => GerirLicencaService(Supabase.instance.client));

/// Assinatura de licenças (via Edge Function `assinar-licenca`).
///
/// O Control **não assina**: a chave privada Ed25519 vive num secret do
/// Supabase e nunca esteve neste binário. Ver `assinar_licenca_service.dart`.
final assinarLicencaProvider =
    Provider((_) => AssinarLicencaService(Supabase.instance.client));

/// Comunicação de séries à AT (via Edge Function `comunicar-serie`).
final comunicarSerieProvider =
    Provider((_) => ComunicarSerieService(Supabase.instance.client));

/// Verifica se há build novo do Control (via Edge Function `versao-mais-recente`).
final actualizacaoServiceProvider =
    Provider((_) => ActualizacaoService(Supabase.instance.client));

/// Actualização disponível actualmente conhecida (`null` = nenhuma). O
/// verificador no arranque/timer 6h preenche; o banner e o modal observam; o X
/// do banner (só quando não obrigatória) volta a pôr `null` para esta sessão.
final actualizacaoDisponivelProvider =
    StateProvider<ActualizacaoInfo?>((_) => null);
