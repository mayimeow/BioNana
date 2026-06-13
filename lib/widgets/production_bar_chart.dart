import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/local_db_service.dart';
import 'package:google_fonts/google_fonts.dart';

class ProductionBarChart extends StatefulWidget {
  const ProductionBarChart({super.key});

  @override
  State<ProductionBarChart> createState() => _ProductionBarChartState();
}

class _ProductionBarChartState extends State<ProductionBarChart> {
  List<BarChartGroupData> _barGroups = [];
  List<String> _bottomLabels = [];
  bool _isLoading = true;
  double _maxY = 1000;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // 1. Get Data
      var batches = await LocalDbService.instance.getLocalBatches();
      
      // 2. Filter for 'Complete' only
      var completeBatches = batches.where((b) => b['status'] == 'Complete').toList();

      // 3. If we have more than 10, take the last 10
      if (completeBatches.length > 10) {
        completeBatches = completeBatches.sublist(0, 10); // Take first 10 since it comes sorted DESC
      }
      
      // Reverse so chart goes Left (Old) -> Right (New)
      completeBatches = completeBatches.reversed.toList();

      List<BarChartGroupData> tempGroups = [];
      List<String> tempLabels = [];
      double maxVol = 0;

      if (completeBatches.isEmpty) {
        // Empty State
        tempGroups = [
          _makeBarData(0, 0),
          _makeBarData(1, 0),
          _makeBarData(2, 0),
        ];
        tempLabels = ["1", "2", "3"];
        maxVol = 1000;
      } else {
        for (int i = 0; i < completeBatches.length; i++) {
          final batch = completeBatches[i];
          
          double vol = (batch['totalVolume'] as num?)?.toDouble() ?? 0.0;
          if (vol > maxVol) maxVol = vol;

          tempGroups.add(_makeBarData(i, vol));
          tempLabels.add("#${i + 1}"); 
        }
      }

      if (maxVol == 0) maxVol = 1000;

      if (mounted) {
        setState(() {
          _barGroups = tempGroups;
          _bottomLabels = tempLabels;
          // Increased headroom to 1.3 so the floating text labels don't get cut off
          _maxY = maxVol * 1.3; 
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("CHART CRASHED: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _barGroups = [_makeBarData(0, 0)]; // Show flat line on error
        });
      }
    }
  }

  // Helper to generate the Bar Rod Data with permanent labels
  BarChartGroupData _makeBarData(int x, double y) {
    return BarChartGroupData(
      x: x,
      showingTooltipIndicators: [0], // <-- This forces the label to ALWAYS show
      barRods: [
        BarChartRodData(
          toY: y,
          color: Colors.green[800],
          width: 16, // Thickness of the bars
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(4),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.only(top: 24.0, left: 16.0, right: 16.0, bottom: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("", style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                Text("ml / batch", style: GoogleFonts.inter(fontSize: 12, color: Colors.green[700], fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 24),
            AspectRatio(
              aspectRatio: 1.7,
              child: BarChart(
                BarChartData(
                  minY: 0,
                  maxY: _maxY,
                  
                  // --- CONFIGURING THE PERMANENT LABELS ---
                  barTouchData: BarTouchData(
                    enabled: false, // Disable touch so they act as static text
                    touchTooltipData: BarTouchTooltipData(
                      tooltipBgColor: Colors.transparent, // Fixed for fl_chart v0.66.0
                      tooltipPadding: EdgeInsets.zero,
                      tooltipMargin: 4, // Gap between bar top and text
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        String shortText;
                        if (rod.toY >= 1000) {
                          shortText = "${(rod.toY / 1000).toStringAsFixed(1)}L"; // e.g., "9.6L"
                        } else {
                          shortText = "${rod.toY.toInt()}"; // e.g., "527"
                        }

                        return BarTooltipItem(
                          shortText, // <--- ADDED THE 'ml' UNIT HERE
                          GoogleFonts.inter(
                            color: Colors.green[800],
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                  // ----------------------------------------------

                  gridData: FlGridData(
                    show: true, 
                    drawVerticalLine: false, 
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), 
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          int index = value.toInt();
                          if (index >= 0 && index < _bottomLabels.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                _bottomLabels[index],
                                style: GoogleFonts.inter(fontSize: 10, color: Colors.grey),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: _barGroups, 
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}