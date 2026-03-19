import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'login_screen.dart';
import 'main_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AuthService.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          final user = snapshot.data as dynamic;
          final uid = user?.uid as String?;
          if (uid != null) {
            Future.microtask(
              () => DatabaseService.instance.syncFromFirestore(uid),
            );
          }
          return const MainPage();
        }
        // clear local data when signed out
        DatabaseService.instance.clearLocalData();
        return const LoginScreen();
      },
    );
  }
}
