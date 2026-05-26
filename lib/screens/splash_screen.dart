import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fasum_nelson/screens/sign_in_screen.dart';
import 'package:fasum_nelson/screens/home_screen.dart';
import 'package:flutter/material.dart';

class SplashScreens extends StatefulWidget {
  const SplashScreens({super.key});
  @override
  State<SplashScreens> createState() => _SplashScreensState();
}

class _SplashScreensState extends State<SplashScreens>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _Animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _Animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
    _controller.forward();
    Timer(const Duration(seconds: 3), () {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_)=> const HomeScreen()));
      } else {
        Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_)=> const SignInScreen()));
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[50],
      body: Center(
        child: FadeTransition(
          opacity: _Animation,
          child: Image.asset(
            'assets/fasum_icon.png',
            width: 150,
            height: 150,
          ),
        ),
      ),
    );
  }
}