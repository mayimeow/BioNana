import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
// --- NEW IMPORT ---
import 'package:flutter_application_1/pages/archive_page.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  // --- BRAND COLORS ---
  final Color bioGreen = const Color(0xFF266533);
  final Color nanaYellow = const Color(0xFFDCC115);
  final Color cardTextTitle = const Color(0xFF1F2937); // Dark Grey
  final Color cardTextBody = const Color(0xFF6B7280);  // Light Grey

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9), // Light grey background
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          children: [
            // --- 1. HEADER (Logo + BioNana) ---
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
            
            const SizedBox(height: 24),

            // --- 2. PAGE TITLE ---
            Text(
              "About BioNana",
              style: GoogleFonts.inter(
                fontSize: 20, 
                fontWeight: FontWeight.bold, 
                color: bioGreen
              ),
            ),

            const SizedBox(height: 16),

            // --- 3. CARDS ---
            
            // PROJECT OVERVIEW
            _buildSectionCard(
              title: "Project Overview",
              children: [
                Text(
                  "The BioNana project is a research initiative focused on sustainable waste utilization. Our primary goal is to convert the discarded banana pseudostem—an abundant agricultural byproduct—into a nutrient-rich, liquid fertilizer through a controlled fermentation process.",
                  style: GoogleFonts.inter(
                    fontSize: 14, 
                    height: 1.6, 
                    color: cardTextBody
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // PROCESS AUTOMATION
            _buildSectionCard(
              title: "The Process Automation",
              children: [
                _buildProcessStep(
                  icon: Icons.rotate_right_sharp,
                  title: "Extraction",
                  subtitle: "Manual process using a physical button-controlled screw-press mechanism.",
                ),
                const Divider(height: 24),
                _buildProcessStep(
                  icon: Icons.opacity,
                  title: "Volumetric Sensing",
                  subtitle: "An ESP32-controlled water level sensor accurately measures the extracted sap volume.",
                ),
                const Divider(height: 24),
                _buildProcessStep(
                  icon: Icons.water_drop,
                  title: "Auto-Dosing",
                  subtitle: "A Cloud Function calculates the required water (1:1) and molasses (3ml/100mL).",
                ),
                const Divider(height: 24),
                _buildProcessStep(
                  icon: Icons.science,
                  title: "Fermentation & Cooling",
                  subtitle: "The mixture ferments for 7 days. An automated cooling system ensures the temperature never exceeds 30°C.",
                ),
              ],
            ),

            const SizedBox(height: 16),

            // SOFTWARE STACK
            _buildSectionCard(
              title: "Software & Data Stack",
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildStackItem(
                        icon: Icons.phone_android,
                        title: "App Layer",
                        subtitle: "Flutter & Dart (Android/iOS)",
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStackItem(
                        icon: Icons.cloud_queue,
                        title: "Backend",
                        subtitle: "Firebase (Real-time DB & Functions)",
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // THE TEAM
            _buildSectionCard(
              title: "The Team",
              children: [
                _buildTeamMember("Mary Ann G. Gumafelix"),
                _buildTeamMember("Jan Allen Silvestre"),
                _buildTeamMember("Jerameel Rhey P. Suyat"),
                _buildTeamMember("Ashanti Louise B. Villadiego"),
              ],
            ),

            const SizedBox(height: 16),

            _buildSectionCard(
              title: "Data Management",
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.archive_outlined, color: bioGreen, size: 28),
                  title: Text("Batch Archive", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text("View or restore deleted batches (Kept for 15 days)", style: GoogleFonts.inter(fontSize: 12, color: cardTextBody)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ArchivePage()));
                  },
                ),
              ],
            ),

            const SizedBox(height: 32),

            // --- 4. FOOTER / CONTACT ---
            Center(
              child: Column(
                children: [
                  Text("For inquiries, contact us at:", 
                    style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 12)
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.mail_outline, size: 16, color: bioGreen),
                      const SizedBox(width: 8),
                      Text(
                        "pupbionana@gmail.com",
                        style: GoogleFonts.inter(
                          fontSize: 14, 
                          fontWeight: FontWeight.bold, 
                          color: bioGreen
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16, 
              fontWeight: FontWeight.bold, 
              color: cardTextTitle
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildProcessStep({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: bioGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: bioGreen, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, 
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: cardTextTitle)
              ),
              const SizedBox(height: 4),
              Text(subtitle, 
                style: GoogleFonts.inter(fontSize: 13, height: 1.4, color: cardTextBody)
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStackItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: bioGreen, size: 24),
        const SizedBox(height: 8),
        Text(title, 
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: cardTextTitle)
        ),
        const SizedBox(height: 4),
        Text(subtitle, 
          style: GoogleFonts.inter(fontSize: 12, height: 1.4, color: cardTextBody)
        ),
      ],
    );
  }

  Widget _buildTeamMember(String name) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(Icons.person, size: 18, color: bioGreen),
          const SizedBox(width: 12),
          Text(name, 
            style: GoogleFonts.inter(fontSize: 14, color: Colors.black87)
          ),
        ],
      ),
    );
  }
}