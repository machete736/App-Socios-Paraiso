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
  String? _idReciboProcesando;
  
  // Controlador de las pestañas
  int _indicePestana = 0;

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

  // =======================================================
  // LA NUEVA CONEXIÓN AL SISTEMA DE PAGOS CON IA (OCR)
  // =======================================================
  Future<void> _abrirPantallaPago(Map<String, dynamic> recibo) async {
    final idRecibo = recibo['id_recibo']?.toString();

    if (idRecibo == null || idRecibo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No se encontró el ID del recibo.')),
      );
      return;
    }

    setState(() => _idReciboProcesando = idRecibo);

    try {
      // 1. Pedimos a Django el QR genérico
      final respuesta = await _socioService.obtenerQrGenerico(idRecibo);
      final transaccion = respuesta['transaccion'];

      if (!mounted) return;

      // 2. Abrimos la pantalla de pago y esperamos a ver si la IA lo aprueba
      final bool? pagoAprobado = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QrPagoScreen(
            transaccion: transaccion,
            idRecibo: idRecibo, // Pasamos el ID para el OCR
          ),
        ),
      );

      // 3. Si la IA aprobó el comprobante, recargamos la app
      if (pagoAprobado == true) {
        _cargarDatos();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 10),
                Text('Lista actualizada. Pago en revisión/aprobado.'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _idReciboProcesando = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Servicio de Agua', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
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
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: _construirPestanaActual(),
                    ),
                  ),
                ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indicePestana,
        onTap: (index) => setState(() => _indicePestana = index),
        selectedItemColor: const Color(0xFF0D6EFD),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.payment), label: 'Pendientes'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Historial'),
        ],
      ),
    );
  }

  // Controla qué vista mostrar según la pestaña seleccionada
  Widget _construirPestanaActual() {
    switch (_indicePestana) {
      case 0:
        return _buildTabInicio();
      case 1:
        return _buildTabRecibos(mostrarPendientes: true);
      case 2:
        return _buildTabRecibos(mostrarPendientes: false);
      default:
        return _buildTabInicio();
    }
  }

  // =======================================================
  // PESTAÑA 1: INICIO (Resumen y Medidores)
  // =======================================================
  Widget _buildTabInicio() {
    final socio = _perfil?['socio'];
    final nombre = socio?['nombre_completo'] ?? 'Socio';
    final ci = socio?['ci'] ?? '';
    final deudaTotal = _perfil?['deuda_total']?.toString() ?? '0.00';
    final recibosPendientes = _perfil?['recibos_pendientes']?.toString() ?? '0';
    final ultimoConsumo = _perfil?['ultimo_consumo']?.toString() ?? '0.00';
    final ultimoPeriodo = _perfil?['ultimo_periodo']?.toString() ?? '—';

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(nombre, ci),
          const SizedBox(height: 16),
          
          // Tarjetas de Resumen
          LayoutBuilder(builder: (context, constraints) {
            final esGrande = constraints.maxWidth > 600;
            if (esGrande) {
              return Row(
                children: [
                  Expanded(child: _buildResumenCard(titulo: 'Deuda Total', valor: 'Bs $deudaTotal', icono: Icons.warning_amber, color: Colors.red)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildResumenCard(titulo: 'Pendientes', valor: recibosPendientes, icono: Icons.receipt_long, color: Colors.orange)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildResumenCard(titulo: 'Último Consumo', valor: '$ultimoConsumo m³', icono: Icons.water_drop, color: Colors.blue, subtitulo: ultimoPeriodo)),
                ],
              );
            } else {
              return Column(
                children: [
                  _buildResumenCard(titulo: 'Deuda Total', valor: 'Bs $deudaTotal', icono: Icons.warning_amber, color: Colors.red),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildResumenCard(titulo: 'Pendientes', valor: recibosPendientes, icono: Icons.receipt_long, color: Colors.orange)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildResumenCard(titulo: 'Consumo', valor: '$ultimoConsumo m³', icono: Icons.water_drop, color: Colors.blue, subtitulo: ultimoPeriodo)),
                    ],
                  )
                ],
              );
            }
          }),

          const SizedBox(height: 24),
          _buildMedidores(),
        ],
      ),
    );
  }

  // =======================================================
  // PESTAÑAS 2 y 3: RECIBOS (Pendientes o Historial)
  // =======================================================
  Widget _buildTabRecibos({required bool mostrarPendientes}) {
    // Filtramos la lista dependiendo de la pestaña
    final listaFiltrada = _recibos.where((r) {
      final estado = r['estado_pago']?.toString() ?? 'Pendiente';
      final estaPagado = estado == 'Cancelado';
      return mostrarPendientes ? !estaPagado : estaPagado;
    }).toList();

    if (listaFiltrada.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 60),
          Icon(
            mostrarPendientes ? Icons.sentiment_very_satisfied : Icons.history_toggle_off,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            mostrarPendientes 
                ? '¡Felicidades!\nNo tienes deudas pendientes.' 
                : 'Aún no tienes recibos cancelados.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, color: Colors.black54),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: listaFiltrada.length,
      itemBuilder: (context, index) {
        final r = listaFiltrada[index];
        final estado = r['estado_pago']?.toString() ?? 'Pendiente';
        final idRecibo = r['id_recibo']?.toString() ?? '';
        final procesando = _idReciboProcesando == idRecibo;

        final color = estado == 'Cancelado'
            ? Colors.green
            : estado == 'Vencido'
                ? Colors.red
                : estado == 'En Revision' || estado == 'En Revisión'
                    ? Colors.amber.shade700
                    : Colors.orange;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      r['periodo_nombre'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Chip(
                      label: Text(estado, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      backgroundColor: color,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Recibo #${r['numero_recibo']}', style: const TextStyle(color: Colors.black54)),
                        const SizedBox(height: 4),
                        Text('Bs ${r['monto_total']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0D6EFD))),
                      ],
                    ),
                    if (mostrarPendientes)
                      ElevatedButton.icon(
                        onPressed: procesando ? null : () => _abrirPantallaPago(Map<String, dynamic>.from(r)),
                        icon: procesando
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.qr_code_scanner),
                        label: Text(procesando ? 'Cargando...' : 'Pagar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D6EFD),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =======================================================
  // COMPONENTES REUTILIZABLES (UI)
  // =======================================================
  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 55),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            ElevatedButton.icon(onPressed: _cargarDatos, icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String nombre, String ci) {
    return Card(
      elevation: 0,
      color: const Color(0xFF0D6EFD),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: Colors.white.withOpacity(0.2),
              child: const Icon(Icons.person, color: Colors.white, size: 35),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nombre, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('CI: $ci', style: TextStyle(color: Colors.white.withOpacity(0.8))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumenCard({required String titulo, required String valor, required IconData icono, required Color color, String? subtitulo}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, color: color, size: 24),
              const SizedBox(width: 8),
              Expanded(child: Text(titulo, style: const TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w600))),
            ],
          ),
          const SizedBox(height: 12),
          Text(valor, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          if (subtitulo != null) ...[
            const SizedBox(height: 4),
            Text(subtitulo, style: const TextStyle(color: Colors.black45, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget _buildMedidores() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Mis Medidores Asignados', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (_medidores.isEmpty)
          const Text('No tiene medidores asignados.', style: TextStyle(color: Colors.black54))
        else
          ..._medidores.map((m) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFF0D6EFD).withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.speed, color: Color(0xFF0D6EFD)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Medidor: ${m['numero_medidor'] ?? 'S/N'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Estado: ${m['estado'] ?? ''}', style: const TextStyle(color: Colors.black54)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}