import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:io' show Platform;
import 'screens/add_transaction_screen.dart';
import 'screens/transaction_list_screen.dart';
import 'screens/statistics_screen.dart';
import 'screens/auth_gate.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'services/database_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // initialize intl date formatting for Vietnamese locale
  await initializeDateFormatting('vi_VN');
  // initialize firebase. Prefer platform resource init, but fallback to explicit options
  if (Platform.isAndroid) {
    // values taken from android/app/google-services.json
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyCJWTKNQ2p67UyOIpsLRsjLkgZCIyuXUww',
        appId: '1:962555466220:android:18c4a552f2d32011dc70c9',
        messagingSenderId: '962555466220',
        projectId: 'transaction-project-951ff',
        storageBucket: 'transaction-project-951ff.firebasestorage.app',
      ),
    );
  } else {
    await Firebase.initializeApp();
  }
  // initialize local persistence for transactions
  await DatabaseService.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = ColorScheme.fromSeed(
      seedColor: const Color(0xFF00695C),
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'Finance Manager',
      theme: ThemeData(
        colorScheme: cs,
        useMaterial3: true,
        scaffoldBackgroundColor: cs.surface,
        appBarTheme: AppBarTheme(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          elevation: 1,
          surfaceTintColor: cs.primary,
        ),
        cardTheme: CardThemeData(
          color: cs.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: cs.surfaceContainerHighest,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: cs.primaryContainer,
            foregroundColor: cs.onPrimaryContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: cs.surface,
          indicatorColor: cs.primaryContainer,
        ),
      ),
      home: const AuthGate(),
      routes: {
        AddTransactionScreen.routeName: (_) => const AddTransactionScreen(),
        TransactionListScreen.routeName: (_) => const TransactionListScreen(),
        StatisticsScreen.routeName: (_) => const StatisticsScreen(),
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
      },
    );
  }
}

// MainPage moved to lib/screens/main_page.dart
