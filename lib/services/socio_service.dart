import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';

class SocioService {
  final AuthService _authService = AuthService();

  Future<Map<String, dynamic>> getPerfil() async {
    final token = await _authService.getAccessToken();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/socio/perfil/'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Error al obtener perfil del socio');
  }

  Future<List<dynamic>> getMedidores() async {
    final token = await _authService.getAccessToken();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/socio/medidores/'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Error al obtener medidores');
  }

  Future<List<dynamic>> getRecibos() async {
    final token = await _authService.getAccessToken();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/socio/recibos/'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Error al obtener recibos');
  }

  Future<List<dynamic>> getPagos() async {
    final token = await _authService.getAccessToken();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/socio/pagos/'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Error al obtener pagos');
  }

  Future<Map<String, dynamic>> getConsumo({String? anio}) async {
    final token = await _authService.getAccessToken();
    final url = anio == null
        ? '${ApiConfig.baseUrl}/socio/consumo/'
        : '${ApiConfig.baseUrl}/socio/consumo/?anio=$anio';
    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Error al obtener consumo');
  }

  Future<Map<String, dynamic>> getEstadoCuenta({String? anio}) async {
    final token = await _authService.getAccessToken();
    final url = anio == null
        ? '${ApiConfig.baseUrl}/socio/estado-cuenta/'
        : '${ApiConfig.baseUrl}/socio/estado-cuenta/?anio=$anio';
    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Error al obtener estado de cuenta');
  }

  // ============================================================
  // FUNCIONES DEL NUEVO SISTEMA (QR GENÉRICO + IA OCR)
  // ============================================================
  
  // 1. Obtener el QR subido por el tesorero
  Future<Map<String, dynamic>> obtenerQrGenerico(String idRecibo) async {
    final token = await _authService.getAccessToken();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/mi-cuenta/$idRecibo/obtener-qr-generico/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {'transaccion': data};
    }
    
    String mensajeReal = 'Error al cargar QR.';
    try {
      final data = jsonDecode(response.body);
      if (data['error'] != null) mensajeReal = data['error'];
    } catch (_) {}
    throw Exception(mensajeReal);
  }

  // 2. Enviar el comprobante para la IA
  Future<Map<String, dynamic>> validarPagoOcr(String idRecibo, File imagen) async {
    final token = await _authService.getAccessToken();
    var uri = Uri.parse('${ApiConfig.baseUrl}/mi-cuenta/$idRecibo/validar-pago-ocr/');
    
    var request = http.MultipartRequest('POST', uri);
    request.headers.addAll({
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });

    // Adjuntamos la imagen
    request.files.add(
      await http.MultipartFile.fromPath('comprobante', imagen.path),
    );

    var response = await request.send();
    var responseData = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      return jsonDecode(responseData);
    } else {
      String mensajeReal = 'Error al validar el pago.';
      try {
        final data = jsonDecode(responseData);
        if (data['error'] != null) mensajeReal = data['error'];
      } catch (_) {}
      throw Exception(mensajeReal);
    }
  }

  // ============================================================
  // FUNCIÓN ANTIGUA (Guardada por si acaso)
  // ============================================================
  Future<Map<String, dynamic>> generarQrBnb(String idRecibo) async {
    final token = await _authService.getAccessToken();
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/mi-cuenta/$idRecibo/generar-qr-bnb/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json', 
      },
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return {'transaccion': data};
    }

    String mensajeReal = 'Error desconocido: Código ${response.statusCode}';
    try {
      final data = jsonDecode(response.body);
      if (data['error'] != null) {
        mensajeReal = data['error'];
      }
    } catch (_) {}
    throw Exception(mensajeReal);
  }
}