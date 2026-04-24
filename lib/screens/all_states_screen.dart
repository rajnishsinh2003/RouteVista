import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'state_places_screen.dart';

class AllStatesScreen extends StatelessWidget {
  final List<String> states;

  const AllStatesScreen({super.key, required this.states});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('Explore by State', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF065A60),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: states.length,
        itemBuilder: (context, index) {
          final state = states[index];
          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              title: Text(state, style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 15)),
              trailing: const Icon(Icons.chevron_right, color: Color(0xFF065A60)),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => StatePlacesScreen(stateName: state)),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
