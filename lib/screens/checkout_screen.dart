// lib/screens/checkout_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../services/cart_service.dart';
import '../services/order_service.dart';
import '../utils/working_hours.dart';
import 'menu_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final double totalSum;
  const CheckoutScreen({Key? key, required this.totalSum}) : super(key: key);

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _phone = '';
  bool _isDelivery = true;
  String _paymentMethod = 'cash';
  double? _minOrder;

  final _cityController = TextEditingController();
  final _streetController = TextEditingController();
  final _houseNumberController = TextEditingController();
  final _postalController = TextEditingController();
  final _floorController = TextEditingController();
  final _commentController = TextEditingController();

  bool _isCustomTime = false;
  TimeOfDay? _selectedTime;

  static const Map<String, double> _zoneMin = {
    '04420': 14.0,
    '04205': 19.0, '04209': 19.0,
    '04179': 23.0,
    '04178': 24.0, '04523': 24.0, '06254': 24.0, '06686': 24.0,
    '06231': 27.0,
    '04229': 29.0, '04249': 29.0, '04442': 29.0,
    '04435': 32.0,
  };

  @override
  void dispose() {
    _cityController.dispose();
    _streetController.dispose();
    _houseNumberController.dispose();
    _postalController.dispose();
    _floorController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Bitte aktiviere die Standortdienste in den Einstellungen.'),
        ),
      );
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Standortberechtigung verweigert. Autovervollständigung nicht möglich.',
          ),
        ),
      );
      return;
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final placemarks =
          await placemarkFromCoordinates(pos.latitude, pos.longitude);
      final pl = placemarks.first;
      setState(() {
        _cityController.text = pl.locality ?? '';
        _streetController.text = pl.thoroughfare ?? '';
        _houseNumberController.text = pl.subThoroughfare ?? '';
        _postalController.text = pl.postalCode ?? '';
        _onPostalChanged(_postalController.text);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Standort ermitteln fehlgeschlagen: $e')),
      );
    }
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (t != null) {
      final now = DateTime.now();
      if (!WorkingHours.isWithin(t, now)) {
        final intervals = WorkingHours.intervals(now);
        final formatted = intervals
            .map((i) =>
                '${i['start']!.format(context)}–${i['end']!.format(context)}')
            .join(', ');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Bitte wählen Sie eine andere Zeit gemäß der Arbeitszeiten: $formatted',
            ),
          ),
        );
        return;
      }
      setState(() {
        _selectedTime = t;
        _isCustomTime = true;
      });
    }
  }

  void _onPostalChanged(String v) {
    setState(() {
      _minOrder = _zoneMin[v];
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isCustomTime && _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte gewünschte Uhrzeit wählen')),
      );
      return;
    }
    _formKey.currentState!.save();
    if (_isDelivery) {
      if (_minOrder == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Liefergebiet nicht abgedeckt')),
        );
        return;
      }
      if (widget.totalSum < _minOrder!) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Mindestbestellwert: €${_minOrder!.toStringAsFixed(2)}'),
          ),
        );
        return;
      }
    }

    try {
      await OrderService.createOrder(
        name: _name,
        phone: _phone,
        isDelivery: _isDelivery,
        paymentMethod: _paymentMethod,
        scheduledTime: _isCustomTime
            ? DateTime(
                DateTime.now().year,
                DateTime.now().month,
                DateTime.now().day,
                _selectedTime!.hour,
                _selectedTime!.minute,
              )
            : null,
        city: _cityController.text,
        street: _streetController.text,
        houseNumber: _houseNumberController.text,
        floor: _floorController.text,
        comment: _commentController.text,
        totalSum: widget.totalSum,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bestellung erfolgreich gespeichert!')),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MenuScreen()),
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Speichern: $e')),
      );
    }
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white10,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'Bestellung',
          style: GoogleFonts.fredokaOne(color: Colors.orange),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Name & Telefon
                Card(
                  color: Colors.white12,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.only(bottom: 24),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextFormField(
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration('Name'),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Name ist erforderlich'
                                  : null,
                          onSaved: (v) => _name = v!.trim(),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration('Telefon'),
                          keyboardType: TextInputType.phone,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Telefon ist erforderlich';
                            }
                            final digits =
                                v.replaceAll(RegExp(r'[^0-9]'), '');
                            if (digits.length < 5)
                              return 'Ungültige Nummer';
                            return null;
                          },
                          onSaved: (v) => _phone = v!.trim(),
                        ),
                      ],
                    ),
                  ),
                ),

                // Abholung/Lieferung
                Card(
                  color: Colors.white12,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.only(bottom: 24),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Abholung oder Lieferung',
                          style: GoogleFonts.poppins(
                              color: Colors.white, fontSize: 16),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: RadioListTile<bool>(
                                title: const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text('Lieferung',
                                      style:
                                          TextStyle(color: Colors.white)),
                                ),
                                value: true,
                                groupValue: _isDelivery,
                                onChanged: (v) =>
                                    setState(() => _isDelivery = true),
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<bool>(
                                title: const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text('Abholung',
                                      style:
                                          TextStyle(color: Colors.white)),
                                ),
                                value: false,
                                groupValue: _isDelivery,
                                onChanged: (v) =>
                                    setState(() => _isDelivery = false),
                              ),
                            ),
                          ],
                        ),
                        if (_isDelivery) ...[
                          const Divider(color: Colors.white24),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.my_location),
                            label: Text(
                              'Aktuellen Standort verwenden',
                              style: const TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white10,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14, horizontal: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _useCurrentLocation,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _cityController,
                            style:
                                const TextStyle(color: Colors.white),
                            decoration: _inputDecoration('Stadt'),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'Stadt ist erforderlich'
                                    : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _streetController,
                            style:
                                const TextStyle(color: Colors.white),
                            decoration:
                                _inputDecoration('Straße'),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'Straße ist erforderlich'
                                    : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _houseNumberController,
                            style:
                                const TextStyle(color: Colors.white),
                            decoration: _inputDecoration(
                                'Hausnummer'),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'Hausnummer ist erforderlich'
                                    : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _postalController,
                            style:
                                const TextStyle(color: Colors.white),
                            decoration:
                                _inputDecoration('Postleitzahl'),
                            keyboardType:
                                TextInputType.number,
                            validator: (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'PLZ ist erforderlich'
                                    : null,
                            onChanged: _onPostalChanged,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _floorController,
                            style:
                                const TextStyle(color: Colors.white),
                            decoration: _inputDecoration(
                                'Etage (optional)'),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _commentController,
                            style:
                                const TextStyle(color: Colors.white),
                            decoration: _inputDecoration(
                                'Kommentar für den Kurier (optional)'),
                            maxLines: 3,
                          ),
                          if (_minOrder != null) ...[
                            const SizedBox(height: 8),
                            if (widget.totalSum < _minOrder!) ...[
                              Text(
                                'Ihr Bestellwert: €${widget.totalSum.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight:
                                      FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  minimumSize:
                                      const Size.fromHeight(
                                          48),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(
                                              8)),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const MenuScreen()),
                                  );
                                },
                                child: Text(
                                  'Mehr bestellen',
                                  style: GoogleFonts.poppins(
                                      color: Colors.black,
                                      fontSize: 16),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Mindestbestellwert: €${_minOrder!.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    color: Colors.white70),
                              ),                               
                            ] else ...[
                              Text(
                                'Mindestbestellwert: €${_minOrder!.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    color: Colors.white70),
                              ),
                            ],
                          ],
                        ],
                      ],
                    ),
                  ),
                ),

                // Zahlungsmethode
                Card(
                  color: Colors.white12,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.only(bottom: 24),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text('Zahlungsmethode',
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 16)),
                        RadioListTile<String>(
                          title: const Text('Barzahlung',
                              style: TextStyle(
                                  color: Colors.white)),
                          value: 'cash',
                          groupValue: _paymentMethod,
                          onChanged: (v) =>
                              setState(() =>
                                  _paymentMethod = v!),
                        ),
                        RadioListTile<String>(
                          title: const Text('Kartenzahlung',
                              style: TextStyle(
                                  color: Colors.white)),
                          value: 'card',
                          groupValue: _paymentMethod,
                          onChanged: (v) =>
                              setState(() =>
                                  _paymentMethod = v!),
                        ),
                      ],
                    ),
                  ),
                ),

                // Gewünschte Zeit
                Card(
                  color: Colors.white12,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  margin:
                      const EdgeInsets.only(bottom: 24),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.stretch,
                      children: [
                        Text('Gewünschte Zeit',
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 16)),
                        const Divider(
                            color: Colors.white24),
                        ListTile(
                          contentPadding:
                              EdgeInsets.zero,
                          leading: const Icon(
                              Icons.flash_on,
                              color: Colors.white),
                          title: Text(
                              'So schnell wie möglich',
                              style: GoogleFonts.poppins(
                                  color: Colors.white)),
                          trailing: !_isCustomTime
                              ? const Icon(Icons.check,
                                  color: Colors.orange)
                              : null,
                          onTap: () => setState(() {
                            _isCustomTime = false;
                            _selectedTime = null;
                          }),
                        ),
                        ListTile(
                          contentPadding:
                              EdgeInsets.zero,
                          leading: const Icon(
                              Icons.access_time,
                              color: Colors.white),
                          title: Text(
                              'Wunschzeit einstellen',
                              style: GoogleFonts.poppins(
                                  color: Colors.white)),
                          subtitle: Text(
                            _selectedTime == null
                                ? 'Tippen, um Zeit auszuwählen'
                                : 'Gewählte Zeit: ${_selectedTime!.format(context)}',
                            style: const TextStyle(
                                color: Colors.white60),
                          ),
                          trailing: _selectedTime != null
                              ? const Icon(Icons.check,
                                  color: Colors.orange)
                              : null,
                          onTap: _pickTime,
                        ),
                      ],
                    ),
                  ),
                ),

                // Abschicken
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    minimumSize:
                        const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                                30)),
                  ),
                  onPressed: _submit,
                  child: Text(
                      'Bestellung abschicken',
                      style: GoogleFonts.poppins(
                          color: Colors.black,
                          fontSize: 18)),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
