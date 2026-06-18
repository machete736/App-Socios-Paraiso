import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/socio_service.dart';
import 'login_screen.dart';
import 'qr_pago_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SocioService _socioService = SocioService();
  final AuthService _authService = AuthService();

  bool _cargando = true;
  String? _error;
  String? _idReciboGenerandoQr;

  Map<String, dynamic>? _perfil;
  List<dynamic> _medidores = [];
  List<dynamic> _recibos = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final perfil = await _socioService.getPerfil();
      final medidores = await _socioService.getMedidores();
      final recibos = await _socioService.getRecibos();

      if (!mounted) return;

      setState(() {
        _perfil = perfil;
        _medidores = medidores;
        _recibos = recibos;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'No se pudieron cargar los datos del socio.';
        _cargando = false;
      });
    }
  }

  Future<void> _cerrarSesion() async {
    await _authService.logout();

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _generarQrParaRecibo(Map<String, dynamic> recibo) async {
    final idRecibo = recibo['id_recibo']?.toString();

    if (idRecibo == null || idRecibo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontró el ID del recibo.')),
      );
      return;
    }

    setState(() {
      _idReciboGenerandoQr = idRecibo;
    });

    try {
      final respuesta = await _socioService.generarQrBnb(idRecibo);
      final transaccion = respuesta['transaccion'];

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QrPagoScreen(
            transaccion: transaccion,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceAll('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _idReciboGenerandoQr = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final socio = _perfil?['socio'];
    final nombre = socio?['nombre_completo'] ?? 'Socio';
    final ci = socio?['ci'] ?? '';
    final deudaTotal = _perfil?['deuda_total']?.toString() ?? '0.00';
    final recibosPendientes =
        _perfil?['recibos_pendientes']?.toString() ?? '0';
    final ultimoConsumo = _perfil?['ultimo_consumo']?.toString() ?? '0.00';
    final ultimoPeriodo = _perfil?['ultimo_periodo']?.toString() ?? '—';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi cuenta de agua'),
        actions: [
          IconButton(
            onPressed: _cargarDatos,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
          IconButton(
            onPressed: _cerrarSesion,
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _cargarDatos,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final esGrande = constraints.maxWidth > 700;

                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 950),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildHeader(nombre, ci),
                                const SizedBox(height: 16),

                                if (esGrande)
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildResumenCard(
                                          titulo: 'Deuda pendiente',
                                          valor: 'Bs $deudaTotal',
                                          icono: Icons.warning_amber,
                                          color: Colors.red,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildResumenCard(
                                          titulo: 'Recibos pendientes',
                                          valor: recibosPendientes,
                                          icono: Icons.receipt_long,
                                          color: Colors.orange,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildResumenCard(
                                          titulo: 'Último consumo',
                                          valor: '$ultimoConsumo m³',
                                          icono: Icons.water_drop,
                                          color: Colors.blue,
                                          subtitulo: ultimoPeriodo,
                                        ),
                                      ),
                                    ],
                                  )
                                else ...[
                                  _buildResumenCard(
                                    titulo: 'Deuda pendiente',
                                    valor: 'Bs $deudaTotal',
                                    icono: Icons.warning_amber,
                                    color: Colors.red,
                                  ),
                                  const SizedBox(height: 12),
                                  _buildResumenCard(
                                    titulo: 'Recibos pendientes',
                                    valor: recibosPendientes,
                                    icono: Icons.receipt_long,
                                    color: Colors.orange,
                                  ),
                                  const SizedBox(height: 12),
                                  _buildResumenCard(
                                    titulo: 'Último consumo',
                                    valor: '$ultimoConsumo m³',
                                    icono: Icons.water_drop,
                                    color: Colors.blue,
                                    subtitulo: ultimoPeriodo,
                                  ),
                                ],

                                const SizedBox(height: 20),
                                _buildMedidores(),
                                const SizedBox(height: 20),
                                _buildRecibosRecientes(),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 55,
            ),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: _cargarDatos,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String nombre, String ci) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: const Color(0xFF0D6EFD).withOpacity(0.12),
              child: const Icon(
                Icons.person,
                color: Color(0xFF0D6EFD),
                size: 35,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'CI: $ci',
                    style: const TextStyle(
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumenCard({
    required String titulo,
    required String valor,
    required IconData icono,
    required Color color,
    String? subtitulo,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icono,
                color: color,
                size: 30,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    valor,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (subtitulo != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitulo,
                      style: const TextStyle(
                        color: Colors.black45,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedidores() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mis medidores',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            if (_medidores.isEmpty)
              const Text(
                'No tiene medidores asignados.',
                style: TextStyle(color: Colors.black54),
              )
            else
              ..._medidores.map((m) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.speed, color: Color(0xFF0D6EFD)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Medidor ${m['numero_medidor'] ?? 'S/N'} - ${m['estado'] ?? ''}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildRecibosRecientes() {
    final recientes = _recibos.take(5).toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recibos recientes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            if (recientes.isEmpty)
              const Text(
                'No tiene recibos registrados.',
                style: TextStyle(color: Colors.black54),
              )
            else
              ...recientes.map((r) {
                final estado = r['estado_pago']?.toString() ?? 'Pendiente';
                final idRecibo = r['id_recibo']?.toString() ?? '';
                final generandoQr = _idReciboGenerandoQr == idRecibo;

                final color = estado == 'Cancelado'
                    ? Colors.green
                    : estado == 'Vencido'
                        ? Colors.red
                        : estado == 'En Revision' || estado == 'En Revisión'
                            ? Colors.amber.shade700
                            : Colors.orange;

                final puedePagarQr = estado != 'Cancelado';

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final esAngosto = constraints.maxWidth < 520;

                      final infoRecibo = Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.receipt_long),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '#${r['numero_recibo']} - ${r['periodo_nombre'] ?? ''}\nBs ${r['monto_total']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      );

                      final acciones = Column(
                        crossAxisAlignment: esAngosto
                            ? CrossAxisAlignment.stretch
                            : CrossAxisAlignment.end,
                        children: [
                          Chip(
                            label: Text(
                              estado,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                            backgroundColor: color,
                          ),
                          if (puedePagarQr) ...[
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 36,
                              child: ElevatedButton.icon(
                                onPressed: generandoQr
                                    ? null
                                    : () => _generarQrParaRecibo(
                                          Map<String, dynamic>.from(r),
                                        ),
                                icon: generandoQr
                                    ? const SizedBox(
                                        width: 15,
                                        height: 15,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.qr_code, size: 16),
                                label: Text(
                                  generandoQr ? 'Generando...' : 'Pagar QR',
                                ),
                              ),
                            ),
                          ],
                        ],
                      );

                      if (esAngosto) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            infoRecibo,
                            const SizedBox(height: 10),
                            acciones,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: infoRecibo),
                          const SizedBox(width: 12),
                          acciones,
                        ],
                      );
                    },
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}