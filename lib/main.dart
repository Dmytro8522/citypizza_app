import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/consent_service.dart';
import 'services/cart_service.dart';
import 'screens/welcome_screen.dart';
import 'screens/cookie_settings_screen.dart';
import 'screens/home_screen.dart';
import 'screens/cart_screen.dart';
import 'widgets/working_hours_banner.dart';
import 'utils/globals.dart'; // ваш navigatorKey

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Фиксируем портретный режим
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  await Supabase.initialize(
    url: 'https://kwjbfxaoicmvdkrcgmpo.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt3amJmeGFvaWNtdmRrcmNnbXBvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDYwOTAyNjIsImV4cCI6MjA2MTY2NjI2Mn0.MqdObfe9_4_kkWzMAywK7XZkYVVpin2HUts39rmv6lU',
  );

  // подгружаем сохранённые товары из SharedPreferences
  await CartService.init();

  // читаем, куда идти дальше
  final legalDone = await ConsentService.hasAgreedLegal();
  final cookiesDone = await ConsentService.hasConsent(CookieType.analyse) ||
      await ConsentService.hasConsent(CookieType.personalisation);

  runApp(CityPizzaApp(
    legalDone: legalDone,
    cookiesDone: cookiesDone,
  ));
}

class CityPizzaApp extends StatelessWidget {
  final bool legalDone;
  final bool cookiesDone;

  const CityPizzaApp({
    required this.legalDone,
    required this.cookiesDone,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    Widget home;
    if (!legalDone) {
      home = const WelcomeScreen();
    } else if (!cookiesDone) {
      home = const CookieSettingsScreen();
    } else {
      home = const HomeScreen();
    }

    return MaterialApp(
      title: 'City Pizza',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      builder: (context, child) {
        // рассчитываем, на сколько «поднять» баннер над bottomNav
        final bottomInset = MediaQuery.of(context).padding.bottom +
            (legalDone && cookiesDone ? kBottomNavigationBarHeight : 0);

        return Stack(
          children: [
            // внизу — само приложение
            Positioned.fill(child: child!),
            // поверх него — баннер «закрыто» только после прохождения Welcome и Cookie screens
            if (legalDone && cookiesDone)
              WorkingHoursBanner(bottomInset: bottomInset),
          ],
        );
      },
      home: home,
    );
  }
}
