import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'services/auth_service.dart';
import 'services/video_service.dart';
import 'services/analytics_service.dart';
import 'screens/login_screen.dart';
import 'screens/video_player_screen.dart';

/// Faqat gorizontal (landscape), vertikal hech qachon yo'q
void _lockLandscapeOrientation() {
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
}

/// Kiosk UI: status bar, navigation bar yashirilgan, immersive sticky
void _applyKioskUi() {
  _lockLandscapeOrientation();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
  ));
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  _lockLandscapeOrientation();
  _applyKioskUi();

  runApp(const MyApp());

  // Dastur to'liq yuklangach orientation qulfini qayta qo'llash
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _lockLandscapeOrientation();
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => VideoService()),
        ChangeNotifierProvider(create: (_) => AnalyticsService()),
      ],
      child: MaterialApp(
        title: 'Billboard Mobile',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          brightness: Brightness.dark,
          useMaterial3: true,
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper>
    with WidgetsBindingObserver {
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkSavedAuth();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _applyKioskUi();
    }
  }

  Future<void> _checkSavedAuth() async {
    // Проверить сохраненный токен
    final authService = context.read<AuthService>();
    await authService.checkAuth();

    if (mounted) {
      setState(() {
        _isChecking = false;
      });
    }
  }

  // kaireke
  // 719364825g
  @override
  Widget build(BuildContext context) {
    // Показать splash screen пока проверяется токен
    if (_isChecking) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 24),
              Text(
                'Billboard Mobile',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Загрузка...',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return PopScope(
      canPop: false,
      child: Consumer<AuthService>(
        builder: (context, authService, _) {
          if (authService.isAuthenticated) {
            return const VideoPlayerScreen();
          } else {
            return const LoginScreen();
          }
        },
      ),
    );
  }
}
