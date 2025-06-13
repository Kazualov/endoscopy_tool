import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

void main() {
  runApp(EndoscopistApp());
}

class EndoscopistApp extends StatelessWidget {
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

class PatientGridScreen extends StatelessWidget {
  final List<String> patients = List.generate(11, (index) => 'Имя $index');

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
          ),
        ),
        actions: [
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
        child: GridView.builder(
          itemCount: patients.length + 1, // +1 for add button
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemBuilder: (context, index) {
            if (index < patients.length) {
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PatientRecordScreen(name: patients[index]),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Color(0xFF00ACAB), width: 2),
                    borderRadius: BorderRadius.circular(12),
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
                        ),
                        SizedBox(height: 8),
                        Text(
                          patients[index],
                          style: TextStyle(fontWeight: FontWeight.bold),
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
                              onTap: () async {
                                Navigator.of(context).pop();
                                // Выбрать видео из файловой системы
                                FilePickerResult? result = await FilePicker.platform.pickFiles(
                                  type: FileType.video,
                                );
                                if (result != null) {
                                  String? filePath = result.files.single.path;
                                  print("Выбранное видео: $filePath");
                                  // Открыть камеру
                                  final picker = ImagePicker();
                                  final pickedVideo = await picker.pickVideo(source: ImageSource.camera);
                                  if (pickedVideo != null) {
                                    print("Видео с камеры: ${pickedVideo.path}");
                                    // Добавь пациента и открой экран, передав путь к видео
                                  }
                                }
                              },
                            ),
                            ListTile(
                              leading: Icon(Icons.videocam),
                              title: Text("Открыть камеру"),
                              onTap: () {
                                Navigator.of(context).pop();
                                // TODO: Реализуй открытие камеры
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

class PatientIcon extends StatelessWidget {


    @override
  Widget build(BuildContext context) {
    // TODO: implement build
    throw UnimplementedError();
  }

}

class PatientRecordScreen extends StatelessWidget {
  final String name;

  const PatientRecordScreen({Key? key, required this.name}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: Center(
        child: Text('Запись пациента: $name'),
      ),
    );
  }
}
