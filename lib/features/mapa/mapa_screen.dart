import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/contexto_instalacoes.dart';
import '../../core/erros.dart';
import '../../models/licenca.dart';
import '../../models/ping.dart';
import '../../repositories/providers.dart';

// TODO(v1.4+): markers custom com 4 assets PNG 96×96 em assets/markers/
// (activa.png, a_expirar.png, expirada.png, suspensa.png), com as cores da
// paleta. Enquanto não existirem, usa-se BitmapDescriptor.defaultMarkerWithHue
// com os hues nativos (fallback explícito, ver Fase 6.6 do prompt v1.4).

class _MapaData {
  final List<Ping> pings;
  final Map<String, Licenca> licencaPorMachine;
  final ContextoInstalacoes ctx;
  _MapaData(this.pings, this.licencaPorMachine, this.ctx);
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

    final pingsF = pingsRepo.comLocalizacao();
    final licencasF = licencasRepo.listar();
    final clientesF = clientesRepo.listar();
    await Future.wait([pingsF, licencasF, clientesF]);

    final pings = await pingsF;
    final licencas = await licencasF;
    final clientes = await clientesF;
    final mapa = {for (final l in licencas) l.machineId: l};
    return _MapaData(
      pings,
      mapa,
      ContextoInstalacoes.build(
          clientes: clientes, licencas: licencas, pings: pings),
    );
  }

  double _hue(EstadoLicenca? estado) {
    switch (estado) {
      case EstadoLicenca.activa:
        return BitmapDescriptor.hueGreen;
      case EstadoLicenca.aExpirar:
        return BitmapDescriptor.hueOrange;
      case EstadoLicenca.expirada:
        return BitmapDescriptor.hueRed;
      case EstadoLicenca.suspensa:
      case null:
        return BitmapDescriptor.hueAzure;
    }
  }

  Set<Marker> _markers(_MapaData data) {
    return data.pings.where((p) => p.lat != null && p.lon != null).map((p) {
      final licenca = data.licencaPorMachine[p.machineId];
      return Marker(
        markerId: MarkerId(p.machineId),
        position: LatLng(p.lat!, p.lon!),
        icon: BitmapDescriptor.defaultMarkerWithHue(_hue(licenca?.estado)),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Mapa')),
      body: FutureBuilder<_MapaData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErroView(
              erro: snapshot.error!,
              onRetry: () => setState(() => _future = _carregar()),
            );
          }
          return GoogleMap(
            initialCameraPosition: _portugal,
            markers: _markers(snapshot.data!),
            myLocationButtonEnabled: false,
          );
        },
      ),
    );
  }
}
