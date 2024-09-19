import 'package:flutter/material.dart';

class EducationalModules extends StatelessWidget {
  const EducationalModules({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Educational Modules on Nutrition and Childcare:',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Card(
          child: ListTile(
            title: const Text('Balanced Diet'),
            subtitle:
                const Text('Learn how to create a balanced diet for children.'),
            onTap: () {
              // Add navigation or educational content
            },
          ),
        ),
        Card(
          child: ListTile(
            title: const Text('Proper Feeding Practices'),
            subtitle:
                const Text('Understand the right way to feed young children.'),
            onTap: () {
              // Add navigation or educational content
            },
          ),
        ),
        // Add more modules as needed
      ],
    );
  }
}
