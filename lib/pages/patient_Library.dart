import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(EndoscopistApp());
}

// Модель данных для пациента
class Patient {
  final String id;
  final String name;
  final String? videoPath;

  Patient({
    required this.id,
    required this.name,
    this.videoPath,
  });

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: json['id'],
      name: json['name'],
      videoPath: json['video_path'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'video_path': videoPath,
    };
  }
}

// Сервис для работы с API
class ApiService {
  static const String baseUrl = 'http://127.0.0.1:8000/'; // Замените на ваш URL
  
  // Получить всех пациентов
  static Future<List<Patient>> getPatients() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/patients'),
        headers: {'Content-Type': 'application/json'},
      );
      
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
  static Future<Patient?> createPatient(String name, String? videoPath) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/patients'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': name,
          'video_path': videoPath,
        }),
      );
      
      if (response.statusCode == 201) {
        return Patient.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to create patient: ${response.statusCode}');
      }
    } catch (e) {
      print('Error creating patient: $e');
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
  
  // Обновить пациента
  static Future<Patient?> updatePatient(String id, String name, String? videoPath) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/patients/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': name,
          'video_path': videoPath,
        }),
      );
      
      if (response.statusCode == 200) {
        return Patient.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to update patient: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating patient: $e');
      return null;
    }
  }
  
  // Загрузить видео файл
  static Future<String?> uploadVideo(String filePath) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload-video'),
      );
      
      request.files.add(await http.MultipartFile.fromPath('video', filePath));
      
      var response = await request.send();
      
      if (response.statusCode == 200) {
        var responseData = await response.stream.toBytes();
        var responseString = String.fromCharCodes(responseData);
        var jsonResponse = json.decode(responseString);
        return jsonResponse['video_path'];
      } else {
        throw Exception('Failed to upload video: ${response.statusCode}');
      }
    } catch (e) {
      print('Error uploading video: $e');
      return null;
    }
  }
}

class EndoscopistApp extends StatelessWidget {
  const EndoscopistApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Пациенты',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Arial',
      ),
      home: PatientGridScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class PatientGridScreen extends StatefulWidget {
  PatientGridScreen({super.key});

  @override
  _PatientGridScreenState createState() => _PatientGridScreenState();
}

class _PatientGridScreenState extends State<PatientGridScreen> {
  List<Patient> patients = [];
  bool isLoading = true;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    loadPatients();
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

  List<Patient> get filteredPatients {
    if (searchQuery.isEmpty) {
      return patients;
    }
    return patients.where((patient) => 
      patient.name.toLowerCase().contains(searchQuery.toLowerCase())
    ).toList();
  }

  Future<void> addPatientWithVideo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    
    if (result != null && result.files.single.path != null) {
      final filePath = result.files.single.path!;
      
      // Показать диалог для ввода имени
      final name = await showPatientNameDialog();
      if (name != null && name.isNotEmpty) {
        // Показать индикатор загрузки
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text('Загрузка видео...'),
              ],
            ),
          ),
        );
        
        // Загрузить видео и создать пациента
        final videoPath = await ApiService.uploadVideo(filePath);
        final patient = await ApiService.createPatient(name, videoPath);
        
        Navigator.of(context).pop(); // Закрыть индикатор загрузки
        
        if (patient != null) {
          await loadPatients(); // Обновить список
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Пациент добавлен успешно')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка при добавлении пациента')),
          );
        }
      }
    }
  }

  Future<String?> showPatientNameDialog() async {
    String? name;
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Имя пациента'),
          content: TextField(
            onChanged: (value) => name = value,
            decoration: InputDecoration(hintText: 'Введите имя пациента'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(name),
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
            onPressed: loadPatients,
          ),
          IconButton(
            icon: Icon(Icons.settings, color: Colors.black),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.emoji_emotions, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: isLoading
            ? Center(child: CircularProgressIndicator())
            : GridView.builder(
                itemCount: filteredPatients.length + 1, // +1 for add button
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemBuilder: (context, index) {
                  if (index < filteredPatients.length) {
                    final patient = filteredPatients[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PatientRecordScreen(patient: patient),
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
                                child: patient.videoPath != null
                                    ? Icon(Icons.video_library, size: 30, color: Colors.blue)
                                    : Icon(Icons.person, size: 30, color: Colors.grey),
                              ),
                              SizedBox(height: 8),
                              Text(
                                patient.name,
                                style: TextStyle(fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 4),
                              Text(
                                'ID: ${patient.id}',
                                style: TextStyle(fontSize: 10, color: Colors.grey),
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
                              title: Text("Добавить пациента"),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: Icon(Icons.video_library),
                                    title: Text("Выбрать видео с компьютера"),
                                    onTap: () {
                                      Navigator.of(context).pop();
                                      addPatientWithVideo();
                                    },
                                  ),
                                  ListTile(
                                    leading: Icon(Icons.videocam),
                                    title: Text("Открыть камеру"),
                                    onTap: () {
                                      Navigator.of(context).pop();
                                      // Здесь можно добавить функционал записи с камеры
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Функция записи с камеры в разработке')),
                                      );
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
                          border: Border.all(color: Color(0xFF00ACAB), width: 2),
                          borderRadius: BorderRadius.circular(12),
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

class PatientRecordScreen extends StatelessWidget {
  final Patient patient;

  const PatientRecordScreen({super.key, required this.patient});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(patient.name)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Информация о пациенте',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 16),
                    Text('ID: ${patient.id}'),
                    SizedBox(height: 8),
                    Text('Имя: ${patient.name}'),
                    SizedBox(height: 8),
                    Text('Видео: ${patient.videoPath != null ? "Доступно" : "Не загружено"}'),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            if (patient.videoPath != null)
              ElevatedButton.icon(
                onPressed: () {
                  // Здесь можно добавить воспроизведение видео
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Воспроизведение видео: ${patient.videoPath}')),
                  );
                },
                icon: Icon(Icons.play_arrow),
                label: Text('Воспроизвести видео'),
              ),
          ],
        ),
      ),
    );
  }
}