import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/scale_model.dart';
import '../models/evaluation_model.dart';

class ApiService {
  // In produzione questo andrà letto da variabili d'ambiente o config
  static const String baseUrl = 'http://localhost:8000';

  Future<List<ScaleModel>> getScales() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/scales'));

      if (response.statusCode == 200) {
        final List<dynamic> body = jsonDecode(response.body);
        return body.map((json) => ScaleModel.fromJson(json)).toList();
      } else {
        throw Exception('Errore nel caricamento delle scale: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Errore di connessione al server: $e');
    }
  }

  Future<List<EvaluationModel>> getEvaluations(String idPatient, int year) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/patients/$idPatient/evaluations/$year'));

      if (response.statusCode == 200) {
        final List<dynamic> body = jsonDecode(response.body);
        return body.map((json) => EvaluationModel.fromJson(json)).toList();
      } else {
        throw Exception('Errore nel caricamento dello storico: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Errore di connessione al server: $e');
    }
  }

  Future<bool> createEvaluation(EvaluationModel evaluation) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/evaluations'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(evaluation.toJson()),
      );

      return response.statusCode == 201;
    } catch (e) {
      throw Exception('Errore durante il salvataggio: $e');
    }
  }
}
