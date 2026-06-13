import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/services/local_db_service.dart';
import 'package:flutter_application_1/services/notification_service.dart';

// Pages
import 'package:flutter_application_1/pages/analytics_page.dart'; 
import 'package:flutter_application_1/pages/status_page.dart';    
import 'package:flutter_application_1/pages/reports_page.dart';
import 'package:flutter_application_1/pages/about_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0; // 0 is now Dashboard/Home
  StreamSubscription? _syncSubscription; // Controls the background listener
  StreamSubscription? _alertSubscription; 

  // Color from your Figma Design (Yellow)
  final Color activeYellow = const Color(0xFFE2CA19);
  
  // NEW: Track flags to prevent notification spam
  bool _hasSentThermalAlert = false;
  bool _hasSentFailsafeAlert = false;

  @override
  void initState() {
    super.initState();
    _startAutoSync();
    _startAlertMonitor(); 
  }

  // --- NEW: GLOBAL ALERT MONITOR ---
  void _startAlertMonitor() {
    _alertSubscription = FirebaseFirestore.instance
        .collection('current_batch')
        .doc('bionana_machine_01')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data() as Map<String, dynamic>;
        final temp = (data['currentTemp'] ?? 0.0).toDouble();
        final status = data['status'] ?? 'Idle';

        // 1. THERMAL WARNING (> 35C)
        if (temp >= 35.0 && !_hasSentThermalAlert && status == 'Fermenting') {
          NotificationService.instance.showUrgentAlert(
            id: 801,
            title: "CRITICAL: High Temperature 🔥",
            body: "Internal tank reached ${temp.toStringAsFixed(1)}C! Cooling system may have failed.",
          );
          _hasSentThermalAlert = true; // Prevent spamming
        } else if (temp < 33.0) {
          _hasSentThermalAlert = false; // Reset if temp drops back down
        }

        // 2. HARDWARE FAILSAFE ALERT (100% Sensor triggered)
        // Note: Make sure your ESP32 sets status to 'Error_Overfill' if this happens
        if (status == 'Error_Overfill' && !_hasSentFailsafeAlert) {
          NotificationService.instance.showUrgentAlert(
            id: 802,
            title: "EMERGENCY: Tank Overfill 🛑",
            body: "The 100% capacity sensor was triggered. Valves have been shut.",
          );
          _hasSentFailsafeAlert = true;
        }

        // Reset failsafe flag if system returns to Idle
        if (status == 'Idle') {
          _hasSentFailsafeAlert = false;
        }
      }
    });
  }

  // --- AUTO-SYNC LOGIC ---
  void _startAutoSync() {
    _syncSubscription = FirebaseFirestore.instance
        .collection('batches')
        .snapshots()
        .listen((snapshot) {
      
      for (var change in snapshot.docChanges) {
        final data = change.doc.data();
        final docId = change.doc.id;

        if (change.type == DocumentChangeType.added || 
            change.type == DocumentChangeType.modified) {
          if (data != null) {
            LocalDbService.instance.saveBatchToLocal(data, docId);
          }
        } else if (change.type == DocumentChangeType.removed) {
          LocalDbService.instance.deleteBatch(docId);
        }
      }
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    _alertSubscription?.cancel();
    super.dispose();
  }

  // Function to switch tabs programmatically 
  // (This allows the Dashboard 'Start' button to jump to Controls)
  void _switchTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // We define the pages list inside build (or use a getter) so we can pass _switchTab
    final List<Widget> pages = [
      AnalyticsPage(onNavigateToControls: () => _switchTab(1)), // Index 0: Home/Dashboard
      StatusPage(),                                             // Index 1: Controls/Status
      ReportsPage(),                                            // Index 2: History
      AboutPage(),                                              // Index 3: About
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed, 
        selectedItemColor: activeYellow, // Changed to Figma Yellow
        unselectedItemColor: Colors.grey,
        showSelectedLabels: false, // Hiding labels for cleaner Figma look
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_filled, size: 28),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.tune, size: 28), // 'Tune' icon looks like controls sliders
            label: 'Controls',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history, size: 28),
            label: 'History', 
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.info_outline, size: 28),
            label: 'About',
          ),
        ],
      ),
    );
  }
}