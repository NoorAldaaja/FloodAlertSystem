// location_safety_page.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocationSafetyPage extends StatefulWidget {
  const LocationSafetyPage({Key? key}) : super(key: key);

  @override
  State<LocationSafetyPage> createState() => _LocationSafetyPageState();
}

class _LocationSafetyPageState extends State<LocationSafetyPage> {
  // 🔥 هون رح تجيب البيانات من Firebase
  final DatabaseReference dangerRef = FirebaseDatabase.instance.ref(
    'DangerZones',
  );

  Position? _currentPosition;
  String _status = 'Checking...';
  double? _distance;
  String _zoneName = '';
  bool _notificationShown = false;
  bool _isLoading = true;

  // ===== Notifications =====
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _getLocationAndCheck();
  }

  void _initNotifications() {
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);
    flutterLocalNotificationsPlugin.initialize(initSettings);
  }

  void _showNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'danger_zone_channel',
      'Danger Zone Alerts',
      channelDescription: 'Alerts when entering danger zones',
      importance: Importance.max,
      priority: Priority.high,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);
    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      notificationDetails,
    );
  }

  Future<void> _getLocationAndCheck() async {
    setState(() => _isLoading = true);

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _status = 'GPS Disabled';
        _isLoading = false;
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _status = 'Permission Denied';
          _isLoading = false;
        });
        return;
      }
    }

    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() => _isLoading = false);
      _checkDangerZones();
    } catch (e) {
      setState(() {
        _status = 'Error getting location';
        _isLoading = false;
      });
    }
  }

  // 🔥 هون الـ function اللي بتفحص المناطق الخطرة من Firebase
  void _checkDangerZones() {
    dangerRef.onValue.listen((event) {
      // 🔥 البيانات من Firebase - استبدلها ببياناتك
      final data = event.snapshot.value as Map?;
      if (data == null || _currentPosition == null) return;

      bool inside = false;
      double closestDistance = double.infinity;
      String closestZone = '';

      data.forEach((key, value) {
        // 🔥 قراءة البيانات من Firebase
        final double lat = value['lat'];
        final double lng = value['lng'];
        final double radius = value['radius'];
        final String name = value['name'];

        final double distance = _calculateDistance(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          lat,
          lng,
        );

        if (distance <= radius) {
          inside = true;
          if (distance < closestDistance) {
            closestDistance = distance;
            _zoneName = name;
            _distance = distance;
          }
        }
      });

      setState(() {
        _status = inside ? 'Inside Danger Zone' : 'Safe';
      });

      if (inside && !_notificationShown) {
        _notificationShown = true;
        _showNotification('⚠️ Danger Zone', 'You are inside $_zoneName');
      } else if (!inside) {
        _notificationShown = false;
      }
    });
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _degToRad(double deg) => deg * pi / 180;

  Color _getStatusColor() {
    if (_status == 'Safe') return Colors.green;
    if (_status == 'Inside Danger Zone') return Colors.red;
    return Colors.orange;
  }

  IconData _getStatusIcon() {
    if (_status == 'Safe') return Icons.check_circle;
    if (_status == 'Inside Danger Zone') return Icons.warning;
    return Icons.info;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
          ),
        ),
        child: Stack(
          children: [
            // Starry background
            ...List.generate(50, (index) {
              return Positioned(
                left: (index * 37) % MediaQuery.of(context).size.width,
                top: (index * 53) % MediaQuery.of(context).size.height,
                child: Container(
                  width: 2,
                  height: 2,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),

            SafeArea(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Colors.blue),
                          const SizedBox(height: 20),
                          Text(
                            'Getting your location...',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),

                            // Title
                            Center(
                              child: Column(
                                children: [
                                  Text(
                                    'Location & Safety',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w300,
                                      color: Colors.white,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    width: 60,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.blue.withValues(alpha: 0.3),
                                          Colors.blue,
                                          Colors.blue.withValues(alpha: 0.3),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 40),

                            // Status Card (Big)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(30),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    _getStatusColor().withValues(alpha: 0.3),
                                    _getStatusColor().withValues(alpha: 0.1),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: _getStatusColor().withValues(
                                    alpha: 0.5,
                                  ),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _getStatusColor().withValues(
                                      alpha: 0.3,
                                    ),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    _getStatusIcon(),
                                    size: 80,
                                    color: _getStatusColor(),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    _status,
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: _getStatusColor(),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    _status == 'Safe'
                                        ? 'You are in a safe area'
                                        : _status == 'Inside Danger Zone'
                                        ? 'Please evacuate immediately'
                                        : 'Checking your location',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 30),

                            // Location Details Section
                            Text(
                              'Location Details',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Your Location Card
                            _buildInfoCard(
                              icon: Icons.my_location,
                              title: 'Your Location',
                              value: _currentPosition == null
                                  ? 'Unknown'
                                  : '${_currentPosition!.latitude.toStringAsFixed(5)}, ${_currentPosition!.longitude.toStringAsFixed(5)}',
                              gradient: [Color(0xFF4E54C8), Color(0xFF8F94FB)],
                            ),

                            const SizedBox(height: 12),

                            // GPS Accuracy
                            _buildInfoCard(
                              icon: Icons.gps_fixed,
                              title: 'GPS Accuracy',
                              value: _currentPosition == null
                                  ? 'N/A'
                                  : '${_currentPosition!.accuracy.toStringAsFixed(1)} m',
                              gradient: [Color(0xFF56CCF2), Color(0xFF2F80ED)],
                            ),

                            // Danger Zone Info (if inside)
                            if (_status == 'Inside Danger Zone') ...[
                              const SizedBox(height: 30),
                              Text(
                                'Danger Zone Info',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                              const SizedBox(height: 16),

                              _buildInfoCard(
                                icon: Icons.place,
                                title: 'Zone Name',
                                value: _zoneName,
                                gradient: [
                                  Color(0xFFFF6B6B),
                                  Color(0xFFFF8E53),
                                ],
                              ),

                              const SizedBox(height: 12),

                              _buildInfoCard(
                                icon: Icons.straighten,
                                title: 'Distance to Center',
                                value: _distance == null
                                    ? 'N/A'
                                    : '${_distance!.toStringAsFixed(1)} m',
                                gradient: [
                                  Color(0xFFFFA726),
                                  Color(0xFFFB8C00),
                                ],
                              ),
                            ],

                            const SizedBox(height: 30),

                            // Refresh Button
                            Center(
                              child: ElevatedButton.icon(
                                onPressed: _getLocationAndCheck,
                                icon: Icon(Icons.refresh, color: Colors.white),
                                label: Text(
                                  'Refresh Location',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required List<Color> gradient,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient.map((c) => c.withValues(alpha: 0.3)).toList(),
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: gradient[0].withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: gradient[0], size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
