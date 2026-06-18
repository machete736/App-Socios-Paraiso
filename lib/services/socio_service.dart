import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';

class SocioService {
  final AuthService _authService = AuthService();

  Future<Map<String, dynamic>> getPerfil() async {
    final token = await _authService.getAccessToken();

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/socio/perfil/'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception('Error al obtener perfil del socio');
  }

  Future<List<dynamic>> getMedidores() async {
    final token = await _authService.getAccessToken();

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/socio/medidores/'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception('Error al obtener medidores');
  }

  Future<List<dynamic>> getRecibos() async {
    final token = await _authService.getAccessToken();

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/socio/recibos/'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception('Error al obtener recibos');
  }

  Future<List<dynamic>> getPagos() async {
    final token = await _authService.getAccessToken();

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/socio/pagos/'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception('Error al obtener pagos');
  }

  Future<Map<String, dynamic>> getConsumo({String? anio}) async {
    final token = await _authService.getAccessToken();

    final url = anio == null
        ? '${ApiConfig.baseUrl}/socio/consumo/'
        : '${ApiConfig.baseUrl}/socio/consumo/?anio=$anio';

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception('Error al obtener consumo');
  }

  Future<Map<String, dynamic>> getEstadoCuenta({String? anio}) async {
    final token = await _authService.getAccessToken();

    final url = anio == null
        ? '${ApiConfig.baseUrl}/socio/estado-cuenta/'
        : '${ApiConfig.baseUrl}/socio/estado-cuenta/?anio=$anio';

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception('Error al obtener estado de cuenta');
  }

  // ============================================================
  // AQUÍ ESTÁ LA MAGIA CORREGIDA
  // ============================================================
  Future<Map<String, dynamic>> generarQrBnb(String idRecibo) async {
    final token = await _authService.getAccessToken();

    // NOTA TÉCNICA: Si ves que en tu Django (urls.py) registraste la ruta como "mi-cuenta",
    // tal vez debas cambiar 'socio/recibos' por 'mi-cuenta'. Lo he dejado tal como
    // lo tenías para no romper tu lógica, pero tenlo en mente por si lanza error 404.
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/mi-cuenta/$idRecibo/generar-qr-bnb/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json', // <- ESTO ELIMINA EL ERROR <!DOCTYPE html>
      },
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      
      // Empaquetamos la respuesta en 'transaccion' para que tu HomeScreen no reciba NULL
      return {'transaccion': data};
    }

    // Blindaje anti-pantalla negra:
    // Si Django nos manda un error, intentamos leerlo como JSON. 
    // Si Django choca y manda un HTML, el 'catch' atrapa la explosión y 
    // te muestra un error limpio en lugar de la pantalla negra.
    try {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? 'Error al generar QR BNB');
    } catch (e) {
      throw Exception('El servidor rechazó la solicitud: Código ${response.statusCode}');
    }
  }
}