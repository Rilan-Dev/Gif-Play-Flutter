import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:lottie/lottie.dart';

import '../common/providers/theme_provider.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  
  // Animation controllers
  late AnimationController _backgroundAnimationController;
  late AnimationController _formAnimationController;
  late AnimationController _logoAnimationController;
  
  // Animations
  late Animation<double> _backgroundAnimation;
  late Animation<double> _formSlideAnimation;
  late Animation<double> _formOpacityAnimation;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoRotateAnimation;
  
  // Focus nodes for text fields
  final FocusNode _usernameFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  
  // Field animation states
  bool _usernameHasFocus = false;
  bool _passwordHasFocus = false;

  // Hardcoded credentials
  static const String _validUsername = 'admin';
  static const String _validPassword = 'password';

  @override
  void initState() {
    super.initState();
    
    // Background animation
    _backgroundAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    
    _backgroundAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(
        parent: _backgroundAnimationController,
        curve: Curves.linear,
      ),
    );
    
    // Form animation
    _formAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _formSlideAnimation = Tween<double>(begin: 50, end: 0).animate(
      CurvedAnimation(
        parent: _formAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );
    
    _formOpacityAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _formAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Logo animation
    _logoAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _logoScaleAnimation = Tween<double>(begin: 1, end: 1.1).animate(
      CurvedAnimation(
        parent: _logoAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    
    _logoRotateAnimation = Tween<double>(begin: -0.05, end: 0.05).animate(
      CurvedAnimation(
        parent: _logoAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Start animations
    _formAnimationController.forward();
    
    // Add focus listeners
    _usernameFocus.addListener(_onUsernameFocusChange);
    _passwordFocus.addListener(_onPasswordFocusChange);
  }
  
  void _onUsernameFocusChange() {
    setState(() {
      _usernameHasFocus = _usernameFocus.hasFocus;
    });
  }
  
  void _onPasswordFocusChange() {
    setState(() {
      _passwordHasFocus = _passwordFocus.hasFocus;
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _backgroundAnimationController.dispose();
    _formAnimationController.dispose();
    _logoAnimationController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _login() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      // Add haptic feedback
      HapticFeedback.mediumImpact();

      // Simulate network delay
      Future.delayed(const Duration(seconds: 2), () {
        if (_usernameController.text == _validUsername && 
            _passwordController.text == _validPassword) {
          // Success animation
          HapticFeedback.heavyImpact();
          
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const MainScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                const begin = Offset(0.0, 1.0);
                const end = Offset.zero;
                const curve = Curves.easeOutExpo;
                var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                var offsetAnimation = animation.drive(tween);
                
                var fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
                  CurvedAnimation(parent: animation, curve: const Interval(0.3, 1.0))
                );
                
                return FadeTransition(
                  opacity: fadeAnimation,
                  child: SlideTransition(position: offsetAnimation, child: child),
                );
              },
              transitionDuration: const Duration(milliseconds: 1000),
            ),
          );
        } else {
          setState(() {
            _isLoading = false;
          });
          
          // Error animation
          HapticFeedback.vibrate();
          
          // Shake animation for form
          _shakeForm();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Invalid username or password'),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              action: SnackBarAction(
                label: 'OK',
                textColor: Colors.white,
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              ),
            ),
          );
        }
      });
    }
  }
  
  void _shakeForm() {
    // Create a shake animation controller
    AnimationController shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    
    Animation<double> offsetAnimation = Tween<double>(begin: 0, end: 1)
      .chain(CurveTween(curve: Curves.elasticIn))
      .animate(shakeController)
      ..addListener(() {
        setState(() {});
      });
    
    shakeController.forward();
    
    // Dispose after use
    shakeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        shakeController.dispose();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final size = MediaQuery.of(context).size;
    final isDarkMode = themeProvider.isDarkMode;
    
    return Scaffold(
      body: Stack(
        children: [
          // Animated background
          AnimatedBuilder(
            animation: _backgroundAnimation,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDarkMode
                        ? [
                            const Color(0xFF1A1A2E),
                            const Color(0xFF16213E),
                            const Color(0xFF0F3460),
                            const Color(0xFF1A1A2E),
                          ]
                        : [
                            const Color(0xFFE8F0F9),
                            const Color(0xFFD1E3F8),
                            const Color(0xFFB9D4F7),
                            const Color(0xFFE8F0F9),
                          ],
                    transform: GradientRotation(_backgroundAnimation.value),
                  ),
                ),
                child: CustomPaint(
                  painter: BubblesPainter(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.05)
                        : Colors.blue.withOpacity(0.1),
                    bubbleCount: 20,
                    animation: _backgroundAnimation.value,
                  ),
                ),
              );
            },
          ),
          
          // Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // App logo with animation
                      AnimatedBuilder(
                        animation: Listenable.merge([_logoScaleAnimation, _logoRotateAnimation]),
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _logoScaleAnimation.value,
                            child: Transform.rotate(
                              angle: _logoRotateAnimation.value,
                              child: Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(35),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(35), // Match the container's border radius
                                  child: Image.asset(
                                    'assets/images/app_icon.png',
                                    fit: BoxFit.cover, // Changed to cover to fill the space
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // App name with animated text
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context).colorScheme.secondary,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds),
                        child: const Text(
                          'GIF Play',
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      Text(
                        'Explore and Share Amazing GIFs',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      
                      const SizedBox(height: 50),
                      
                      // Login form with animations
                      AnimatedBuilder(
                        animation: Listenable.merge([_formSlideAnimation, _formOpacityAnimation]),
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, _formSlideAnimation.value),
                            child: Opacity(
                              opacity: _formOpacityAnimation.value,
                              child: Container(
                                width: size.width > 600 ? 500 : double.infinity,
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? Colors.black.withOpacity(0.6)
                                      : Colors.white.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: isDarkMode
                                        ? Colors.white.withOpacity(0.1)
                                        : Colors.black.withOpacity(0.05),
                                    width: 1,
                                  ),
                                ),
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Welcome Back',
                                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: isDarkMode ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                      
                                      const SizedBox(height: 8),
                                      
                                      Text(
                                        'Sign in to continue',
                                        style: TextStyle(
                                          color: isDarkMode ? Colors.white60 : Colors.black54,
                                        ),
                                      ),
                                      
                                      const SizedBox(height: 32),
                                      
                                      // Username field with animation
                                      TweenAnimationBuilder<double>(
                                        tween: Tween<double>(begin: 0, end: _usernameHasFocus ? 1 : 0),
                                        duration: const Duration(milliseconds: 200),
                                        builder: (context, value, child) {
                                          return Container(
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(
                                                color: Color.lerp(
                                                  isDarkMode ? Colors.white30 : Colors.black12,
                                                  Theme.of(context).colorScheme.primary,
                                                  value,
                                                )!,
                                                width: 1 + value,
                                              ),
                                              color: isDarkMode
                                                  ? Colors.black.withOpacity(0.3)
                                                  : Colors.white,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1 * value),
                                                  blurRadius: 8 * value,
                                                  spreadRadius: 2 * value,
                                                ),
                                              ],
                                            ),
                                            child: TextFormField(
                                              controller: _usernameController,
                                              focusNode: _usernameFocus,
                                              decoration: InputDecoration(
                                                labelText: 'Username',
                                                prefixIcon: Icon(
                                                  Icons.person,
                                                  color: Color.lerp(
                                                    isDarkMode ? Colors.white54 : Colors.black45,
                                                    Theme.of(context).colorScheme.primary,
                                                    value,
                                                  ),
                                                ),
                                                border: InputBorder.none,
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                              ),
                                              validator: (value) {
                                                if (value == null || value.isEmpty) {
                                                  return 'Please enter your username';
                                                }
                                                return null;
                                              },
                                              onFieldSubmitted: (_) {
                                                FocusScope.of(context).requestFocus(_passwordFocus);
                                              },
                                            ),
                                          );
                                        },
                                      ),
                                      
                                      const SizedBox(height: 24),
                                      
                                      // Password field with animation
                                      TweenAnimationBuilder<double>(
                                        tween: Tween<double>(begin: 0, end: _passwordHasFocus ? 1 : 0),
                                        duration: const Duration(milliseconds: 200),
                                        builder: (context, value, child) {
                                          return Container(
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(
                                                color: Color.lerp(
                                                  isDarkMode ? Colors.white30 : Colors.black12,
                                                  Theme.of(context).colorScheme.primary,
                                                  value,
                                                )!,
                                                width: 1 + value,
                                              ),
                                              color: isDarkMode
                                                  ? Colors.black.withOpacity(0.3)
                                                  : Colors.white,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1 * value),
                                                  blurRadius: 8 * value,
                                                  spreadRadius: 2 * value,
                                                ),
                                              ],
                                            ),
                                            child: TextFormField(
                                              controller: _passwordController,
                                              focusNode: _passwordFocus,
                                              obscureText: _obscurePassword,
                                              decoration: InputDecoration(
                                                labelText: 'Password',
                                                prefixIcon: Icon(
                                                  Icons.lock,
                                                  color: Color.lerp(
                                                    isDarkMode ? Colors.white54 : Colors.black45,
                                                    Theme.of(context).colorScheme.primary,
                                                    value,
                                                  ),
                                                ),
                                                suffixIcon: IconButton(
                                                  icon: Icon(
                                                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                                    color: isDarkMode ? Colors.white54 : Colors.black45,
                                                  ),
                                                  onPressed: () {
                                                    setState(() {
                                                      _obscurePassword = !_obscurePassword;
                                                    });
                                                  },
                                                ),
                                                border: InputBorder.none,
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                              ),
                                              validator: (value) {
                                                if (value == null || value.isEmpty) {
                                                  return 'Please enter your password';
                                                }
                                                return null;
                                              },
                                              onFieldSubmitted: (_) => _login(),
                                            ),
                                          );
                                        },
                                      ),
                                      
                                      const SizedBox(height: 32),
                                      
                                      // Login button with animation
                                      SizedBox(
                                        width: double.infinity,
                                        height: 56,
                                        child: ElevatedButton(
                                          onPressed: _isLoading ? null : _login,
                                          style: ElevatedButton.styleFrom(
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            elevation: 8,
                                            shadowColor: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                                          ),
                                          child: _isLoading
                                              ? const CircularProgressIndicator()
                                              : const Text(
                                                  'LOGIN',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 1.5,
                                                  ),
                                                ),
                                        ),
                                      ),
                                      
                                      const SizedBox(height: 24),
                                      
                                      // Hint for hardcoded credentials
                                      Center(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: isDarkMode
                                                ? Colors.white.withOpacity(0.1)
                                                : Colors.black.withOpacity(0.05),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            'Hint: Username: admin, Password: password',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDarkMode ? Colors.white70 : Colors.black54,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Theme toggle with animation
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.elasticOut,
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: value,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? Colors.white.withOpacity(0.1)
                                    : Colors.black.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Theme:',
                                    style: TextStyle(
                                      color: isDarkMode ? Colors.white : Colors.black87,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 300),
                                      transitionBuilder: (Widget child, Animation<double> animation) {
                                        return RotationTransition(
                                          turns: animation,
                                          child: ScaleTransition(
                                            scale: animation,
                                            child: child,
                                          ),
                                        );
                                      },
                                      child: Icon(
                                        themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                                        key: ValueKey<bool>(themeProvider.isDarkMode),
                                        color: isDarkMode ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                    onPressed: () {
                                      themeProvider.toggleTheme();
                                      HapticFeedback.lightImpact();
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BubblesPainter extends CustomPainter {
  final Color color;
  final int bubbleCount;
  final double animation;
  
  BubblesPainter({
    required this.color,
    required this.bubbleCount,
    required this.animation,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final random = math.Random(42); // Fixed seed for consistent pattern
    
    for (int i = 0; i < bubbleCount; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = 20 + random.nextDouble() * 60;
      
      // Add some movement based on animation
      final offsetX = math.sin(animation + i * 0.5) * 20;
      final offsetY = math.cos(animation + i * 0.7) * 20;
      
      canvas.drawCircle(
        Offset(x + offsetX, y + offsetY),
        radius,
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant BubblesPainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}

