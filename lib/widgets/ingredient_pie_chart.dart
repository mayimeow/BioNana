import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/local_db_service.dart';
import 'package:google_fonts/google_fonts.dart';

class IngredientPieChart extends StatefulWidget {
  const IngredientPieChart({super.key});

  @override
  State<IngredientPieChart> createState() => _IngredientPieChartState();
}

class _IngredientPieChartState extends State<IngredientPieChart> {
  double _totalSap = 0;
  double _totalWater = 0;
  double _totalMolasses = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final batches = await LocalDbService.instance.getLocalBatches();
    
    double s = 0;
    double w = 0;
    double m = 0;

    for (var batch in batches) {
      s += (batch['sapVolume'] ?? 0.0);
      w += (batch['waterVolume'] ?? 0.0);
      m += (batch['molassesVolume'] ?? 0.0);
    }

    if (mounted) {
      setState(() {
        _totalSap = s;
        _totalWater = w;
        _totalMolasses = m;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SizedBox();
    
    double total = _totalSap + _totalWater + _totalMolasses;
    // (UPDATED) Check if empty
    bool isEmpty = total == 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Text("", 
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[700])),
             const SizedBox(height: 20),
             SizedBox(
               height: 200,
               child: PieChart(
                 PieChartData(
                   sectionsSpace: 2,
                   centerSpaceRadius: 40,
                   sections: isEmpty 
                   ? [
                      // Placeholder Section if empty
                      PieChartSectionData(
                        value: 1,
                        color: Colors.grey[200],
                        title: 'No Data',
                        radius: 50,
                        titleStyle: GoogleFonts.inter(color: Colors.grey[500], fontWeight: FontWeight.bold),
                      )
                   ]
                   : [
                     PieChartSectionData(
                       value: _totalSap,
                       color: Colors.green[700],
                       title: '${((_totalSap/total)*100).toStringAsFixed(0)}%',
                       radius: 50,
                       titleStyle: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
                     ),
                     PieChartSectionData(
                       value: _totalWater,
                       color: Colors.blue[400],
                       title: '${((_totalWater/total)*100).toStringAsFixed(0)}%',
                       radius: 50,
                       titleStyle: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
                     ),
                     PieChartSectionData(
                       value: _totalMolasses,
                       color: Colors.brown[400],
                       title: 'M', 
                       radius: 50,
                       titleStyle: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
                     ),
                   ],
                 ),
               ),
             ),
             const SizedBox(height: 16),
             if (!isEmpty) _buildLegend(),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _legendItem("Sap", Colors.green[700]!),
        _legendItem("Water", Colors.blue[400]!),
        _legendItem("Molasses", Colors.brown[400]!),
      ],
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.inter(fontSize: 12)),
      ],
    );
  }
}