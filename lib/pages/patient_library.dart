import 'dart:async';

import 'package:endoscopy_tool/pages/main_page.dart';
import 'package:endoscopy_tool/pages/settings.dart';
import 'package:endoscopy_tool/widgets/VoiceCommandService.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../widgets/ApiService.dart';

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



//______________основной виджет__________________//
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

  StreamSubscription<String>? _voiceSubscription; // 👈 Добавляем подписку

  @override
  void initState() {
    super.initState();
    loadExamination();

    // 👇 Используем ГЛОБАЛЬНЫЙ экземпляр VoiceService
    _voiceSubscription = voiceService.commandStream.listen((command) {
      print('[MainPageLayout] 🎤 Получена команда: $command');
      if (command.toLowerCase().contains('exemination')){
        print('[MainPageLayout] создаем обследование...');
        _showAddExaminationDialog(context);
      } else if(command.toLowerCase().contains('choose camera')){
        Navigator.of(_dialogContext!).pop();
        addExaminationWithCamera();
      } else if(command.toLowerCase().contains('choose file')) {
        Navigator.of(_dialogContext!).pop();
        addExaminationWithVideo();
      }
    });
  }

  // загрузка осмотров
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

  // получить путь к видео по обследованию
  Future<String?> getVideoPath(Examination examination) async {
    if (examination.video_id != null) {
      return await ApiService.loadVideoPath(examination.video_id!);
    }
    return null;
  }

  //отсортировать осмотры по ID
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


  BuildContext? _dialogContext;
  void _showAddExaminationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        _dialogContext = context; // сохраняем контекст
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
            },
          ),
          IconButton(
            icon: Icon(Icons.settings, color: Colors.black),
            onPressed: () async {
              final result = await showSettingsDialog(context);
              if (result != null) {
                print('Настройки обновлены: ${result.resolution}, ${result.path}, ${result.theme}');
                //ApiService.setSaveDirectory(result.path);
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
                  _showAddExaminationDialog(context);
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
