import 'package:flutter/material.dart';
import '../screens/app_drawer.dart';

class HelpScreen extends StatelessWidget {
  final String userId;
  final String role;

  const HelpScreen({super.key, required this.userId, required this.role});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Core Features'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      drawer: AppDrawer(
        currentPage: 'help',
        userId: userId,
        role: role,
      ),
      backgroundColor: const Color(0xFFF7F8FA),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          const Text(
            'Core Features Overview',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4B1EFF),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Welcome to the V-Audit Help Center. This section highlights the key features designed for this application thesis.',
            style: TextStyle(fontSize: 16, color: Colors.black87),
          ),
          const SizedBox(height: 24),
          _buildFeatureCard(
            title: 'Certificate Expiry Monitoring',
            icon: Icons.event_available,
            children: [
              const Text(
                'In the Profiling Team screen, the application automatically highlights the status of various certificates based on their expiry date relative to the audit creation date.',
                style: TextStyle(fontSize: 15, color: Colors.black87, height: 1.5),
              ),
              const SizedBox(height: 16),
              _buildLegendItem(
                color: Colors.green.shade800,
                bgColor: Colors.green.shade50,
                borderColor: Colors.green,
                icon: Icons.check_circle,
                title: 'Valid (Green)',
                description: 'The certificate is valid and is not expiring within 3 months after the audit date.',
              ),
              const SizedBox(height: 12),
              _buildLegendItem(
                color: Colors.amber.shade900,
                bgColor: Colors.amber.shade50,
                borderColor: Colors.amber.shade700,
                icon: Icons.warning_amber_rounded,
                title: 'Expiring Soon (Yellow)',
                description: 'The certificate is expiring soon (within 3 months after the audit date).',
              ),
              const SizedBox(height: 12),
              _buildLegendItem(
                color: Colors.red,
                bgColor: Colors.red.shade50,
                borderColor: Colors.red,
                icon: Icons.error,
                title: 'Expired (Red)',
                description: 'The certificate has already expired before the audit date.',
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildFeatureCard(
            title: 'Geolocation Stamp',
            icon: Icons.location_on,
            children: [
              const Text(
                'When capturing images for physical inspections or findings, the application automatically embeds a geolocation stamp into the data.',
                style: TextStyle(fontSize: 15, color: Colors.black87, height: 1.5),
              ),
              const SizedBox(height: 16),
              _buildLegendItem(
                color: Colors.blue.shade800,
                bgColor: Colors.blue.shade50,
                borderColor: Colors.blue,
                icon: Icons.gps_fixed,
                title: 'Data Authenticity & Verification',
                description: 'Captures precise GPS coordinates (Latitude & Longitude) alongside the exact timestamp. This proves the auditor\'s physical presence at the inspection site and provides a verifiable audit trail for compliance.',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 2,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4B1EFF).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: const Color(0xFF4B1EFF), size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required Color bgColor,
    required Color borderColor,
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: borderColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: color.withValues(alpha: 0.9),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
