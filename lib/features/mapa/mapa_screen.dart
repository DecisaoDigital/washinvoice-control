import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/erros.dart';
import '../../models/licenca.dart';
import '../../models/ping.dart';
import '../../repositories/providers.dart';

class _MapaData {
  final List<Ping> pings;
  final Map<String, Licenca> licencaPorMachine;
  _MapaData(this.pings, this.licencaPorMachine);
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
    final results = await Future.wait([
      pingsRepo.comLocalizacao(),
      licencasRepo.listar(),
    ]);
    final pings = results[0] as List<Ping>;
    final licencas = results[1] as List<Licenca>;
    final mapa = {for (final l in licencas) l.machineId: l};
    return _MapaData(pings, mapa);
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
    return data.pings
        .where((p) => p.lat != null && p.lon != null)
        .map((p) {
      final licenca = data.licencaPorMachine[p.machineId];
      return Marker(
        markerId: MarkerId(p.machineId),
        position: LatLng(p.lat!, p.lon!),
        icon: BitmapDescriptor.defaultMarkerWithHue(_hue(licenca?.estado)),
        infoWindow: InfoWindow(
          title: p.nif ??
              (p.machineId.length > 8
                  ? p.machineId.substring(0, 8)
                  : p.machineId),
          snippet: '${p.cidade ?? 'Sem cidade'} · v${p.versao ?? '?'}',
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
