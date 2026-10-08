import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/app_filter/app_filter_provider.dart';
import '../../core/app_spacing.dart';
import '../../core/contexto_instalacoes.dart';
import '../../core/erros.dart';
import '../../core/widgets/widgets.dart';
import '../../models/licenca.dart';
import '../../models/ping.dart';
import '../../repositories/providers.dart';

// Markers custom: 4 assets PNG 96×96 em assets/markers/ (activa, a_expirar,
// expirada, suspensa), com as cores da paleta (ver tokens.md §1.5). Carregados
// uma vez como BitmapDescriptor e reutilizados por marker.

class _MapaData {
  final List<Ping> pings;
  final Map<String, Licenca> licencaPorMachine;
  final ContextoInstalacoes ctx;
  final Map<EstadoLicenca, BitmapDescriptor> icones;
  _MapaData(this.pings, this.licencaPorMachine, this.ctx, this.icones);
}

class MapaScreen extends ConsumerStatefulWidget {
  const MapaScreen({super.key});

  @override
  ConsumerState<MapaScreen> createState() => _MapaScreenState();
}

class _MapaScreenState extends ConsumerState<MapaScreen> {
  late Future<_MapaData> _future;

  static const _portugal = CameraPosition(
    target: LatLng(39.5, -8.0),
    zoom: 6.5,
  );

  @override
  void initState() {
    super.initState();
    _future = _carregar();
  }

  Future<_MapaData> _carregar() async {
    final pingsRepo = ref.read(pingsRepoProvider);
    final licencasRepo = ref.read(licencasRepoProvider);
    final clientesRepo = ref.read(clientesRepoProvider);

    final app = ref.read(appFilterProvider).valorApp;

    final pingsF = pingsRepo.comLocalizacao(app: app);
    final licencasF = licencasRepo.listar(app: app);
    final clientesF = clientesRepo.listar();
    final iconesF = _carregarIcones();
    await Future.wait([pingsF, licencasF, clientesF, iconesF]);

    final pings = await pingsF;
    final licencas = await licencasF;
    final clientes = await clientesF;
    final mapa = {for (final l in licencas) l.machineId: l};
    return _MapaData(
      pings,
      mapa,
      ContextoInstalacoes.build(
        clientes: clientes,
        licencas: licencas,
        pings: pings,
      ),
      await iconesF,
    );
  }

  Future<Map<EstadoLicenca, BitmapDescriptor>> _carregarIcones() async {
    Future<BitmapDescriptor> load(String nome) => BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(40, 40)),
      'assets/markers/$nome',
      width: 40,
      height: 40,
    );
    return {
      EstadoLicenca.activa: await load('activa.png'),
      EstadoLicenca.aExpirar: await load('a_expirar.png'),
      EstadoLicenca.expirada: await load('expirada.png'),
      EstadoLicenca.suspensa: await load('suspensa.png'),
    };
  }

  Set<Marker> _markers(_MapaData data) {
    return data.pings.where((p) => p.lat != null && p.lon != null).map((p) {
      final licenca = data.licencaPorMachine[p.machineId];
      final icone = data.icones[licenca?.estado ?? EstadoLicenca.suspensa]!;
      return Marker(
        markerId: MarkerId(p.machineId),
        position: LatLng(p.lat!, p.lon!),
        icon: icone,
        infoWindow: InfoWindow(
          title: data.ctx.nomeDe(machineId: p.machineId, nif: p.nif),
          snippet:
              '${data.ctx.sinalLocalidadeDe(machineId: p.machineId, nif: p.nif)} · v${p.versao ?? '?'}',
        ),
      );
    }).toSet();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      appFilterProvider,
      (_, __) => setState(() {
        _future = _carregar();
      }),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa'),
        actions: const [
          WiAppSelector(),
          SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: WiComPastilhaApp(
        corpo: FutureBuilder<_MapaData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ErroView(
                erro: snapshot.error!,
                onRetry: () => setState(() {
                  _future = _carregar();
                }),
              );
            }
            return GoogleMap(
              initialCameraPosition: _portugal,
              markers: _markers(snapshot.data!),
              myLocationButtonEnabled: false,
            );
          },
        ),
      ),
    );
  }
}
