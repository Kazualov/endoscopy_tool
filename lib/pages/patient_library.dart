import 'package:endoscopy_tool/pages/main_page.dart';
import 'package:endoscopy_tool/pages/settings.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// hello Gleb

class Examination {
  final String id;
  final String patientId;
  final String? description;
  String? video_id;

  Examination({
    required this.id,
    required this.patientId,
    this.description,
    this.video_id,
  });

  factory Examination.fromJson(Map<String, dynamic> json) {
    return Examination(
      id: json['id'],
      patientId: json['patient_id'],
      description: json['description'],
      video_id: json['video_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'description': description,
      'video_id': video_id,
    };
  }
}

// Модель данных для пациента
class Patient {
  final String id;
  final String name;

  Patient({
    required this.id,
    required this.name,
  });

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: json['id'],
      name: json['name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}

// Сервис для работы с API
class ApiService {
  static const String baseUrl = 'http://127.0.0.1:8000'; 


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
  
  // Получить всех пациентов
  static Future<List<Patient>> getPatients() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/patients/'),
        headers: {'Content-Type': 'application/json'},
      );
      print(response);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Patient.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load patients: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching patients: $e');
      return [];
    }
  }
  
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
  
  // Получить пациента по ID
  static Future<Patient?> getPatientById(String id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/patients/$id'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        return Patient.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to load patient: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching patient: $e');
      return null;
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
  
  // Загрузить видео файл
  static Future<String?> uploadVideo(String filePath, String patientId) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload/'),
      );
      
      request.fields.addAll({
        'patient_id': patientId,
        'description': "default",
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




class EndoscopistApp extends StatelessWidget {
  const EndoscopistApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Обследования',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Arial',
      ),
      home: ExaminationGridScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ExaminationGridScreen extends StatefulWidget {
  ExaminationGridScreen({super.key});

  @override
  _ExaminationGridScreenState createState() => _ExaminationGridScreenState();
}

class _ExaminationGridScreenState extends State<ExaminationGridScreen> {
  List<Patient> patients = [];
  List<Examination> examinations = [];
  bool isLoading = true;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    loadPatients();
    loadExamination();
  }

  Future<void> loadPatients() async {
    setState(() {
      isLoading = true;
    });
    
    final loadedPatients = await ApiService.getPatients();
    
    setState(() {
      patients = loadedPatients;
      isLoading = false;
    });
  }

  Future<void> loadExamination() async {
    setState(() {
      isLoading = true;
    });

    final loadedExamination = await ApiService.getExamination();

    setState(() {
      examinations = loadedExamination;
      isLoading = false;
    });
  }

  Future<String?> getVideoPath(Examination examination) async {
    if (examination.video_id != null) {
      return await ApiService.loadVideoPath(examination.video_id!);
    }
    return null;
  }

  List<Examination> get filteredExamination {
    if (searchQuery.isEmpty) {
      return examinations;
    }
    return examinations.where((examination) => 
      examination.id.toLowerCase().contains(searchQuery.toLowerCase())
    ).toList();
  }

  // Получить имя пациента по ID
  String getPatientName(String patientId) {
    final patient = patients.firstWhere(
      (p) => p.id == patientId,
      orElse: () => Patient(id: '', name: 'Неизвестный пациент'),
    );
    return patient.name;
  }

  Future<void> addExaminationWithVideo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    
    if (result != null && result.files.single.path != null) {
      final filePath = result.files.single.path!;
      
      // Показать диалог для ввода данных пациента и обследования
      final registrationData = await showPatientRegistrationDialog();
      if (registrationData != null) {
        // Показать индикатор загрузки
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text('Создание обследования...'),
              ],
            ),
          ),
        );
        
        try {
          // 1. Создать пациента
          final patient_id = await ApiService.createPatient(
            registrationData["patient_id"]!,
          );
          
          if (patient_id != null) {
                        
            // 2. Создать обследование
            final examination = await ApiService.createExamination(
              patient_id,
              registrationData["serviceType"] ?? "Обследование"
            );

            print("Обследование создано");

            // 3. Загрузить видео
            final video_id = await ApiService.uploadVideoToExamination(examination!.id, filePath);
            examination.video_id = video_id;

            Navigator.of(context).pop(); // Закрыть индикатор загрузки
            
            await loadExamination(); // Обновить список обследований
            await loadPatients(); // Обновить список пациентов
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Обследование создано успешно')),
            );
            
            // Открыть MainPage с видео
            if (video_id != null) {
              Navigator.of(context, rootNavigator: true).pop();
              print("video id exist");
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MainPage(videoPath: filePath, examinationId: examination.id),
                ),
              );
              print("mainPage open");
            }
          } else {
            Navigator.of(context).pop(); // Закрыть индикатор загрузки
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Ошибка при создании пациента')),
            );
          }
        } catch (e) {
          Navigator.of(context).pop(); // Закрыть индикатор загрузки
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: $e')),
          );
        }
      }
    }
  }

  Future<void> addExaminationWithCamera() async {
    // Показать диалог для ввода данных пациента и обследования
    final registrationData = await showPatientRegistrationDialog();
    if (registrationData != null) {
      // Показать индикатор загрузки
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Создание обследования...'),
            ],
          ),
        ),
      );
      
      try {
        // 1. Создать пациента
        final patient_id = await ApiService.createPatient(
          registrationData["patient_id"]!,
        );
        
        if (patient_id != null) {
          // 2. Создать обследование без видео
          final examination = await ApiService.createExamination(
            patient_id,
            registrationData["serviceType"] ?? "Обследование",
          );
          
          
          Navigator.of(context).pop(); // Закрыть индикатор загрузки
          
          if (examination != null) {
            await loadExamination(); // Обновить список обследований
            await loadPatients(); // Обновить список пациентов
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Обследование создано успешно')),
            );
            
            // Открыть MainPage без видео
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MainPage(videoPath: "null",  examinationId: examination.id),
              ),
            );
          } else {
            // ignore: use_build_context_synchronously
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Ошибка при создании обследования')),
            );
          }
        } else {
          Navigator.of(context).pop(); // Закрыть индикатор загрузки
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка при создании пациента')),
          );
        }
      } catch (e) {
        Navigator.of(context).pop(); // Закрыть индикатор загрузки
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  Future<Map<String, String>?> showPatientRegistrationDialog() async {
    String? patient_id;
    String? serviceType;
    
    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Регистрация пациента'),
          content: Container(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  onChanged: (value) => patient_id = value,
                  decoration: InputDecoration(
                    labelText: 'Id *',
                    hintText: 'Введите id пациента',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  onChanged: (value) => serviceType = value,
                  decoration: InputDecoration(
                    labelText: 'Исследование/Услуга',
                    hintText: 'Введите тип исследования или услуги',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.medical_services),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                // Проверяем, что обязательные поля заполнены
                if (patient_id?.isNotEmpty == true) {
                  Navigator.of(context).pop({
                    'patient_id': patient_id ?? '',
                    'serviceType': serviceType ?? '',
                  });
                } else {
                  // Показать ошибку о незаполненных обязательных полях
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Заполните обязательные поля: Фамилия и Имя'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Text('Добавить'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 1,
        title: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'ПОИСК',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 10),
            ),
            onChanged: (value) {
              setState(() {
                searchQuery = value;
              });
            },
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.black),
            onPressed: () {
              loadExamination();
              loadPatients();
            },
          ),
          IconButton(
            icon: Icon(Icons.settings, color: Colors.black),
            onPressed: () async {
              final result = await showSettingsDialog(context);
              if (result != null) {
                print('Настройки обновлены: ${result.resolution}, ${result.path}, ${result.theme}');
                // Если нужно — обнови UI, состояние и т.п.
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: isLoading
            ? Center(child: CircularProgressIndicator())
            : GridView.builder(
                itemCount: filteredExamination.length + 1, // +1 for add button
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemBuilder: (context, index) {
                  if (index < filteredExamination.length) {
                    final examination = filteredExamination[index];
                    return GestureDetector(
                      onTap: () async {
                        final videoPath = await getVideoPath(examination);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MainPage(videoPath: videoPath!, examinationId: examination.id),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Color(0xFF00ACAB), width: 3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.black, width: 2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: examination.video_id != null
                                    ? Icon(Icons.video_library, size: 30, color: Colors.blue)
                                    : Icon(Icons.medical_services, size: 30, color: Colors.grey),
                              ),
                              SizedBox(height: 8),
                              Text(
                                examination.id,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 4),
                              Text(
                                getPatientName(examination.patientId),
                                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Exam ID: ${examination.id}',
                                style: TextStyle(fontSize: 8, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  } else {
                    return GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: Text("Добавить обследование"),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: Icon(Icons.video_library),
                                    title: Text("Выбрать видео с компьютера"),
                                    onTap: () {
                                      Navigator.of(context).pop();
                                      addExaminationWithVideo();
                                    },
                                  ),
                                  ListTile(
                                    leading: Icon(Icons.videocam),
                                    title: Text("Открыть камеру"),
                                    onTap: () {
                                      Navigator.of(context).pop();
                                      addExaminationWithCamera();
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Color(0xFF00ACAB), width: 3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Icon(Icons.add, size: 40),
                        ),
                      ),
                    );
                  }
                },
              ),
      ),
    );
  }
}
