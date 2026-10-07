import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:page_transition/page_transition.dart';
import 'package:animated_splash_screen/animated_splash_screen.dart';

// Import common providers
import 'common/providers/theme_provider.dart';
import 'common/providers/liked_gifs_provider.dart';
import 'common/providers/viewed_gifs_provider.dart';
import 'common/providers/view_mode_provider.dart';
import 'common/providers/mood_vibe_view_mode_provider.dart';
import 'common/utils/shared_preferences_util.dart';
import 'data/local/legacy_preferences_migration.dart';
import 'data/local/local_database.dart';
import 'data/local/local_media_repository.dart';
import 'data/cache/media_cache_manager.dart';
import 'data/cache/collection_share_service.dart';

// Import screens
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize shared preferences
  final sharedPreferences = await SharedPreferences.getInstance();
  SharedPreferencesUtil.init(sharedPreferences);

  // Initialize durable media/collection storage before UI state loads.
  // SharedPreferences remains available for lightweight settings and is
  // migrated into SQLite once without deleting the legacy source data.
  final localDatabase = LocalDatabase.open();
  await localDatabase.initialize();
  final localMediaRepository = LocalMediaRepository(localDatabase);
  final mediaCacheManager = MediaCacheManager(localMediaRepository);
  await LegacyPreferencesMigration(localDatabase, localMediaRepository)
      .run(sharedPreferences);

  // Initialize theme mode
  final themeProvider = ThemeProvider();
  await themeProvider.loadThemeMode();

  // Initialize liked gifs provider
  final likedGifsProvider = LikedGifsProvider(localMediaRepository);
  await likedGifsProvider.loadLikedGifs();

  // Initialize viewed gifs provider
  final viewedGifsProvider = ViewedGifsProvider(localMediaRepository);
  await viewedGifsProvider.loadViewedGifs();

  // Initialize view mode providers
  final viewModeProvider = ViewModeProvider();
  final moodVibeViewModeProvider = MoodVibeViewModeProvider();
  moodVibeViewModeProvider.loadViewMode();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => themeProvider),
        ChangeNotifierProvider(create: (_) => likedGifsProvider),
        ChangeNotifierProvider(create: (_) => viewedGifsProvider),
        ChangeNotifierProvider(create: (_) => viewModeProvider),
        ChangeNotifierProvider(create: (_) => moodVibeViewModeProvider),
        Provider<LocalMediaRepository>.value(value: localMediaRepository),
        Provider<MediaCacheManager>.value(
          value: mediaCacheManager,
        ),
        Provider<CollectionShareService>.value(
          value: CollectionShareService(
            localMediaRepository,
            cacheManager: mediaCacheManager,
          ),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp(
          title: 'GIF Play',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          debugShowCheckedModeBanner: false,
          home: const SplashScreen(),
        );
      },
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final backgroundColor = isDark 
        ? AppTheme.darkTheme.colorScheme.background 
        : AppTheme.lightTheme.colorScheme.background;
        
    return AnimatedSplashScreen(
      splash: SplashContent(isDarkMode: isDark),
      nextScreen: const LoginScreen(),
      splashTransition: SplashTransition.fadeTransition,
      backgroundColor: backgroundColor,
      duration: 3000,
      animationDuration: const Duration(milliseconds: 1000),
      pageTransitionType: PageTransitionType.fade,
      splashIconSize: 250,
    );
  }
}

class SplashContent extends StatefulWidget {
  final bool isDarkMode;

  const SplashContent({Key? key, required this.isDarkMode}) : super(key: key);

  @override
  State<SplashContent> createState() => _SplashContentState();
}

class _SplashContentState extends State<SplashContent> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
      ),
    );
    
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.8, curve: Curves.easeIn),
      ),
    );
    
    _rotateAnimation = Tween<double>(begin: 0.0, end: 2 * 3.14159).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeInOut),
      ),
    );
    
    // Ensure animation starts immediately
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.isDarkMode 
        ? AppTheme.darkTheme.colorScheme.primary 
        : AppTheme.lightTheme.colorScheme.primary;
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App logo with animation
              Transform.scale(
                scale: _scaleAnimation.value,
                child: Transform.rotate(
                  angle: _rotateAnimation.value * 0.1,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: Image.asset(
                        'assets/images/app_icon.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Opacity(
                opacity: _opacityAnimation.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'GIF Play',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: widget.isDarkMode ? Colors.white : Colors.black,
                        letterSpacing: 2,
                        shadows: [
                          Shadow(
                            color: primaryColor.withOpacity(0.5),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Explore & Share Amazing GIFs',
                      style: TextStyle(
                        fontSize: 14,
                        color: widget.isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

