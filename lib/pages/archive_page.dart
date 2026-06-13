import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_1/services/local_db_service.dart';

class ArchivePage extends StatefulWidget {
  const ArchivePage({super.key});

  @override
  State<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends State<ArchivePage> {
  final Color bioGreen = const Color(0xFF266533);
  final Color redAccent = const Color(0xFFFF3B30);

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return "Unknown";
    return DateFormat('MMM d, yyyy - h:mm a').format(timestamp.toDate());
  }

  Future<void> _restoreBatch(DocumentSnapshot doc) async {
    try {
      final data = doc.data() as Map<String, dynamic>;
      data.remove('archivedAt'); // Clean up the archive timestamp
      
      // 1. Move back to active cloud batches
      await FirebaseFirestore.instance.collection('batches').doc(doc.id).set(data);
      
      // 2. Save back to local DB so charts update again
      await LocalDbService.instance.saveBatchToLocal(data, doc.id);
      
      // 3. Delete from archive
      await FirebaseFirestore.instance.collection('archived_batches').doc(doc.id).delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Batch Restored Successfully"), backgroundColor: Colors.green));
      }
    } catch (e) {
      debugPrint("Error restoring: $e");
    }
  }

  Future<void> _permanentlyDelete(String docId) async {
    try {
      await FirebaseFirestore.instance.collection('archived_batches').doc(docId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Permanently Deleted"), backgroundColor: Colors.red));
      }
    } catch (e) {
      debugPrint("Error deleting: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: Text("Batch Archive", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: bioGreen)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: IconThemeData(color: bioGreen),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('archived_batches').orderBy('archivedAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_delete_outlined, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 8),
                  Text("Archive is empty", style: GoogleFonts.inter(color: Colors.grey[400])),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              
              // Calculate 15-day expiration
              final archivedAt = data['archivedAt'] as Timestamp?;
              int daysLeft = 15;
              
              if (archivedAt != null) {
                final daysPassed = DateTime.now().difference(archivedAt.toDate()).inDays;
                if (daysPassed >= 15) {
                  // Background auto-delete if older than 15 days
                  FirebaseFirestore.instance.collection('archived_batches').doc(doc.id).delete();
                  return const SizedBox.shrink(); 
                }
                daysLeft = 15 - daysPassed;
              }

              return _buildArchivedCard(doc, data, daysLeft);
            },
          );
        },
      ),
    );
  }

  Widget _buildArchivedCard(DocumentSnapshot doc, Map<String, dynamic> data, int daysLeft) {
    final batchName = data['batchName'] ?? 'Unknown Batch';
    final archivedAt = data['archivedAt'] as Timestamp?;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(batchName, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: daysLeft <= 3 ? redAccent.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)
                ),
                child: Text("$daysLeft days left", style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.bold, 
                  color: daysLeft <= 3 ? redAccent : Colors.orange[800]
                )),
              )
            ],
          ),
          const SizedBox(height: 8),
          Text("Archived on: ${_formatDate(archivedAt)}", style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
          
          const Divider(height: 24),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.delete_forever, size: 18),
                label: const Text("Delete"),
                style: TextButton.styleFrom(foregroundColor: redAccent),
                onPressed: () => _permanentlyDelete(doc.id),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.restore, size: 18),
                label: const Text("Restore"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: bioGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                onPressed: () => _restoreBatch(doc),
              )
            ],
          )
        ],
      ),
    );
  }
}