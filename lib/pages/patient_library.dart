import 'dart:async';
import 'dart:io';

import 'package:endoscopy_tool/pages/main_page.dart';
import 'package:endoscopy_tool/pages/settings.dart';
import 'package:endoscopy_tool/modules/SettingsStorage.dart';
import 'package:endoscopy_tool/modules/VoiceCommandService.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../modules/ApiService.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

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


class HoverDeleteIcon extends StatefulWidget {
  final VoidCallback onDelete;

  const HoverDeleteIcon({required this.onDelete, Key? key}) : super(key: key);

  @override
  State<HoverDeleteIcon> createState() => _HoverDeleteIconState();
}

class _HoverDeleteIconState extends State<HoverDeleteIcon> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedOpacity(
        opacity: _hovering ? 1 : 0.2,
        duration: Duration(milliseconds: 150),
        child: GestureDetector(
          onTap: widget.onDelete,
          child: Container(
            padding: EdgeInsets.all(4),
            child: Icon(
              Icons.delete_forever_rounded,
              size: 30,
              color: _hovering ? Colors.red : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }
}

class EndoscopistApp extends StatelessWidget {
  const EndoscopistApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Обследования',
      theme: ThemeData(
        brightness: Brightness.light,
        fontFamily: 'Nunito',
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color(0xFF00ACAB),
          brightness: Brightness.light,
        ).copyWith(
          primary: Color(0xFF00ACAB),    // force your exact color
          secondary: Color(0xFF00ACAB),  // optional, match branding
          onPrimary: Colors.white,       // for text/icons on primary
          surface: Colors.white,
          background: Colors.white,
        ),
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
        addExamination();
        }
    });
  }

  Future<void> _deleteExamination(String examId) async{
    await ApiService.deleteExamination(examId);
    await loadExamination();
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
    ApiService.getExamination(); // ← кстати, тут тоже может не хватать await
    if (examination.video_id != null) {
      final settings = await SettingsStorage.loadSettings();
      final path_ = await ApiService.loadVideoPath(examination.video_id!); // ← вот здесь важно
      return path.join(settings!.path, path_);// "${settings?.path}/$path";
    }
    return "";
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


  Future<Map<String, dynamic>?> showPatientRegistrationDialog() async {
    String? patient_id;
    String? serviceType;
    VideoMode selectedMode = VideoMode.camera; // Default selection

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Регистрация пациента'),
          content: SingleChildScrollView(
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
                SizedBox(height: 16),
                DropdownButtonFormField<VideoMode>(
                  value: selectedMode,
                  decoration: InputDecoration(
                    labelText: 'Режим видео',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: VideoMode.camera,
                      child: Text('Снять видео'),
                    ),
                    DropdownMenuItem(
                      value: VideoMode.uploaded,
                      child: Text('Загрузить видео'),
                    ),
                  ],
                  onChanged: (mode) {
                    if (mode != null) {
                      selectedMode = mode;
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                  'Отмена'
              ),
            ),
            TextButton(
              onPressed: () {
                if (patient_id?.isNotEmpty == true) {
                  Navigator.of(context).pop({
                    'patient_id': patient_id ?? '',
                    'serviceType': serviceType ?? '',
                    'videoMode': selectedMode,
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Заполните обязательные поля: Id пациента'),
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

  Future<void> addExamination() async {
    final registrationData = await showPatientRegistrationDialog();
    if (registrationData == null) return;

    final VideoMode mode = registrationData['videoMode'] ?? VideoMode.camera;

    if (mode == VideoMode.camera) {
      addExaminationWithCamera(registrationData);
    } else if (mode == VideoMode.uploaded) {
      addExaminationWithUpload(registrationData);
    }
  }

  Future<void> addExaminationWithUpload(Map<String, dynamic> registrationData) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result == null || result.files.single.path == null) return;

    final filePath = result.files.single.path!;

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
      final patient_id = await ApiService.createPatient(
        registrationData["patient_id"]!,
      );

      if (patient_id != null) {
        final examination = await ApiService.createExamination(
          patient_id,
          registrationData["serviceType"] ?? "Обследование",
        );

        final video_id = await ApiService.uploadVideoToExamination(
          examination!.id,
          filePath,
        );
        examination.video_id = video_id;

        Navigator.of(context).pop();

        await loadExamination();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Обследование создано успешно')),
        );

        Navigator.of(context, rootNavigator: true).pop();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MainPage(
              initialMode: VideoMode.uploaded,
              videoPath: filePath,
              examinationId: examination.id,
            ),
          ),
        );
      } else {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при создании пациента')),
        );
      }
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  Future<void> addExaminationWithCamera(Map<String, dynamic> registrationData) async {
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
      final patient_id = await ApiService.createPatient(
        registrationData["patient_id"]!,
      );

      if (patient_id != null) {
        final examination = await ApiService.createExamination(
          patient_id,
          registrationData["serviceType"] ?? "Обследование",
        );

        Navigator.of(context).pop(); // close loading
        if (examination != null) {
          await loadExamination();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Обследование создано успешно')),
          );
          Navigator.of(context, rootNavigator: true).pop(); // close dialog
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MainPage(
                initialMode: VideoMode.camera,
                examinationId: examination.id,
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка при создании обследования')),
          );
        }
      } else {
        Navigator.of(context).pop(); // close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при создании пациента')),
        );
      }
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }


  bool _isHovered = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight + 10),
        child: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.white,
          elevation: 0,
          title: SizedBox(
            height: 40,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'ПОИСК',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), // rounded corners
                  borderSide: BorderSide(
                    color: Color(0xFF00ACAB), // custom border color
                    width: 10,          // custom thickness
                  ),
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 2, horizontal: 10),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
            ),
          ),
          actions: [
            Container(
              margin: EdgeInsets.symmetric(horizontal: 0, vertical:8),
              child: IconButton(
                icon: Icon(Icons.refresh, color: Color(0xFFF00ACAB)),
                onPressed: () {
                  loadExamination();
                },
              ),
            ),
            Container(
                margin: EdgeInsets.symmetric(horizontal: 0, vertical:8),
                child: IconButton(
                icon: Icon(Icons.folder_open_outlined, color: Color(0xFFF00ACAB)),
                onPressed: () async {
                  final result = await showSettingsDialog(context);
                  if (result != null) {
                    print('Настройки обновлены: ${result.path}');
                    ApiService.setSaveDirectory(result.path);
                  }
                },
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 0.0, horizontal: 15.0),
        child: Container(
          color: Colors.white,
          margin: EdgeInsets.symmetric(vertical: 5),
          child: isLoading
              ? Center(child: CircularProgressIndicator())
              : GridView.builder(
            itemCount: filteredExamination.length + 1, // +1 for add button
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (context, index) {
              if (index < filteredExamination.length) {
                final examination = filteredExamination[index];
                return GestureDetector(
                  onTap: () async {
                    final videoPath = await getVideoPath(examination);
                    print(videoPath);
                    print("Exists: ${await File(videoPath!.trim()).exists()}");
                    print('Directory exists: ${await Directory(videoPath).exists()}');

                    final sourceFile = File(videoPath.trim());
                    if (await sourceFile.exists()) {
                      final appDir = await getApplicationDocumentsDirectory();
                      final newPath = path.join(appDir.path, path.basename(videoPath));
                      await sourceFile.copy(newPath);
                      print('File copied to: $newPath');
                    } else {
                      print('Source file does NOT exist');
                    }

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MainPage(initialMode: VideoMode.uploaded, videoPath: videoPath!, examinationId: examination.id),
                      ),
                    );
                  },
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Color(0xFF00ACAB), width: 3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(height: 20), // Spacer to not overlap with the top icon

                              // Icons
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

                              // Id
                              Text(
                                examination.id,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 4),

                              // Description
                              Text(
                                examination.description!,
                                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),

                      Positioned(
                        top: 8,
                        right: 8,
                        child: HoverDeleteIcon(
                          onDelete: () async {
                            await _deleteExamination(examination.id.toString());
                          },
                        ),
                      ),
                    ],
                  ),

                );
              } else {
                return GestureDetector(
                  onTap: () {
                    addExamination();
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
        )
      ),
    );
  }
}
