// lib/screens/animated_loading_screen.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class AnimatedLoadingScreen extends StatefulWidget {
  final Widget nextScreen;

  const AnimatedLoadingScreen({Key? key, required this.nextScreen}) : super(key: key);

  @override
  _AnimatedLoadingScreenState createState() => _AnimatedLoadingScreenState();
}

class _AnimatedLoadingScreenState extends State<AnimatedLoadingScreen> with TickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    // Navigue vers l'écran suivant après 3 secondes
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => widget.nextScreen),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildDot(int index) {
    // Calcul corrigé pour l'animation
    final begin = index * 0.1;
    final end = begin + 0.4;

    return FadeTransition(
      opacity: Tween(begin: 0.2, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          // L'Interval doit avoir une valeur 'end' qui ne dépasse pas 1.0
          curve: Interval(begin, end < 1.0 ? end : 1.0, curve: Curves.easeInOut),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5),
        width: 12,
        height: 12,
        decoration: const BoxDecoration(
          color: Colors.blue, // Couleur des points
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Image.asset(
              'assets/icon/Logososelectricityapp.jpg',
              width: 120,
              height: 120,
            ),
            const SizedBox(height: 50),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) => _buildDot(index)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}