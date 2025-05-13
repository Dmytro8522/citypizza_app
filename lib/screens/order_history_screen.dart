// lib/screens/order_history_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/order_service.dart';
import '../utils/globals.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({Key? key}) : super(key: key);

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  late Future<List<Map<String, dynamic>>> _futureOrders;

  @override
  void initState() {
    super.initState();
    _futureOrders = OrderService.fetchOrderHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => navigatorKey.currentState!.pop(),
        ),
        title: Text('Bestellhistorie', style: GoogleFonts.fredokaOne(color: Colors.orange)),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futureOrders,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: Colors.orange));
          }
          if (snap.hasError) {
            return Center(
              child: Text('Fehler: ${snap.error}', style: GoogleFonts.poppins(color: Colors.white70)),
            );
          }
          final orders = snap.data!;
          if (orders.isEmpty) {
            return Center(
              child: Text('Keine Bestellungen gefunden', style: GoogleFonts.poppins(color: Colors.white70)),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, i) {
              final o = orders[i];
              final items = (o['order_items'] as List<dynamic>).cast<Map<String, dynamic>>();
              return Card(
                color: Colors.white12,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Bestellt am ${DateTime.parse(o['created_at']).toLocal().toString().substring(0,16)}',
                        style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      ...items.map((it) {
                        final extras = (it['order_item_extras'] as List<dynamic>).cast<Map<String, dynamic>>();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${it['quantity']}× Item #${it['menu_item_id']} (${it['size']})',
                                style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                              ),
                              if (extras.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(left: 12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: extras.map((e) {
                                      return Text(
                                        '+ Extra #${e['extra_id']} ×${e['quantity']}',
                                        style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
                                      );
                                    }).toList(),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                      const Divider(color: Colors.white24),
                      Text(
                        'Gesamt: €${(o['total_sum'] as num).toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
