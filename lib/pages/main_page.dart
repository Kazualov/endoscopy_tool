import 'package:flutter/material.dart';

class MainPage extends StatelessWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: DynamicListExample(),
    );
  }
}

class DynamicListExample extends StatefulWidget {
  @override
  _DynamicListExampleState createState() => _DynamicListExampleState();
}

class _DynamicListExampleState extends State<DynamicListExample> {
  // This will hold the data (in this case, just integers for demonstration)
  List<int> items = [];

  // Function to add a new item
  void addItem() {
    setState(() {
      items.add(items.length + 1);
    });
  }

  // Function to remove an item (optional, adds interactivity)
  void removeItem(int index) {
    setState(() {
      items.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Container(
            height: 2005,
            width: 300,
            margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: (){
                    addItem;
                    print("Clicked");
                  },
                  child: Container(
                    height: 100,
                    width: 300,
                    margin: EdgeInsets.symmetric(vertical: 5, horizontal: 0),
                    decoration: BoxDecoration(
                        color: Color(0xFF00ACAB),
                        borderRadius: BorderRadius.circular(20)
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 100,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          margin: EdgeInsets.symmetric(vertical: 0, horizontal: 10)
                        ),
                        Column(
                          children: [
                            Container(
                              margin: EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                              child: Text(
                                  "3:28",
                                  style: TextStyle(
                                      fontSize: 24,
                                      fontFamily: ''
                                  )
                              ),
                            ),
                            Container(
                              margin: EdgeInsets.symmetric(vertical: 0, horizontal: 5),
                              child: Text(
                                  "Useful Text",
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontFamily: ''
                                  )
                              ),
                            ),
                          ],
                        )

                      ],
                    ),
                  ),
                );//Container to produce
              },
            ),
          ), //List of Photos
          Container(
            height: 500,
            width: 500,
            margin: EdgeInsets.only(top: 5 ),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20), // Rounded corners (16 pixels)
            ),
          ),//Video
          GestureDetector(
            onTap: addItem,
            child: Container(
              width: 50,
              height: 50,
              color: Colors.black,
            )
          )
        ],
      ),
    );
  }
}
