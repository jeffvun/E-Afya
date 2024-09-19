import 'package:flutter/material.dart';

class Navbar extends StatelessWidget implements PreferredSizeWidget {
  const Navbar({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('E-Afya'),
      actions: [
        IconButton(
          icon: const Icon(Icons.account_circle),
          onPressed: () {
            // Navigate to profile or settings
          },
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(60);
}
