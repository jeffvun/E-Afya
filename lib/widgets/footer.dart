import 'package:flutter/material.dart';

class Footer extends StatelessWidget {
  const Footer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[200],
      padding: const EdgeInsets.all(16.0),
      child: const Text(
        'E-Afya © 2024. All rights reserved.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, color: Colors.black),
      ),
    );
  }
}
