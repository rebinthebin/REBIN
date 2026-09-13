import 'package:flutter/material.dart';

class GamesScreen extends StatelessWidget {
  const GamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Oyunlar'),
      ),
      body: const Center(
        child: Text(
          'Geri dönüşüm temalı eğitici oyunlar burada yer alacak.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      ),
    );
  }
}
