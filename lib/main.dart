import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fl_chart/fl_chart.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF4A4E69),
        scaffoldBackgroundColor: const Color(0xFFF2E9E4),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: const Color(0xFF4A4E69),
          secondary: const Color(0xFF9A8C98),
          background: const Color(0xFFF2E9E4),
          surface: const Color(0xFFC9ADA7),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFF22223B)),
          bodyMedium: TextStyle(color: Color(0xFF22223B)),
        ),
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _shouldShowOxygenAlert = false;
  bool _shouldShowTemperatureAlert = false;
  bool _shouldShowHumidityAlert = false;
  bool _shouldShowMovementAlert = false;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }
Future<List<Map<String, dynamic>>> getLast20OutOfRangeReadings() async {
  Query query = FirebaseFirestore.instance
      .collection('sensorData')
      .orderBy(FieldPath.documentId, descending: true);
  
  List<Map<String, dynamic>> outOfRangeDocuments = [];
  bool reachedLimit = false;
  DocumentSnapshot? lastDocument;

  while (!reachedLimit) {
    QuerySnapshot querySnapshot = lastDocument == null
        ? await query.limit(300).get()
        : await query.startAfterDocument(lastDocument).limit(50).get();

    if (querySnapshot.docs.isEmpty) break;

    for (QueryDocumentSnapshot doc in querySnapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;

      // Check out-of-range conditions
      bool isOutOfRangeSpO2 = data['SpO2'] < 90;
      bool isOutOfRangeHeartRate = data['heartRate'] < 60 || data['heartRate'] > 100;
      bool isOutOfRangeBodyTemperature = data['bodyTemperature'] >= 37.5;
      bool isOutOfRangeHumidity = data['humidity'] >= 70;
      bool isHighTemperature = data['temperature'] >= 50;
      bool isShaking = data['status'] == "shaking";

      // Document is out of range only if all readings are out of range and temperature is less than 50
      if (isOutOfRangeSpO2 && isOutOfRangeHeartRate && isOutOfRangeBodyTemperature &&
          isOutOfRangeHumidity && !isHighTemperature && isShaking) {
        outOfRangeDocuments.add({
          'timestamp': data['timestamp'],
          'SpO2': data['SpO2'],
          'heartRate': data['heartRate'],
          'bodyTemperature': data['bodyTemperature'],
          'humidity': data['humidity'],
          'temperature': data['temperature'],
          'status': data['status'], // Include status in the readings
        });
      }

      if (outOfRangeDocuments.length >= 20) {
        reachedLimit = true;
        break;
      }
    }

    lastDocument = querySnapshot.docs.last;
  }

  return outOfRangeDocuments;
}
  void _showAlertDialog(String title, String advice) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(advice),
          actions: <Widget>[
            TextButton(
              child: Text("OK"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
  Future<void> _showNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'stress_channel',
      'Stress Alerts',
      importance: Importance.high,
      priority: Priority.high,
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(0, title, body, platformChannelSpecifics);
  }

  Stream<QueryDocumentSnapshot<Map<String, dynamic>>> getLatestReading() {
    return FirebaseFirestore.instance
        .collection('sensorData')
        .orderBy(FieldPath.documentId, descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) {
            throw Exception('No documents found');
          }
          return snapshot.docs.first;
        });
  }

 Widget _buildStressIndicator(int stressLevel) {
  Color color;
  if (stressLevel <= 1) {
    color = Colors.green;
  } else if (stressLevel == 2) {
   color = Colors.orange;
  }  else {
    color = Colors.red;
  }

  return GestureDetector(
    onTap: () async {
      List<Map<String, dynamic>> readings = await getLast20OutOfRangeReadings();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StressReadingsPage(readings: readings),
        ),
      );
    },
    child: Container(
      width: 100,
      height: 100,
      margin: EdgeInsets.only(
        bottom: MediaQuery.of(context).size.height * 0.1,
        left: MediaQuery.of(context).size.width * 0.02,
        right: MediaQuery.of(context).size.width * 0.02,
      ),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
            
          const Center(
            child: Text(
              'Stress',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  @override
@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color.fromARGB(255, 241, 241, 241), // Make background transparent for the image to show
    body: Stack(
      children: [
        // Background image
       
        // Content over the background
        SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 0.0),
                child: Image.asset(
                  'assets/logo.png',
                  width: 250,
                  height: 250,
                  fit: BoxFit.contain,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 20.0, bottom: 10.0),
                child: StreamBuilder<QueryDocumentSnapshot<Map<String, dynamic>>>(
                  stream: getLatestReading(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    if (!snapshot.hasData || snapshot.data == null) {
                      return const Center(child: Text('No data available'));
                    }

                    var data = snapshot.data!.data();
                    double spo2 = data['SpO2']?.toDouble() ?? 100.0;
                    double heartRate = data['heartRate']?.toDouble() ?? 0.0;
                    double temperature = data['temperature']?.toDouble() ?? 0.0;
                    double bodyTemperature = data['bodyTemperature']?.toDouble() ?? 36.5;
                    double humidity = data['humidity']?.toDouble() ?? 40.0;
                    double mq135 = data['MQ135']?.toDouble() ?? 0.0;
                    String status = data['status'] ?? 'stable';

                    int stressLevel = 0;
                    if (spo2 < 90) stressLevel++;
                    if (bodyTemperature > 37) stressLevel++;
                    if (humidity > 50) stressLevel++;
                    if (status == "shaking") stressLevel++;

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _triggerAlerts(spo2, bodyTemperature, humidity, status);
                    });

                    return Column(
                      children: [
                        _buildStressIndicator(stressLevel),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          childAspectRatio: 0.9,
                          padding: const EdgeInsets.all(8.0),
                          children: [
                            _buildRoundedRectangleWidget(
                              icon: Icons.health_and_safety,
                              label: 'Status: $status',
                              padding: const EdgeInsets.all(8.0),
                              sensorType: 'status',
                            ),
                            _buildRoundedRectangleWidget(
                              icon: Icons.favorite,
                              label: 'SpO2: $spo2',
                              padding: const EdgeInsets.all(8.0),
                              sensorType: 'SpO2',
                            ),
                            _buildRoundedRectangleWidget(
                              icon: Icons.heart_broken,
                              label: 'Heart Rate: $heartRate',
                              padding: const EdgeInsets.all(8.0),
                              sensorType: 'heartrate',
                            ),
                            _buildRoundedRectangleWidget(
                              icon: Icons.thermostat,
                              label: 'Body Temp: $bodyTemperature',
                              padding: const EdgeInsets.all(8.0),
                              sensorType: 'bodyTemperature',
                            ),
                            _buildRoundedRectangleWidget(
                              icon: Icons.sunny,
                              label: 'Temperature: $temperature',
                              padding: const EdgeInsets.all(8.0),
                              sensorType: 'temperature',
                            ),
                            _buildRoundedRectangleWidget(
                              icon: Icons.water,
                              label: 'Humidity: $humidity',
                              padding: const EdgeInsets.all(8.0),
                              sensorType: 'humidity',
                            ),
                            _buildRoundedRectangleWidget(
                              icon: Icons.air,
                              label: 'Air Quality: $mq135',
                              padding: const EdgeInsets.all(8.0),
                              sensorType: 'MQ135',
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

void _triggerAlerts(double spo2, double bodyTemperature, double humidity, String status) {
  if (spo2 < 90 ) {
    _shouldShowOxygenAlert = true;
    _showAlertDialog('Low Oxygen', 'Your SpO2 level is below 90. Please seek medical advice and stay hydrated.');
    _showNotification('Low Oxygen', 'Your SpO2 level is below 90. Please seek medical advice and stay hydrated.');
  }

  if (bodyTemperature > 37 ) {
    _shouldShowTemperatureAlert = true;
    _showAlertDialog('High Temperature', 'High Temperature detected. please relax and wash your face with cold water.');
    _showNotification('High Temperature','High Temperature detected. please relax and wash your face with cold water.');
  }

  if (humidity > 50 ) {
    _shouldShowHumidityAlert = true;
    _showAlertDialog('High Humidity', 'High humidity detected. Please relax.');
    _showNotification('High Humidity','High humidity detected. Please relax.');
  }

  if (status == "shaking") {
    _shouldShowMovementAlert = true;
    _showAlertDialog('Unusual Movement', 'Shaking detected. Please stay relaxed.');
    _showNotification('Shaking detected','Shaking detected. Please stay relaxed.');
  }
}

 Widget _buildRoundedRectangleWidget({
  required IconData icon,
  required String label,
  required EdgeInsets padding,
  required String sensorType,
}) {
  return GestureDetector(
    onTap: () {
      if (sensorType != 'status') { // Prevent navigation for 'status'
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SensorChartPage(sensorType: sensorType),
          ),
        );
      }
    },
    child: Padding(
      padding: padding,
      child: Container(
        width: 150,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15.0),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.5),
              spreadRadius: 3,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 40,
              color: Theme.of(context).primaryColor, // Keep icon color consistent with the theme
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
color: Color.fromARGB(255, 13, 55, 71), // Equivalent to #0D3747 with full opacity
                ),
            ),
          ],
        ),
      ),
    ),
  );
}

}

class StressReadingsPage extends StatelessWidget {
  final List<Map<String, dynamic>> readings;

  const StressReadingsPage({Key? key, required this.readings}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stress Readings'),
        backgroundColor: const Color.fromARGB(255, 184, 5, 5),
      ),
      body: ListView.builder(
        itemCount: readings.length,
        itemBuilder: (context, index) {
          var reading = readings[index];
          return Card(
            margin: const EdgeInsets.all(8.0),
            child: ListTile(
              title: Text("STRESS DETECTED"),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Timestamp: ${reading['timestamp']}"),
                  Text("SpO2: ${reading['SpO2']}"),
                  Text("Heart Rate: ${reading['heartRate']}"),
                  Text("Body Temp: ${reading['bodyTemperature']}"),
                  Text("Humidity: ${reading['humidity']}"),
                  Text("Environment Temp: ${reading['temperature']}"),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
class SensorChartPage extends StatelessWidget {
  final String sensorType;

  const SensorChartPage({Key? key, required this.sensorType}) : super(key: key);

  Future<List<double>> fetchSensorData() async {
    QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection('sensorData')
        .orderBy(FieldPath.documentId, descending: true)
        .limit(10)
        .get();

    return querySnapshot.docs.map((doc) {
      var data = doc.data() as Map<String, dynamic>;
      return (data[sensorType] as num?)?.toDouble() ?? 0.0;
    }).cast<double>().toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF22223B), // Set page background to 22223B
      appBar: AppBar(
        title: Text('$sensorType Chart'),
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        elevation: 0,
      ),
      body: FutureBuilder<List<double>>(
        future: fetchSensorData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No data found'));
          } else {
            var readings = snapshot.data!;
            return Center(
              child: Container(
                margin: const EdgeInsets.all(16.0),
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white, // White background for the chart container
                  borderRadius: BorderRadius.circular(20.0), // Rounded edges
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 3,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: buildLineChart(readings), // Display the chart within this container
              ),
            );
          }
        },
      ),
    );
  }

  Widget buildLineChart(List<double> readings) {
  return LineChart(
    LineChartData(
      gridData: FlGridData(show: true),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1, // Show every X-axis value
            reservedSize: 22,
            getTitlesWidget: (value, meta) {
              return SideTitleWidget(
                axisSide: meta.axisSide,
                space: 6.0,
                child: Text(value.toInt().toString()), // Display integer X-axis labels
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 35,
          ),
        ),
        topTitles: AxisTitles( // Hide top X-axis titles
          sideTitles: SideTitles(showTitles: false),
        ),
        rightTitles: AxisTitles( // Hide right Y-axis titles
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      borderData: FlBorderData(show: true),
      minX: 0,
      maxX: readings.length.toDouble() - 1,
      minY: readings.reduce((a, b) => a < b ? a : b) - 10,
      maxY: readings.reduce((a, b) => a > b ? a : b) + 10,
      lineBarsData: [
        LineChartBarData(
          spots: readings.asMap().entries.map((entry) {
            int index = entry.key;
            double value = entry.value;
            return FlSpot(index.toDouble(), value);
          }).toList(),
          isCurved: true,
          color: Colors.blue,
          dotData: FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
      ],
    ),
  );
}
}