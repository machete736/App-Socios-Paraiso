import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/socio_service.dart';

class QrPagoScreen extends StatefulWidget {
  final Map<String, dynamic> transaccion;
  final String idRecibo; // Necesitamos el ID para enviar la foto

  const QrPagoScreen({
    super.key,
    required this.transaccion,
    required this.idRecibo, // Asegúrate de pasarlo desde la pantalla anterior
  });

  @override
  State<QrPagoScreen> createState() => _QrPagoScreenState();
}

class _QrPagoScreenState extends State<QrPagoScreen> {
  final SocioService _socioService = SocioService();
  bool _procesando = false;

  Future<void> _escanearComprobante() async {
    final ImagePicker picker = ImagePicker();
    
    // Abrimos un menú inferior para que elija Cámara o Galería
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
        imageQuality: 70, // Comprimimos un poco para no saturar el servidor
      );

      if (foto != null) {
        setState(() => _procesando = true);
        
        File imagenFile = File(foto.path);
        
        // Enviamos la foto al servidor Django
        final respuesta = await _socioService.validarPagoOcr(widget.idRecibo, imagenFile);
        
        if (!mounted) return;
        
        // ¡ÉXITO!
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
                  Navigator.pop(context); // Cierra modal
                  Navigator.pop(context, true); // Regresa y avisa que ya se pagó
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
    // Ahora tomamos la URL del enlace directo
    final String qrUrl = widget.transaccion['qr_image_url']?.toString() ?? '';
    final String referencia = widget.transaccion['referencia']?.toString() ?? '—';
    final String monto = widget.transaccion['monto']?.toString() ?? '0.00';
    final String estado = widget.transaccion['estado']?.toString() ?? 'Generado';
    final String periodo = widget.transaccion['periodo_nombre']?.toString() ?? '';

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
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    const Icon(Icons.qr_code_2, size: 60, color: Color(0xFF0D6EFD)),
                    const SizedBox(height: 10),
                    const Text('Escanea este QR para pagar', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
                    const SizedBox(height: 6),
                    Text(periodo, style: const TextStyle(color: Colors.black54)),
                    const SizedBox(height: 22),

                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.black12),
                      ),
                      // Mostrar la imagen desde URL
                      child: qrUrl.isNotEmpty
                          ? Image.network(
                              qrUrl,
                              width: 260,
                              height: 260,
                              fit: BoxFit.contain,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const SizedBox(
                                  width: 260, height: 260,
                                  child: Center(child: CircularProgressIndicator()),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) => 
                                const SizedBox(
                                  width: 260, height: 260,
                                  child: Center(child: Icon(Icons.broken_image, size: 50, color: Colors.grey)),
                                ),
                            )
                          : const SizedBox(
                              width: 260, height: 260,
                              child: Center(child: Text("QR no disponible")),
                            ),
                    ),

                    const SizedBox(height: 22),
                    _dato('Monto', 'Bs $monto'),
                    _dato('Referencia', referencia),
                    _dato('Estado', estado),
                    _dato('Sistema', 'Inteligencia Artificial (OCR)'), // Detalle para impresionar al jurado
                    const SizedBox(height: 18),

                    // Botón para subir comprobante con efecto de carga
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _procesando ? null : _escanearComprobante,
                        icon: _procesando 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.camera_alt),
                        label: Text(_procesando ? 'Verificando Comprobante...' : 'Enviar Comprobante'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _procesando ? null : () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Cancelar y Volver'),
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
      ),
    );
  }

  Widget _dato(String titulo, String valor) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Expanded(child: Text(titulo, style: const TextStyle(color: Colors.black54))),
          Flexible(child: Text(valor, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}