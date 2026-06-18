import 'package:flutter/material.dart';
import 'dart:convert';

class QrPagoScreen extends StatelessWidget {
  final Map<String, dynamic> transaccion;

  const QrPagoScreen({
    super.key,
    required this.transaccion,
  });

  @override
  Widget build(BuildContext context) {
    final String qrBase64 = transaccion['qr_imagen_base64']?.toString() ?? '';
    final String referencia = transaccion['referencia']?.toString() ?? '—';
    final String monto = transaccion['monto']?.toString() ?? '0.00';
    final String estado = transaccion['estado']?.toString() ?? 'Generado';
    final String periodo = transaccion['periodo_nombre']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pago QR BNB'),
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
                    const Text('Escanea este QR para pagar', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
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
                      // Mostrar la imagen del banco
                      child: qrBase64.isNotEmpty
                          ? Image.memory(
                              base64Decode(qrBase64),
                              width: 260,
                              height: 260,
                              fit: BoxFit.contain,
                            )
                          : const SizedBox(
                              width: 260, height: 260,
                              child: Center(child: CircularProgressIndicator()),
                            ),
                    ),

                    const SizedBox(height: 22),
                    _dato('Monto', 'Bs $monto'),
                    _dato('Referencia', referencia),
                    _dato('Estado', estado),
                    _dato('Ambiente', 'Integración BNB'),
                    const SizedBox(height: 18),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Volver a mis recibos'),
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