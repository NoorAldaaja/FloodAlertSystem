// weather_details_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class WeatherDetailsPage extends StatefulWidget {
  const WeatherDetailsPage({super.key});

  @override
  State<WeatherDetailsPage> createState() => _WeatherDetailsPageState();
}

class _WeatherDetailsPageState extends State<WeatherDetailsPage> {
  // ===== Firebase =====
  late DatabaseReference sensorRef;

  // ===== ESP32 Sensor Data =====
  int rainAnalog = 0;
  int rainDigital = 0;
  String rainStatus = '---';
  double waterDistance = 0.0;
  String waterLevel = 'LOW';

  // ===== Temporary Weather API Mock Data =====
  final Map<String, dynamic> weatherData = {
    'temperature': 21,
    'humidity': 31,
    'rainIntensity': 0,
    'windSpeed': 9,
    'windDirection': 'ESE',
  };

  // ===== Notifications =====
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  @override
  void initState() {
    super.initState();
    sensorRef = FirebaseDatabase.instance.ref('SensorData');
    _listenToSensorData();
    _initNotifications();
  }

  void _initNotifications() {
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    flutterLocalNotificationsPlugin.initialize(initSettings);
  }

  void _showNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'water_level_channel',
      'Water Level Alerts',
      channelDescription: 'Alerts when water level is high',
      importance: Importance.max,
      priority: Priority.high,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);
    await flutterLocalNotificationsPlugin.show(0, title, body, notificationDetails);
  }

  // ===== FIREBASE LISTENER =====
  void _listenToSensorData() {
    sensorRef.onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data == null) return;

      setState(() {
        rainAnalog = data['rainAnalog'] ?? 0;
        rainDigital = data['rainDigital'] ?? 0;
        rainStatus = data['rainStatus'] ?? '---';
        waterDistance = (data['waterDistance'] as num).toDouble();
        waterLevel = data['waterLevel'] ?? 'LOW';
      });

      // إشعار عند مستوى مياه عالي
      if (waterLevel.toUpperCase() == 'HIGH') {
        _showNotification('⚠️ Warning', 'Water level is HIGH! Be careful.');
      }
    });
  }

  // ===== Water Level Color Logic =====
  Color _getWaterLevelColor(String level) {
    switch (level.toUpperCase()) {
      case 'HIGH':
        return Colors.red;
      case 'MEDIUM':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color waterLevelColor = _getWaterLevelColor(waterLevel);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Center(
                  child: Column(
                    children: [
                      const Text(
                        'Weather Details',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w300,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 60,
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                _buildSectionTitle('Current Weather'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildWeatherCard(
                        icon: Icons.thermostat,
                        label: 'Temperature',
                        value: '${weatherData['temperature']}°C',
                        gradient: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildWeatherCard(
                        icon: Icons.water_drop,
                        label: 'Humidity',
                        value: '${weatherData['humidity']}%',
                        gradient: [Color(0xFF4E54C8), Color(0xFF8F94FB)],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                _buildWeatherCard(
                  icon: Icons.warning,
                  label: 'Water Level',
                  value: waterLevel,
                  gradient: [waterLevelColor, waterLevelColor],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===== UI HELPERS =====
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.white.withValues(alpha:0.9),
      ),
    );
  }

  Widget _buildWeatherCard({
    required IconData icon,
    required String label,
    required String value,
    required List<Color> gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient.map((c) => c.withValues(alpha:0.3)).toList(),
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha:0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 32),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha:0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
