import 'package:flutter/material.dart';
import '../widgets/navbar.dart';
import '../widgets/sidebar.dart';
import '../widgets/footer.dart';
import 'educational_modules.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const Navbar(),
      drawer: const Sidebar(),
      body: Center(
        child: Column(
          children: const [
            Text(
              'E-Afya Dashboard',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            EducationalModules(),
          ],
        ),
      ),
      bottomNavigationBar: const Footer(),
    );
  }
}
