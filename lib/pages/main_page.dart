import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'package:endoscopy_tool/pages/start_page.dart';
import 'package:endoscopy_tool/widgets/video_player_widget.dart';
import 'package:endoscopy_tool/widgets/screensot_button_widget.dart';

class MainPage extends StatelessWidget {
  final String videoPath;
  const MainPage({super.key, required this.videoPath});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MainPageLayout(videoPath: videoPath,),
    );
  }
}

class MainPageLayout extends StatefulWidget {
  final String videoPath;

  const MainPageLayout({super.key, required this.videoPath});

  @override
  _DynamicListExampleState createState() => _DynamicListExampleState();
}

class _DynamicListExampleState extends State<MainPageLayout> {
  // Video controller
  late VideoPlayerController _videoController;
  final GlobalKey _screenshotKey = GlobalKey();

  // List of items → each with time string
  List<String> items = []; // Example: ["0:06", "0:12", "1:30"]

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.file(File(widget.videoPath));

    // Example items (you can generate dynamically later)
    items = ["0:06", "0:12", "0:00"];
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  // Function to add a new item
  void addItem() {
    setState(() {
      // Just adding a dummy time for demo
      items.add("0:0${items.length + 1}");
    });
  }

  Duration _parseDuration(String timeString) {
    final parts = timeString.split(":");
    final minutes = int.parse(parts[0]);
    final seconds = int.parse(parts[1]);
    return Duration(minutes: minutes, seconds: seconds);
  }

  @override
  Widget build(BuildContext context) {
    Size screenSize = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // List of buttons
          Container(
            height: screenSize.height,
            width: 300,
            margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final timeString = items[index];
                return GestureDetector(
                  onTap: () {
                    print("Clicked $timeString");
                    final duration = _parseDuration(timeString);
                    _videoController.seekTo(duration);
                  },
                  child: Container(
                    height: 100,
                    width: 300,
                    margin: EdgeInsets.symmetric(vertical: 10, horizontal: 0),
                    decoration: BoxDecoration(
                      color: Color(0xFF00ACAB),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 100,
                          height: 80,
                          decoration: BoxDecoration(
                            // A photo instead of color
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          margin:
                          EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 0),
                              child: Text(
                                timeString,
                                style: TextStyle(
                                    fontSize: 24, fontFamily: 'Nunito'),
                              ),
                            ),
                            Container(
                              margin: EdgeInsets.symmetric(
                                  vertical: 0, horizontal: 0),
                              child: Text(
                                "Useful Text",
                                style: TextStyle(
                                    fontSize: 16, fontFamily: 'Nunito'),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Video player
          RepaintBoundary(
            key: _screenshotKey,
            child: Container(
              height: screenSize.height,
              width: screenSize.width - 500,
              margin: EdgeInsets.symmetric(vertical: 10, horizontal: 0),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Color(0xFF00ACAB),
                      width: 5
                  )
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: VideoPlayerWidget(controller: _videoController),
              ),
            ),
          ),

          // Button to add new item
          GestureDetector(
              onTap: addItem,
              child: Container(
                width: 50,
                height: 50,
                color: Colors.black,
              )),

          // Button to go to StartPage
          GestureDetector(
              onTap: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => StartPage()));
              },
              child: Container(
                width: 50,
                height: 50,
                color: Colors.green,
              )),
          ScreenshotButton(screenshotKey: _screenshotKey),
        ],
      ),
    );
  }
}
