import 'package:flutter_test/flutter_test.dart';
import 'package:washinvoice_control/models/ping.dart';

/// Task #95 — o modelo Ping lê os campos enriquecidos do ping.
void main() {
  Map<String, dynamic> base() => {
        'id': 'p1',
        'machine_id': 'abc123',
        'created_at': '2026-07-21T10:00:00Z',
      };

  test('fromJson lê ip_publico, estado_licenca, termos_aceites, origem', () {
    final p = Ping.fromJson({
      ...base(),
      'ip_publico': '46.102.20.34',
      'estado_licenca': 'activa',
      'termos_aceites': true,
      'origem': 'timer_6h',
    });
    expect(p.ipPublico, '46.102.20.34');
    expect(p.estadoLicenca, 'activa');
    expect(p.termosAceites, isTrue);
    expect(p.origem, 'timer_6h');
  });

  test('sem esses campos → tudo null (pings antigos)', () {
    final p = Ping.fromJson(base());
    expect(p.ipPublico, isNull);
    expect(p.estadoLicenca, isNull);
    expect(p.termosAceites, isNull);
    expect(p.origem, isNull);
  });

  test('round-trip pelo toJson preserva os campos', () {
    final original = Ping.fromJson({
      ...base(),
      'ip_publico': '80.1.2.3',
      'estado_licenca': 'bloqueada',
      'termos_aceites': false,
      'origem': 'aceite_termos',
    });
    final round = Ping.fromJson(original.toJson());
    expect(round.ipPublico, '80.1.2.3');
    expect(round.estadoLicenca, 'bloqueada');
    expect(round.termosAceites, isFalse);
    expect(round.origem, 'aceite_termos');
  });

  test('termos_aceites=false é distinto de ausente (null)', () {
    expect(Ping.fromJson({...base(), 'termos_aceites': false}).termosAceites,
        isFalse);
    expect(Ping.fromJson(base()).termosAceites, isNull);
  });
}
