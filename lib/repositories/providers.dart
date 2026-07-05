import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'aceites_repository.dart';
import 'clientes_repository.dart';
import 'licencas_repository.dart';
import 'pedidos_repository.dart';
import 'pings_repository.dart';

final clientesRepoProvider = Provider((_) => ClientesRepository());
final licencasRepoProvider = Provider((_) => LicencasRepository());
final pingsRepoProvider = Provider((_) => PingsRepository());
final pedidosRepoProvider = Provider((_) => PedidosRepository());
final aceitesRepoProvider = Provider((_) => AceitesRepository());
