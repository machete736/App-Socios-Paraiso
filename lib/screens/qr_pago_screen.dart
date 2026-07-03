import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:gal/gal.dart';
import '../services/socio_service.dart';

class QrPagoScreen extends StatefulWidget {
  final Map<String, dynamic> transaccion;
  final String idRecibo;

  const QrPagoScreen({
    super.key,
    required this.transaccion,
    required this.idRecibo,
  });

  @override
  State<QrPagoScreen> createState() => _QrPagoScreenState();
}

class _QrPagoScreenState extends State<QrPagoScreen> {
  final SocioService _socioService = SocioService();
  bool _procesando = false;
  bool _descargando = false;

  // ==========================================
  // NUEVA FUNCIÓN: Traductor de Meses
  // ==========================================
  String _formatearMes(String periodo) {
    if (periodo.isEmpty || !periodo.contains('-')) return periodo;
    try {
      final partes = periodo.split('-');
      final anio = partes[0];
      final mesNumero = int.parse(partes[1]);
      
      const meses = [
        'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 
        'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
      ];

      if (mesNumero >= 1 && mesNumero <= 12) {
        return '${meses[mesNumero - 1]} $anio'; // Ejemplo: Mayo 2026
      }
    } catch (e) {
      return periodo; // Si algo falla, devuelve el original por seguridad
    }
    return periodo;
  }
// ==========================================
  // NUEVA FUNCIÓN: Descargar QR a la galería
  // ==========================================
  Future<void> _descargarQR(String url) async {
    if (url.isEmpty) return;
    
    setState(() => _descargando = true);
    try {
      // 1. Descargamos la imagen
      var response = await http.get(Uri.parse(url));
      
      // 2. Usamos el nuevo paquete 'gal' para guardarla en un álbum genial
      await Gal.putImageBytes(
        Uint8List.fromList(response.bodyBytes),
        album: "Agua Paraiso", 
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.download_done, color: Colors.white),
              SizedBox(width: 10),
              Text("QR guardado en álbum: Agua Paraiso"),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error al guardar. Revisa los permisos de almacenamiento."),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _descargando = false);
    }
  }

  // ==========================================
  // FUNCIÓN: Escanear y subir comprobante
  // ==========================================
  Future<void> _escanearComprobante() async {
    final ImagePicker picker = ImagePicker();
    
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                  leading: const Icon(Icons.photo_library, color: Color(0xFF0D6EFD)),
                  title: const Text('Elegir de la Galería'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _procesarImagen(picker, ImageSource.gallery);
                  }),
              ListTile(
                leading: const Icon(Icons.photo_camera, color: Color(0xFF0D6EFD)),
                title: const Text('Tomar Foto'),
                onTap: () {
                  Navigator.of(context).pop();
                  _procesarImagen(picker, ImageSource.camera);
                },
              ),
            ],
          ),
        );
      }
    );
  }

  Future<void> _procesarImagen(ImagePicker picker, ImageSource source) async {
    try {
      final XFile? foto = await picker.pickImage(
        source: source,
        imageQuality: 70,
      );

      if (foto != null) {
        setState(() => _procesando = true);
        File imagenFile = File(foto.path);
        
        final respuesta = await _socioService.validarPagoOcr(widget.idRecibo, imagenFile);
        
        if (!mounted) return;
        
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text("¡Pago Validado!"),
              ],
            ),
            content: Text(respuesta['mensaje'] ?? "Comprobante verificado con éxito."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context, true);
                },
                child: const Text("Aceptar", style: TextStyle(color: Colors.green)),
              )
            ],
          )
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text(e.toString().replaceAll('Exception: ', ''))),
            ],
          ),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String qrUrl = widget.transaccion['qr_image_url']?.toString() ?? '';
    final String monto = widget.transaccion['monto']?.toString() ?? '0.00';
    final String estado = widget.transaccion['estado']?.toString() ?? 'Generado';
    
    // Obtenemos el periodo original (ej. 2026-05) y lo convertimos
    final String periodoBruto = widget.transaccion['periodo_nombre']?.toString() ?? '';
    final String periodoFormateado = _formatearMes(periodoBruto);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Validación de Pago'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              elevation: 0,
              color: Colors.transparent,
              child: Column(
                children: [
                  // =======================================
                  // SECCIÓN 1: Tarjeta del QR
                  // =======================================
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Column(
                      children: [
                        qrUrl.isNotEmpty
                            ? Image.network(
                                qrUrl,
                                width: double.infinity,
                                fit: BoxFit.contain,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return const SizedBox(
                                    height: 200,
                                    child: Center(child: CircularProgressIndicator()),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) => 
                                  const SizedBox(
                                    height: 200,
                                    child: Center(child: Icon(Icons.broken_image, size: 50, color: Colors.grey)),
                                  ),
                              )
                            : const SizedBox(
                                height: 200,
                                child: Center(child: Text("QR no disponible")),
                              ),
                        
                        // Botón de descargar debajo del QR
                        if (qrUrl.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          TextButton.icon(
                            onPressed: _descargando ? null : () => _descargarQR(qrUrl),
                            icon: _descargando 
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.download),
                            label: Text(_descargando ? 'Descargando...' : 'Descargar QR'),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF0D6EFD),
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // =======================================
                  // SECCIÓN 2: Detalles del Recibo Limpios
                  // =======================================
                  _dato('Mes', periodoFormateado), // AQUÍ ESTÁ EL CAMBIO MÁGICO
                  _dato('Monto', 'Bs $monto'),
                  _dato('Estado', estado),
                  
                  const SizedBox(height: 24),

                  // =======================================
                  // SECCIÓN 3: Botones de Acción
                  // =======================================
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _procesando ? null : _escanearComprobante,
                      icon: _procesando 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.camera_alt),
                      label: Text(
                        _procesando ? 'Verificando Comprobante...' : 'Enviar Comprobante',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50), // Verde agradable
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _procesando ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Cancelar y Volver', style: TextStyle(fontSize: 16)),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dato(String titulo, String valor) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Expanded(child: Text(titulo, style: const TextStyle(color: Colors.black54, fontSize: 16))),
          Flexible(child: Text(valor, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        ],
      ),
    );
  }
}