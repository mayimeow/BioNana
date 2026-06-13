import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application_1/services/local_db_service.dart';
// Widgets
import 'package:flutter_application_1/widgets/production_bar_chart.dart'; // UPDATED IMPORT
import 'package:flutter_application_1/widgets/ingredient_pie_chart.dart';

class AnalyticsPage extends StatefulWidget {
  final VoidCallback? onNavigateToControls;

  const AnalyticsPage({super.key, this.onNavigateToControls});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  // Brand Colors
  final Color bioGreen = const Color(0xFF266533);
  final Color nanaYellow = const Color(0xFFDCC115);

  Future<Map<String, dynamic>> _getLocalOverallStats() async {
    final batches = await LocalDbService.instance.getLocalBatches();
    int count = 0;
    double totalVolume = 0.0;
    for (var batch in batches) {
      if (batch['status'] == 'Complete') {
        count++;
        totalVolume += (batch['totalVolume'] ?? 0.0);
      }
    }
    return {'count': count, 'volume': totalVolume};
  }

  @override
  Widget build(BuildContext context) {
    final String todayDate = DateFormat('EEE, dd MMM').format(DateTime.now());

    return Scaffold(
      backgroundColor: Colors.white, 
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          children: [
            // --- 1. HEADER ---
            Row(
              children: [
                Image.asset('assets/images/logo.png', height: 32),
                const SizedBox(width: 8),
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.geologica(
                      fontSize: 22, // Standardized size
                      fontWeight: FontWeight.bold,
                    ),
                    children: [
                      TextSpan(text: "Bio", style: TextStyle(color: bioGreen)),
                      TextSpan(text: "Nana", style: TextStyle(color: nanaYellow)),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // --- 2. DATE HEADER ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Today", style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500)),
                Text(todayDate, style: GoogleFonts.inter(fontSize: 14, color: Colors.grey)),
              ],
            ),

            const SizedBox(height: 12),

            // --- 3. ACTIVE BATCH CARD ---
            StreamBuilder<DocumentSnapshot>(
              // Fixed: Listening to the correct machine document
              stream: FirebaseFirestore.instance.collection('current_batch').doc('bionana_machine_01').snapshots(),
              builder: (context, snapshot) {
                
                String title = "No Active Batch";
                String actionText = "start >";
                Widget? subWidget; 

                if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>?;
                  
                  if (data != null) {
                    String status = data['status'] ?? "Idle";
                    
                    if (status == "Idle" || status == "Complete") {
                      title = "No Active Batch";
                      actionText = "start >";
                    } else if (status == "Fermenting") {
                      actionText = "monitor >";
                      
                      // Calculate Days
                      Timestamp? fermStart = data['fermentationStartTime'];
                      int dayNum = 1;
                      if (fermStart != null) {
                        final start = fermStart.toDate();
                        final diff = DateTime.now().difference(start);
                        dayNum = diff.inDays + 1;
                        if (dayNum > 7) dayNum = 7; 
                      }

                      title = "Fermenting:";
                      // Fixed: Used FittedBox to ensure it fits on one line
                      subWidget = FittedBox(
                        alignment: Alignment.centerLeft,
                        fit: BoxFit.scaleDown,
                        child: Text(
                          "$dayNum out of 7 days",
                          style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
                        ),
                      );
                    } else {
                      // Initialization Phase
                      title = "Batch Initialization";
                      actionText = "monitor >";
                    }
                  }
                }

                return Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      )
                    ],
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title (small green label if active, big grey if idle)
                          Text(
                            title,
                            style: GoogleFonts.inter(
                              fontSize: subWidget == null ? 24 : 16, 
                              fontWeight: subWidget == null ? FontWeight.bold : FontWeight.w600,
                              color: subWidget == null ? Colors.grey[400] : bioGreen,
                            ),
                          ),
                          
                          // SubWidget (The big black text)
                          if (subWidget != null) ...[
                            const SizedBox(height: 4),
                            subWidget,
                          ],
                          
                          const SizedBox(height: 16),
                          
                          // Animated Action Button
                          InkWell(
                            onTap: widget.onNavigateToControls,
                            borderRadius: BorderRadius.circular(8),
                            splashColor: nanaYellow.withValues(alpha: 0.2), // Yellow Ripple
                            highlightColor: nanaYellow.withValues(alpha: 0.1),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min, // Hug content
                                children: [
                                  Text(
                                    actionText,
                                    style: GoogleFonts.inter(fontSize: 16, color: Colors.black87),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // --- 4. OVERALL PERFORMANCE ---
            FutureBuilder<Map<String, dynamic>>(
              future: _getLocalOverallStats(),
              builder: (context, snapshot) {
                int count = 0;
                double volume = 0.0;
                if (snapshot.hasData) {
                  count = snapshot.data!['count'];
                  volume = snapshot.data!['volume'];
                }

                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        "OVERALL PERFORMANCE",
                        style: GoogleFonts.inter(
                          fontSize: 10, fontWeight: FontWeight.bold, color: bioGreen, letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _statItem(count.toString(), "Completed Batches"),
                          _statItem("${(volume / 1000).toStringAsFixed(0)}L", "Total Produced"), 
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // --- 5. CHARTS ---
            Text("Batch Yield Volume", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: bioGreen)), // UPDATED TITLE
            const SizedBox(height: 8),
            const ProductionBarChart(), // UPDATED WIDGET

            const SizedBox(height: 24),
            Text("Total Ingredient Usage", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: bioGreen)),
            const SizedBox(height: 8),
            const IngredientPieChart(),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.bold, color: const Color(0xFF14532D)), 
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF14532D)),
        ),
      ],
    );
  }
}