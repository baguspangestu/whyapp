import 'package:flutter/material.dart';

import '../widgets/register_form.dart';

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: const SafeArea(
        child: Padding(padding: EdgeInsets.all(24), child: RegisterForm()),
      ),
    );
  }
}
