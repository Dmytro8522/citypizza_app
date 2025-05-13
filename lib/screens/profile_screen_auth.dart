// lib/screens/profile_screen_auth.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import 'order_history_screen.dart';
import 'home_screen.dart';
import '../utils/globals.dart';

class ProfileScreenAuth extends StatelessWidget {
  const ProfileScreenAuth({Key? key}) : super(key: key);

  Future<void> _signOut(BuildContext context) async {
    await AuthService.signOut();
    navigatorKey.currentState!.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen(initialIndex: 2)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? 'Unbekannt';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: ListView(
          padding:
              const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.white12,
              child: const Icon(Icons.person,
                  size: 48, color: Colors.white54),
            ),
            const SizedBox(height: 16),
            Text(
              email,
              style: GoogleFonts.poppins(
                  color: Colors.white, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            ListTile(
              leading: const Icon(Icons.history,
                  color: Colors.white),
              title: Text('Bestellhistorie',
                  style: GoogleFonts.poppins(
                      color: Colors.white)),
              onTap: () {
                navigatorKey.currentState!.push(
                  MaterialPageRoute(
                      builder: (_) =>
                          const OrderHistoryScreen()),
                );
              },
            ),
            const Divider(color: Colors.white24),

            ListTile(
              leading: const Icon(Icons.card_giftcard,
                  color: Colors.white),
              title: Text('Gutscheine & Angebote',
                  style: GoogleFonts.poppins(
                      color: Colors.white)),
              onTap: () {
                ScaffoldMessenger.of(context)
                    .showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Hier kommen Ihre Gutscheine')),
                );
              },
            ),
            const Divider(color: Colors.white24),

            ListTile(
              leading:
                  const Icon(Icons.settings, color: Colors.white),
              title: Text('Einstellungen',
                  style: GoogleFonts.poppins(
                      color: Colors.white)),
              onTap: () {
                ScaffoldMessenger.of(context)
                    .showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Hier kommen die Einstellungen')),
                );
              },
            ),
            const Divider(color: Colors.white24),

            ListTile(
              leading: const Icon(Icons.logout,
                  color: Colors.white),
              title: Text('Abmelden',
                  style: GoogleFonts.poppins(
                      color: Colors.white)),
              onTap: () => _signOut(context),
            ),
          ],
        ),
      ),
    );
  }
}
