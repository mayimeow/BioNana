import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application_1/services/local_db_service.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  // State for Filter and Sort
  String _selectedStatus = 'Complete'; // Matches Firestore 'status' value
  String _sortOrder = 'completedAt_desc';

  // --- BRAND COLORS ---
  final Color bioGreen = const Color(0xFF266533);
  final Color nanaYellow = const Color(0xFFDCC115);
  final Color redAccent = const Color(0xFFFF3B30); // Bright UI Red
  
  // Card Backgrounds
  final Color greenCardBg = const Color(0xFFE0FADF); // Light Green for active card
  final Color redCardBg = const Color(0xFFFFE5E5);   // Light Red for cancelled card (optional)

  // --- HELPER: Sort Logic ---
  List<DocumentSnapshot> _sortDocs(List<DocumentSnapshot> docs) {
    docs.sort((a, b) {
      Map<String, dynamic> dataA = a.data() as Map<String, dynamic>;
      Map<String, dynamic> dataB = b.data() as Map<String, dynamic>;
      
      dynamic valA, valB;
      // Sort by Date
      if (_sortOrder.contains('completedAt')) {
        // Fallback to startTime if completedAt is missing
        valA = dataA['completedAt'] ?? dataA['startTime'] ?? Timestamp.now();
        valB = dataB['completedAt'] ?? dataB['startTime'] ?? Timestamp.now();
      } 
      
      int comparison;
      if (valA is Timestamp && valB is Timestamp) {
        comparison = valA.compareTo(valB);
      } else {
        comparison = 0;
      }

      // Reverse if descending (Newest First)
      if (_sortOrder.endsWith('_desc')) {
        return -comparison;
      }
      return comparison;
    });
    return docs;
  }

  // --- UPDATED HELPER: Archive instead of permanent delete ---
  Future<void> _archiveBatch(DocumentSnapshot doc) async {
    try {
      final data = doc.data() as Map<String, dynamic>;
      // Add archiving timestamp
      data['archivedAt'] = FieldValue.serverTimestamp();

      // 1. Move to archived_batches collection
      await FirebaseFirestore.instance.collection('archived_batches').doc(doc.id).set(data);
      
      // 2. Remove from active batches
      await FirebaseFirestore.instance.collection('batches').doc(doc.id).delete();
      
      // 3. Remove from local DB
      await LocalDbService.instance.deleteBatch(doc.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Batch moved to Archive (15 days remaining)."), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      debugPrint("Error archiving: $e");
    }
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return "Unknown";
    return DateFormat('MMMM d, yyyy - h:mm a').format(timestamp.toDate());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9), // Very light grey background
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          // Fetch ALL batches to calculate totals dynamically
          stream: FirebaseFirestore.instance.collection('batches').snapshots(),
          builder: (context, snapshot) {
            
            // 1. Data Processing
            int completedCount = 0;
            int cancelledCount = 0;
            List<DocumentSnapshot> filteredList = [];

            if (snapshot.hasData) {
              for (var doc in snapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final status = data['status'] ?? 'Unknown';

                // Count Totals
                if (status == 'Complete') completedCount++;
                if (status == 'Canceled') cancelledCount++; // Note: Check DB spelling "Canceled" vs "Cancelled"

                // Filter for ListView
                if (status == _selectedStatus) {
                  filteredList.add(doc);
                }
              }
              // Apply Sort
              filteredList = _sortDocs(filteredList);
            }

            return Column(
              children: [
                // --- HEADER & CONTROLS SECTION ---
                Container(
                  padding: const EdgeInsets.all(24),
                  color: Colors.transparent,
                  child: Column(
                    children: [
                      // 1. Logo Row
                      Row(
                        children: [
                          Image.asset('assets/images/logo.png', height: 32),
                          const SizedBox(width: 8),
                          RichText(
                            text: TextSpan(
                              style: GoogleFonts.geologica(fontSize: 22, fontWeight: FontWeight.bold),
                              children: [
                                TextSpan(text: "Bio", style: TextStyle(color: bioGreen)),
                                TextSpan(text: "Nana", style: TextStyle(color: nanaYellow)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      // 2. Title
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text("Batch History", 
                          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: bioGreen)
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 3. Summary Cards (The Counts)
                      Row(
                        children: [
                          // Completed Card
                          Expanded(
                            child: _buildSummaryCard(
                              "Completed", 
                              completedCount, 
                              isGreen: true
                            )
                          ),
                          const SizedBox(width: 16),
                          // Cancelled Card
                          Expanded(
                            child: _buildSummaryCard(
                              "Cancelled", 
                              cancelledCount, 
                              isGreen: false
                            )
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // 4. Custom Toggle Buttons
                      Row(
                        children: [
                          Expanded(
                            child: _buildToggleButton("Completed", true)
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildToggleButton("Cancelled", false)
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),

                      // 5. Sort Dropdown
                      Align(
                        alignment: Alignment.centerRight,
                        child: _buildSortDropdown(),
                      ),
                      const Divider(height: 1),
                    ],
                  ),
                ),

                // --- SCROLLABLE LIST SECTION ---
                Expanded(
                  child: filteredList.isEmpty 
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history, size: 48, color: Colors.grey[300]),
                          const SizedBox(height: 8),
                          Text("No ${_selectedStatus.toLowerCase()} batches found", 
                            style: GoogleFonts.inter(color: Colors.grey[400])
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                      itemCount: filteredList.length,
                      itemBuilder: (context, index) {
                        return _buildBatchCard(filteredList[index]);
                      },
                    ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildSummaryCard(String title, int count, {required bool isGreen}) {
    // Style logic
    final bgColor = isGreen ? greenCardBg : Colors.white; 
    final textColor = isGreen ? bioGreen : redAccent;
    
    // Manual Shadow color to avoid deprecation warnings: Black with 5% opacity
    final shadowColor = const Color.fromRGBO(0, 0, 0, 0.05);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
        border: isGreen ? null : Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Text(title, 
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: textColor)
          ),
          const SizedBox(height: 8),
          Text(count.toString(), 
            style: GoogleFonts.inter(fontSize: 36, fontWeight: FontWeight.bold, color: textColor)
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String label, bool isGreenType) {
    bool isActive = false;
    Color activeColor = Colors.grey;

    if (isGreenType) {
      isActive = _selectedStatus == 'Complete';
      activeColor = bioGreen;
    } else {
      isActive = _selectedStatus == 'Canceled';
      activeColor = redAccent;
    }

    return SizedBox(
      height: 44,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive ? activeColor : Colors.white,
          foregroundColor: isActive ? Colors.white : Colors.black87,
          elevation: 0,
          // Reduced horizontal padding to prevent text overflow
          padding: const EdgeInsets.symmetric(horizontal: 4), 
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
            side: isActive ? BorderSide.none : BorderSide(color: Colors.grey.shade200),
          ),
        ),
        onPressed: () {
          setState(() {
            _selectedStatus = isGreenType ? 'Complete' : 'Canceled';
          });
        },
        // FittedBox ensures text scales down instead of cropping if screen is narrow
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label, 
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 14, // Explicit size
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSortDropdown() {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: _sortOrder,
        icon: const Icon(Icons.arrow_drop_down, size: 20),
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700]),
        items: const [
          DropdownMenuItem(value: 'completedAt_desc', child: Text("Sort by: Date (Newest)")),
          DropdownMenuItem(value: 'completedAt_asc', child: Text("Sort by: Date (Oldest)")),
        ],
        onChanged: (val) {
          if (val != null) setState(() => _sortOrder = val);
        },
      ),
    );
  }

  // --- UPDATED BATCH CARD TO SHOW CANCEL REASON ---
  Widget _buildBatchCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final batchName = data['batchName'] ?? 'Batch #';
    final totalVol = (data['totalVolume'] ?? 0).toStringAsFixed(2);
    
    // FETCH THE REASON
    final cancelReason = data['cancelReason'] as String?;
    
    final fermStart = data['fermentationStartTime'] as Timestamp?;
    final completedOn = data['completedAt'] as Timestamp?;
    
    final fermLabel = fermStart != null ? _formatDate(fermStart) : "N/A";
    final completedLabel = completedOn != null ? _formatDate(completedOn) : "N/A";

    final isComplete = _selectedStatus == 'Complete';
    final accentColor = isComplete ? bioGreen : redAccent;
    final statusLabel = isComplete ? "Completed On:" : "Cancelled On:";
    
    // Manual Shadow: Black with 3% opacity
    final shadowColor = const Color.fromRGBO(0, 0, 0, 0.03);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 5,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(batchName, 
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: accentColor)
          ),
          const SizedBox(height: 12),
          
          // Data Rows
          _buildDetailRow("Total Volume:", "$totalVol ml"),
          const SizedBox(height: 6),
          _buildDetailRow("Fermentation Started:", fermLabel),
          const SizedBox(height: 6),
          _buildDetailRow(statusLabel, completedLabel),
          
          // --- SHOW REASON IF CANCELLED ---
          if (!isComplete && cancelReason != null && cancelReason.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: redAccent.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: redAccent.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Cancellation Reason", 
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: redAccent)
                  ),
                  const SizedBox(height: 4),
                  Text(cancelReason, 
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.black87)
                  ),
                ],
              ),
            ),
          ],

          // Archive Button (Formerly Delete)
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: Icon(Icons.archive_outlined, color: Colors.grey[400], size: 20),
              onPressed: () => _confirmArchive(doc),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return RichText(
      text: TextSpan(
        style: GoogleFonts.inter(fontSize: 12, height: 1.5, color: Colors.grey[600]),
        children: [
          TextSpan(text: "$label "),
          TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }

  // --- UPDATED POPUP: Confirm Archive ---
  void _confirmArchive(DocumentSnapshot doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Archive Record?"),
        content: const Text("This record will be moved to the archive and held for 15 days before permanent deletion."),
        actions: [
           TextButton(child: const Text("Cancel"), onPressed: () => Navigator.pop(ctx)),
           ElevatedButton(
             style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
             child: const Text("Archive"), 
             onPressed: () {
               Navigator.pop(ctx);
               _archiveBatch(doc);
             }
           ),
        ],
      )
    );
  }
}