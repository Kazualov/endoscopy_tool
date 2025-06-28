// Сервис для работы с API
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../pages/patient_library.dart';

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:8000';

  // Создать нового пациента
  static Future<String?> createPatient(String id) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/patients/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'id': id,
        }),
      );

      if (response.statusCode == 201) {
        // Сервер возвращает строку с ID в кавычках, убираем кавычки
        String patientId = response.body.replaceAll('"', '');
        return patientId;
      } else {
        throw Exception('Failed to create patient: ${response.statusCode}');
      }
    } catch (e) {
      print('Error creating patient: $e');
      return null;
    }
  }


  // Создать новое обследование
  static Future<Examination?> createExamination(String patientId, String description) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/examinations/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'patient_id': patientId,
          'description': description,
        }),
      );

      if (response.statusCode == 200) {
        return Examination.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to create examination: ${response.statusCode}');
      }
    } catch (e) {
      print('Error creating examination: $e');
      return null;
    }
  }


  static Future<List<Examination>> getExamination() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/examinations/'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Examination.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load examinations: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching examinations: $e');
      return [];
    }
  }


  static Future<String?> uploadVideoToExamination(String examination_id, String filePath) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/examinations/$examination_id/video/'),
      );

      request.fields.addAll({
        'examination_id': examination_id
      });

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          filePath,
        ),
      );

      final streamed = await request.send();
      final res = await http.Response.fromStream(streamed);

      if (res.statusCode == 200) {
        final jsonResp = jsonDecode(res.body);
        return jsonResp['video_id'] as String?; // Возвращаем video_id вместо video_path
      } else {
        throw Exception('Failed (${res.statusCode}): ${res.body}');
      }
    } catch (e) {
      print('Error uploading video: $e');
      return null;
    }
  }


  static Future<String?> loadVideo(String video_id) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/videos/$video_id/file'));

      if (response.statusCode == 200) {
        return response.body;
      } else {
        throw Exception('Failed to load video: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading video: $e');
      return null;
    }
  }

  /// Возвращает абсолютный путь к видео либо `null`, если что‑то пошло не так.
  static Future<String?> loadVideoPath(String videoId) async {
    try {
      final url = Uri.parse('$baseUrl/videos/$videoId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        // Декодируем тело в Map<String, dynamic>
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        // Берём путь, если он есть и он строка
        return data['file_path'] as String?;
      } else {
        throw Exception('Failed to load video: ${response.statusCode}');
      }
    } catch (e) {
      // Можно заменить debugPrint, log и т.д.
      print('Error loading video path: $e');
      return null;
    }
  }
}

