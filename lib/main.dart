import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_state_provider.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AiVisualApp());
}

class AiVisualApp extends StatelessWidget {
  const AiVisualApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppStateProvider(),
      child: Consumer<AppStateProvider>(
        builder: (context, stateProvider, _) {
          return MaterialApp(
            title: 'AI Visual Assistant',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              brightness: Brightness.dark,
              primaryColor: const Color(0xFF1E88E5),
              scaffoldBackgroundColor: const Color(0xFF121212),
              textTheme: const TextTheme(
                bodyLarge: TextStyle(color: Colors.white, fontSize: 18),
                bodyMedium: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              useMaterial3: true,
            ),
            // Dynamic locale based on app state
            locale: Locale(stateProvider.language),
            supportedLocales: const [Locale('en'), Locale('ar')],
            localizationsDelegates:
                const [], // Add GlobalMaterialLocalizations.delegate if needed
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
