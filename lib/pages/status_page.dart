import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/services/local_db_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:flutter_application_1/services/notification_service.dart';

class StatusPage extends StatefulWidget {
  const StatusPage({super.key});

  @override
  State<StatusPage> createState() => _StatusPageState();
}

class _StatusPageState extends State<StatusPage> {
  final String sharedMachineId = "bionana_machine_01";
  final String? userId = FirebaseAuth.instance.currentUser?.uid;
  late Stream<DocumentSnapshot> _currentBatchStream;

  bool _isBatchProcessing = false;

  // --- BRAND & STATE COLORS ---
  final Color bioGreen = const Color(0xFF266533);
  final Color nanaYellow = const Color(0xFFDCC115);
  final Color uiRed = const Color(0xFFFF3B30); // Specific Red from design
  
  // State Backgrounds
  final Color bgOrange = const Color(0xFFFFF3E0); 
  final Color textOrange = const Color(0xFFEF6C00);
  final Color bgBlue = const Color(0xFFE3F2FD);
  final Color textBlue = const Color(0xFF1565C0);
  final Color bgGreen = const Color(0xFFE8F5E9);
  final Color textGreen = const Color(0xFF2E7D32);
  final Color bgGrey = const Color(0xFFF5F5F5);
  final Color textGrey = const Color(0xFF757575);

  @override
  void initState() {
    super.initState();
    _currentBatchStream = FirebaseFirestore.instance
        .collection('current_batch')
        .doc(sharedMachineId)
        .snapshots();
  }

  // --- ACTIONS (Database Logic) ---

  void _startNewBatch() async {
    if (_isBatchProcessing) return;
    setState(() => _isBatchProcessing = true);

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('current_batch').doc(sharedMachineId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final status = data['status'] ?? 'Idle';
        
        // --- READ THE 4 SENSORS ---
        final sensors = data['sensor_levels'] as Map<String, dynamic>? ?? {};
        
        // --- LEVEL 1 SAFETY LOCK ---
        bool hasResidualLiquid = sensors['level_1'] == true; 

        if (status != 'Idle' && status != 'Complete') {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Batch in progress.")));
          return;
        }
        
        // STRICT TANK VALIDATION
        if (hasResidualLiquid) {
           if (mounted) {
             _showErrorDialog(
               "Tank Not Empty", 
               "The bottom sensor detects liquid. Please drain and clean the tank completely before starting a new batch."
             );
           }
           return;
        }
      }

      await FirebaseFirestore.instance.collection('current_batch').doc(sharedMachineId).set({
        'status': 'ReadyToExtract',
        'sensor_levels': { 'level_1': false, 'level_2': false, 'level_3': false, 'level_4': false }, 
        'startTime': FieldValue.serverTimestamp(),
        'batchName': "New Batch...",
        'currentTemp': 0.0,
        'tempHistory': [], 
        'coolingStatus': 'Off',
        'sapVolume': 0.0,
        'waterVolume': 0.0,
        'molassesVolume': 0.0,
        'totalVolume': 0.0,
      });
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      if (mounted) setState(() => _isBatchProcessing = false);
    }
  }

  void _finishExtractionPhase() async {
     if (_isBatchProcessing) return;
     
     final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Finish Extraction?"),
        content: const Text("Press this ONLY when you are done crushing ALL the banana stems and have cleared the machine."),
        actions: [
          TextButton(child: const Text("Cancel"), onPressed: () => Navigator.pop(context, false)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: bioGreen, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Yes, Proceed"),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    setState(() => _isBatchProcessing = true);
    
    try {
      // 1. Enter the settling phase
      await FirebaseFirestore.instance.collection('current_batch').doc(sharedMachineId).update({'status': 'Settling'}); 
      
      // 2. Wait 15 seconds to allow hardware ripples to stabilize
      await Future.delayed(const Duration(seconds: 15));

      // 3. Trigger the Cloud Function to calculate
      await FirebaseFirestore.instance.collection('current_batch').doc(sharedMachineId).update({'status': 'Calculating'}); 
    } finally {
      if (mounted) setState(() => _isBatchProcessing = false);
    }
  }

  void _startFermentation(double calculatedMolasses) async {
    if (_isBatchProcessing) return;
    
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Ingredient"),
        content: const Text("Have you added the required amount of molasses to the tank?"),
        actions: [
          TextButton(child: const Text("Not Yet", style: TextStyle(color: Colors.red)), onPressed: () => Navigator.pop(context, false)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green[100], foregroundColor: Colors.green[800], elevation: 0),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Yes, Start Fermentation"),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    setState(() => _isBatchProcessing = true);
    
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('current_batch').doc(sharedMachineId).get();
      final data = doc.data() as Map<String, dynamic>;
      final totalVol = (data['totalVolume'] ?? 0.0).toDouble();

      await FirebaseFirestore.instance.collection('current_batch').doc(sharedMachineId).update({
        'status': 'Fermenting',
        'currentTankVolume': totalVol,
        'fermentationStartTime': FieldValue.serverTimestamp(),
        'molassesVolume': calculatedMolasses,
      });

      await NotificationService.instance.cancelIngredientReminder();
      await NotificationService.instance.scheduleFermentationComplete();

    } finally {
      if (mounted) setState(() => _isBatchProcessing = false);
    }
  }

  void _finishBatch() async {
    if (_isBatchProcessing) return;
    setState(() => _isBatchProcessing = true);
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('current_batch').doc(sharedMachineId).get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        
        final completedData = {
          ...data,
          'status': 'Complete', 
          'completedAt': FieldValue.serverTimestamp(),
        };

        DocumentReference ref = await FirebaseFirestore.instance.collection('batches').add(completedData);
        await LocalDbService.instance.saveBatchToLocal(completedData, ref.id);
      }

      await FirebaseFirestore.instance.collection('current_batch').doc(sharedMachineId).update({
        'status': 'Idle',
        'batchName': 'Idle',
        'startTime': null,
        'fermentationStartTime': null,
        'sapVolume': 0.0,
        'waterVolume': 0.0,
        'molassesVolume': 0.0,
        'totalVolume': 0.0,
        'coolingStatus': 'Off',
        'currentTemp': 0.0,
        'tempHistory': FieldValue.delete(), 
      });

    } catch (e) {
      debugPrint("Error finishing batch: $e");
    } finally {
      if (mounted) setState(() => _isBatchProcessing = false);
    }
  }

  void _cancelBatch() async {
    if (_isBatchProcessing) return;

    String selectedReason = 'Wrong Ingredient Amount'; 
    TextEditingController otherController = TextEditingController();

    final String? finalReason = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              backgroundColor: Colors.white,
              titlePadding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 10),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              actionsPadding: const EdgeInsets.all(24),
              
              title: Text(
                "Cancel Batch?",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)
              ),
              
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Please select a reason for cancellation. This will be recorded in your history.",
                      style: GoogleFonts.inter(fontSize: 14, height: 1.5, color: Colors.grey[600])
                    ),
                    const SizedBox(height: 16),
                    
                    RadioGroup<String>(
                      groupValue: selectedReason,
                      onChanged: (String? val) {
                        if (val != null) {
                          setState(() => selectedReason = val);
                        }
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildRadioOption("Wrong Ingredient Amount"),
                          _buildRadioOption("Equipment / Sensor Failure"),
                          _buildRadioOption("Power Outage"),
                          _buildRadioOption("Other"),
                        ],
                      ),
                    ),
                    
                    if (selectedReason == "Other") ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: otherController,
                        decoration: InputDecoration(
                          hintText: "Enter reason...",
                          hintStyle: GoogleFonts.inter(fontSize: 14),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        style: GoogleFonts.inter(fontSize: 14),
                      ),
                    ]
                  ],
                ),
              ),
              
              actions: [
                Column(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, null),
                      child: Text("Go Back", style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF6366F1))),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: uiRed,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          String reasonToSave = selectedReason;
                          if (selectedReason == "Other") {
                            reasonToSave = otherController.text.trim().isEmpty ? "Unspecified" : otherController.text.trim();
                          }
                          Navigator.pop(context, reasonToSave);
                        },
                        child: Text("Yes, Cancel Batch", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                )
              ],
            );
          }
        );
      },
    );

    if (finalReason == null) return;

    setState(() => _isBatchProcessing = true);

    try {
       DocumentSnapshot doc = await FirebaseFirestore.instance.collection('current_batch').doc(sharedMachineId).get();
       
       if (doc.exists) {
         final data = doc.data() as Map<String, dynamic>;
         
         final canceledData = {
           ...data,
           'status': 'Canceled', 
           'cancelReason': finalReason, 
           'completedAt': FieldValue.serverTimestamp(),
         };

         DocumentReference ref = await FirebaseFirestore.instance.collection('batches').add(canceledData);
         await LocalDbService.instance.saveBatchToLocal(canceledData, ref.id);
       }

       await FirebaseFirestore.instance.collection('current_batch').doc(sharedMachineId).update({
         'status': 'Idle',
         'batchName': 'Idle',
         'startTime': null,
         'fermentationStartTime': null,
         'sapVolume': 0.0,
         'waterVolume': 0.0,
         'molassesVolume': 0.0,
         'totalVolume': 0.0,
         'coolingStatus': 'Off',
         'currentTemp': 0.0,
         'tempHistory': FieldValue.delete(), 
       });

       await NotificationService.instance.cancelAllNotifications();

    } catch (e) {
      debugPrint("Error cancelling: $e");
    } finally {
      if (mounted) setState(() => _isBatchProcessing = false);
    }
  }

  Widget _buildRadioOption(String title) {
    return RadioListTile<String>(
      title: Text(title, style: GoogleFonts.inter(fontSize: 14)),
      value: title,
      contentPadding: EdgeInsets.zero,
      visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
      activeColor: bioGreen,
    );
  }

  void _showErrorDialog(String title, String content) {
    showDialog(context: context, builder: (context) => AlertDialog(title: Text(title), content: Text(content), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))]));
  }

  // --- UI BUILDER ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: _currentBatchStream,
          builder: (context, snapshot) {
            String status = "Idle";
            Map<String, dynamic> data = {};

            if (snapshot.hasData && snapshot.data!.exists) {
              data = snapshot.data!.data() as Map<String, dynamic>;
              status = data['status'] ?? 'Idle';
            }

            bool isIdle = status == "Idle";
            bool isProcessing = _isBatchProcessing;

            String btnText = "Start New Batch";
            VoidCallback? btnAction = _startNewBatch;
            String? waitingText; 

            if (isProcessing) {
              waitingText = "Processing...";
            } else {
              switch (status) {
                case 'ReadyToExtract':
                  waitingText = "Waiting for Machine ..."; 
                  break;
                case 'Extracting':
                  btnText = "Finish Extraction";
                  btnAction = _finishExtractionPhase;
                  break;
                case 'Settling':
                  waitingText = "Stabilizing Sap..."; 
                  break;
                case 'Calculating':
                  waitingText = "Calculating";
                  break;
                case 'ReadyToDose':
                case 'Dosing':
                  waitingText = "Dosing";
                  break;
                case 'Awaiting Molasses':
                  btnText = "Done Adding Molasses";
                  double sap = (data['sapVolume'] ?? 0.0).toDouble();
                  btnAction = () => _startFermentation(sap * 0.03);
                  
                  Future.delayed(Duration.zero, () => NotificationService.instance.scheduleIngredientReminder());
                  break;
                case 'Fermenting':
                  Timestamp? fermStart = data['fermentationStartTime'];
                  bool isDone = false;
                  
                  if (fermStart != null) {
                    final start = fermStart.toDate();
                    final diff = DateTime.now().difference(start);
                    if (diff.inDays >= 7) {
                      isDone = true;
                    }
                  }

                  if (isDone) {
                    btnText = "Finish Batch";
                    btnAction = _finishBatch;
                  } else {
                    waitingText = "Fermentation in Progress..."; 
                  }
                  break;
                case 'Complete':
                  btnText = "Finish Batch";
                  btnAction = _finishBatch;
                  break;
              }
            }

            bool showComposition = [
              'Calculating', 'ReadyToDose', 'Dosing', 'Awaiting Molasses', 'Fermenting', 'Complete'
            ].contains(status);

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- HEADER ---
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
                  const SizedBox(height: 12),
                  Text("Status & Controls", 
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: bioGreen)
                  ),
                  const SizedBox(height: 20),

                  // --- STATUS CARD ---
                  _buildMainStatusCard(status, data),

                  const SizedBox(height: 24),

                  // --- LIVE DATA LABEL ---
                  Text("LIVE DATA", style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: bioGreen, letterSpacing: 1.0)),
                  const SizedBox(height: 12),

                  // --- GRID 2x2 ---
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildProgressCard(status, data)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildTempCard(status, data)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildCoolingCard(status, data)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildTankCard(status, data)),
                        ],
                      ),
                    ],
                  ),

                  // --- COMPOSITION CARD ---
                  if (showComposition) ...[
                    const SizedBox(height: 24),
                    Text("BATCH COMPOSITION", style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: bioGreen, letterSpacing: 1.0)),
                    const SizedBox(height: 12),
                    _buildCompositionCard(data),
                  ],

                  const SizedBox(height: 32),

                  // --- PRIMARY BUTTON ---
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (waitingText != null) ? Colors.grey[200] : nanaYellow,
                        foregroundColor: (waitingText != null) ? Colors.grey[500] : Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      onPressed: (waitingText != null) ? null : btnAction,
                      child: Text(
                        waitingText ?? btnText, 
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)
                      ),
                    ),
                  ),

                  // --- CANCEL BUTTON (Red Outline) ---
                  if (!isIdle && status != 'Complete') ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: uiRed.withValues(alpha: 0.3)), 
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          foregroundColor: uiRed,
                        ),
                        onPressed: _cancelBatch,
                        child: Text("Cancel", style: GoogleFonts.inter(fontSize: 16)),
                      ),
                    )
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // --- WIDGET HELPERS ---

  Widget _buildMainStatusCard(String status, Map<String, dynamic> data) {
    Color bg = Colors.white;
    Color iconColor = Colors.grey;
    IconData icon = Icons.power_settings_new;
    String title = "Idle";
    String subtitle = "Ready to start a new batch";
    
    String batchName = data['batchName'] ?? '';

    switch (status) {
      case 'ReadyToExtract':
        bg = bgOrange; iconColor = textOrange; icon = Icons.play_arrow_rounded;
        title = "Ready to Extract"; subtitle = "Machine is ready. Press the physical 'Start' button."; break;
      case 'Extracting':
        bg = bgOrange; iconColor = textOrange; icon = Icons.refresh;
        title = "Extracting"; subtitle = "Manual Mode. Press 'Finish Extraction' in app when done."; break;
      case 'Settling':
        bg = bgBlue; iconColor = textBlue; icon = Icons.hourglass_empty;
        title = "Stabilizing"; subtitle = "Hardware is waiting 15 seconds for liquid to settle..."; break;
      case 'Calculating':
        bg = bgBlue; iconColor = textBlue; icon = Icons.calculate_outlined;
        title = "Calculating"; subtitle = "Calculating volumes..."; break;
      case 'Dosing': case 'ReadyToDose':
        bg = bgBlue; iconColor = textBlue; icon = Icons.water_drop;
        title = "Dosing"; subtitle = "Dosing Water... Please Wait"; break;
      case 'Awaiting Molasses':
        bg = bgOrange; iconColor = textOrange; icon = Icons.add;
        title = "Awaiting Molasses"; 
        double mol = (data['sapVolume'] ?? 0) * 0.03;
        subtitle = "Please add ${mol.toStringAsFixed(2)} ml of molasses."; break;
      case 'Fermenting':
        bg = bgOrange; iconColor = textOrange; icon = Icons.science;
        title = "Fermenting";
        
        String dateStr = "";
        if (data['fermentationStartTime'] != null) {
          if (data['fermentationStartTime'] is Timestamp) {
             dateStr = DateFormat('MMM d, h:mm a').format((data['fermentationStartTime'] as Timestamp).toDate());
          }
        }
        subtitle = "Started: $dateStr\n(Standard 7-day process)"; 
        break;
      case 'Complete':
        bg = bgGreen; iconColor = textGreen; icon = Icons.check;
        title = "Complete"; subtitle = "Batch process finished successfully."; break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: status == 'Idle' ? Colors.transparent : Colors.white.withValues(alpha: 0.5),
              shape: BoxShape.circle,
              border: status == 'Idle' ? Border.all(color: Colors.grey, width: 3) : null,
            ),
            child: Icon(icon, color: iconColor, size: 36),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (status != 'Idle' && batchName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text(
                      batchName.toUpperCase(), 
                      style: GoogleFonts.inter(
                        fontSize: 10, 
                        fontWeight: FontWeight.bold, 
                        color: iconColor.withValues(alpha: 0.7),
                        letterSpacing: 1.0
                      ),
                    ),
                  ),

                Text(title, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: status == 'Idle' ? Colors.grey : iconColor)),
                const SizedBox(height: 6),
                Text(subtitle, style: GoogleFonts.inter(fontSize: 13, height: 1.4, color: Colors.black87)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildGridCard({required Widget content, required String title, Color? bgColor}) {
    return Container(
      height: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor ?? bgGrey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[700])),
          Expanded(child: Center(child: content)),
        ],
      ),
    );
  }

  Widget _buildProgressCard(String status, Map<String, dynamic> data) {
    Color bg = bgGrey;
    Widget content = Text("-", style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.grey[500]));

    if (status == 'Fermenting') {
      bg = bgGreen;
      Timestamp? start = data['fermentationStartTime'];
      if (start != null) {
        final diff = DateTime.now().difference(start.toDate());
        
        int totalTargetHours = 7 * 24; 
        int hoursPassed = diff.inHours;
        int hoursLeftTotal = totalTargetHours - hoursPassed;

        if (hoursLeftTotal <= 0) {
          content = Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Ready!", style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: textGreen)),
              Text("Press Finish", style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: textGreen)),
            ],
          );
        } else {
          int daysLeft = hoursLeftTotal ~/ 24;
          int hoursLeft = hoursLeftTotal % 24;
          
          content = Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("$daysLeft days,", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: textGreen)),
              Text("$hoursLeft hours left", style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: textGreen)),
            ],
          );
        }
      }
    } else if (status == 'Complete') {
      bg = bgGreen;
      content = Text("0", style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.bold, color: textGreen));
    }
    return _buildGridCard(title: "Progress", content: content, bgColor: bg);
  }

  Widget _buildTempCard(String status, Map<String, dynamic> data) {
    double temp = (data['currentTemp'] ?? 0.0).toDouble();
    Color bg = bgGrey;
    Color contentColor = Colors.grey[600]!;
    if (status != 'Idle' && status != 'ReadyToExtract') {
      bg = bgOrange; contentColor = textOrange;
    }
    return _buildGridCard(
      title: "Temperature", bgColor: bg,
      content: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.thermostat, color: contentColor, size: 24),
          const SizedBox(width: 8),
          Text("${temp.toStringAsFixed(1)} C", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: contentColor)),
      ]),
    );
  }

  Widget _buildCoolingCard(String status, Map<String, dynamic> data) {
    String cool = data['coolingStatus'] ?? 'OFF';
    bool isOn = cool.toUpperCase() == 'ON';
    return _buildGridCard(
      title: "Cooling System", bgColor: bgGrey,
      content: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.ac_unit, color: Colors.grey[600], size: 24),
          const SizedBox(width: 8),
          Text(isOn ? "ON" : "OFF", style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[700])),
      ]),
    );
  }

  // --- UPDATED TANK SENSOR CARD ---
  Widget _buildTankCard(String status, Map<String, dynamic> data) {
    // 1. Read the sensor map
    final sensors = data['sensor_levels'] as Map<String, dynamic>? ?? {};
    bool l1 = sensors['level_1'] == true;
    bool l2 = sensors['level_2'] == true;
    bool l3 = sensors['level_3'] == true;
    bool l4 = sensors['level_4'] == true;

// 2. Determine highest active level (NOW WITH CURLY BRACES)
    String levelText = "Empty";
    if (l4) {
      levelText = "Level 4 (Max)";
    } else if (l3) {
      levelText = "Level 3";
    } else if (l2) {
      levelText = "Level 2";
    } else if (l1) {
      levelText = "Level 1 (Low)";
    }
    // 3. UI Styling
    Color bg = bgGrey;
    Color contentColor = Colors.grey[600]!;
    
    // Turn blue if ANY liquid is detected, or if a batch is active
    if (l1 || (status != 'Idle' && status != 'ReadyToExtract')) {
      bg = bgBlue; 
      contentColor = textBlue;
    }

    return _buildGridCard(
      title: "Tank Level", 
      bgColor: bg,
      content: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.water, color: contentColor, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                levelText, 
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: contentColor)
              ),
            ),
          ),
      ]),
    );
  }

  Widget _buildCompositionCard(Map<String, dynamic> data) {
    double sap = (data['sapVolume'] ?? 0.0).toDouble();
    double water = (data['waterVolume'] ?? 0.0).toDouble();
    double mol = (data['molassesVolume'] ?? 0.0).toDouble();
    if (water == 0 && sap > 0) water = sap * 1.0;
    if (mol == 0 && sap > 0) mol = sap * 0.03;
    double total = sap + water + mol;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          _buildCompRow("Sap Volume", "${sap.toStringAsFixed(1)} ml"),
          const SizedBox(height: 12),
          _buildCompRow("Water Volume", "${water.toStringAsFixed(2)} ml"),
          const SizedBox(height: 12),
          _buildCompRow("Molasses Volume", "${mol.toStringAsFixed(2)} ml"),
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
          _buildCompRow("Est. Total Volume", "${total.toStringAsFixed(2)} ml", isBold: true),
        ],
      ),
    );
  }

  Widget _buildCompRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 14, color: Colors.black87, fontWeight: isBold ? FontWeight.bold : FontWeight.w500)),
        Text(value, style: GoogleFonts.inter(fontSize: 14, color: Colors.black, fontWeight: FontWeight.bold)),
      ],
    );
  }
}