import 'package:endoscopy_tool/pages/main_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Examination {
  final String id;
  final String patientId;
  String? name;
  final String? description;
  String? video_id;

  Examination({
    required this.id,
    required this.patientId,
    this.name,
    this.description,
    this.video_id,
  });

  factory Examination.fromJson(Map<String, dynamic> json) {
    return Examination(
      id: json['id'],
      patientId: json['patient_id'],
      name: json["name"],
      description: json['description'],
      video_id: json['video_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      "name": name,
      'description': description,
      'video_id': video_id,
    };
  }

  Future<void> addName(String name) async {
    this.name = name;
  }
}

// Модель данных для пациента
class Patient {
  final String id;
  final String name;
  final String? surname;
  final String? middleName;
  final String? birthday;
  final String? gender;

  Patient({
    required this.id,
    required this.name,
    this.surname,
    this.middleName,
    this.birthday,
    this.gender,
  });

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: json['id'],
      name: json['name'],
      surname: json['surname'],
      middleName: json['middleName'],
      birthday: json['birthday'],
      gender: json['gender'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'surname': surname,
      'middleName': middleName,
      'birthday': birthday,
      'gender': gender,
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
  static Future<String?> createPatient(String name, String surname, String middleName, String birthday, String gender) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/patients/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': name,
          'surname': surname,
          'middlename': middleName,
          'birthday': birthday,
          'gender': gender,
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
          'name': 'Default Name'
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
      return await ApiService.loadVideo(examination.video_id!);
    }
    return null;
  }

  List<Examination> get filteredExamination {
    if (searchQuery.isEmpty) {
      return examinations;
    }
    return examinations.where((examination) => 
      examination.name!.toLowerCase().contains(searchQuery.toLowerCase())
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
            registrationData["firstName"]!,
            registrationData["lastName"]!,
            registrationData["middleName"] ?? "",
            registrationData["birthDate"] ?? "",
            "gender", // По умолчанию, можно добавить выбор пола в диалог
          );
          
          if (patient_id != null) {
                        
            // 2. Создать обследование
            final examination = await ApiService.createExamination(
              patient_id,
              registrationData["serviceType"] ?? "Обследование"
            );

            print("f");

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
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MainPage(videoPath: filePath),
                ),
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
          registrationData["firstName"]!,
          registrationData["lastName"]!,
          registrationData["middleName"] ?? "",
          registrationData["birthDate"] ?? "",
          "gender", // По умолчанию
        );
        
        if (patient_id != null) {
          // 2. Создать обследование без видео
          final examination = await ApiService.createExamination(
            patient_id,
            registrationData["serviceType"] ?? "Обследование",
          );
          
          
          Navigator.of(context).pop(); // Закрыть индикатор загрузки
          
          if (examination != null) {
            examination.addName(registrationData["firstName"]!);
            await loadExamination(); // Обновить список обследований
            await loadPatients(); // Обновить список пациентов
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Обследование создано успешно')),
            );
            
            // Открыть MainPage без видео
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MainPage(videoPath: "null"),
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
    String? lastName;
    String? firstName;
    String? middleName;
    String? birthDate;
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
                  onChanged: (value) => lastName = value,
                  decoration: InputDecoration(
                    labelText: 'Фамилия *',
                    hintText: 'Введите фамилию пациента',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                SizedBox(height: 16),
                TextField(
                  onChanged: (value) => firstName = value,
                  decoration: InputDecoration(
                    labelText: 'Имя *',
                    hintText: 'Введите имя пациента',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  onChanged: (value) => middleName = value,
                  decoration: InputDecoration(
                    labelText: 'Отчество',
                    hintText: 'Введите отчество пациента',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  onChanged: (value) => birthDate = value,
                  decoration: InputDecoration(
                    labelText: 'Дата рождения',
                    hintText: 'ДД.ММ.ГГГГ',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  keyboardType: TextInputType.datetime,
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
                if (lastName?.isNotEmpty == true && 
                    firstName?.isNotEmpty == true) {
                  Navigator.of(context).pop({
                    'lastName': lastName ?? '',
                    'firstName': firstName ?? '',
                    'middleName': middleName ?? '',
                    'birthDate': birthDate ?? '',
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
                            builder: (context) => MainPage(videoPath: videoPath!),
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
                                'ID: ${examination.id}',
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
