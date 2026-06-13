import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';

class TemperatureChart extends StatelessWidget {
  final List<dynamic> rawTemps;

  const TemperatureChart({super.key, required this.rawTemps});

  @override
  Widget build(BuildContext context) {
    // Safely convert Firestore array to List<double>
    List<double> temps = rawTemps.map((e) => (e as num).toDouble()).toList();

    // If no data yet, show a placeholder flat line
    if (temps.isEmpty) {
      temps = [0];
    }

    // Keep only the last 24 hours to keep the chart readable on mobile
    if (temps.length > 24) {
      temps = temps.sublist(temps.length - 24);
    }

    // Prepare chart spots
    List<FlSpot> spots = [];
    double minTemp = temps.isNotEmpty ? temps.reduce(min) : 0;
    double maxTemp = temps.isNotEmpty ? temps.reduce(max) : 40;

    for (int i = 0; i < temps.length; i++) {
      spots.add(FlSpot(i.toDouble(), temps[i]));
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "24H Temperature Trend",
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[800]),
              ),
              Icon(Icons.show_chart, color: Colors.orange[700], size: 20),
            ],
          ),
          const SizedBox(height: 24),
          AspectRatio(
            aspectRatio: 2.0, // Wide and short
            child: LineChart(
              LineChartData(
                minY: (minTemp - 2).clamp(0, 100).toDouble(), // Give some padding at the bottom
                maxY: (maxTemp + 2).toDouble(), // Give some padding at the top
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 5,
                  getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), // Hide X axis numbers
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          "${value.toInt()}°",
                          style: GoogleFonts.inter(fontSize: 10, color: Colors.grey[500]),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Colors.orange[600],
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: false), // Hide dots to make it look cleaner
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.orange.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}