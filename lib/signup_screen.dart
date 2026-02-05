import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'widgets/recaptcha_v2_widget.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _captchaToken;
  String _selectedRole = 'buyer'; // 'buyer' or 'seller'

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    if (_captchaToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete the reCAPTCHA')),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final result = await auth.signUpWithEmail(
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      recaptchaToken: _captchaToken,
      role: _selectedRole,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created! Please login.')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error'] ?? 'Signup failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Consumer<AuthProvider>(
                builder: (context, auth, _) {
                  return Card(
                    elevation: 14,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              "Create Account",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _usernameController,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.person_outline),
                                labelText: "Username",
                                hintText: "e.g., John Doe or john_doe",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Enter username';
                                }
                                if (val.length > 150) {
                                  return 'Username is too long (max 150 characters)';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.email_outlined),
                                labelText: "Email",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              validator: (val) => val!.contains('@')
                                  ? null
                                  : 'Enter valid email',
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.lock_outline),
                                labelText: "Password",
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility),
                                  onPressed: () => setState(
                                      () => _obscurePassword = !_obscurePassword),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              validator: (val) => val!.length >= 6
                                  ? null
                                  : 'Password must be 6+ characters',
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirm,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.lock_outline),
                                labelText: "Confirm Password",
                                suffixIcon: IconButton(
                                  icon: Icon(_obscureConfirm
                                      ? Icons.visibility_off
                                      : Icons.visibility),
                                  onPressed: () => setState(
                                      () => _obscureConfirm = !_obscureConfirm),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              validator: (val) => val == _passwordController.text
                                  ? null
                                  : 'Passwords do not match',
                            ),
                            const SizedBox(height: 16),

                            // Role Selection
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "I am a:",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setState(() => _selectedRole = 'buyer'),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: _selectedRole == 'buyer' ? const Color(0xFF2575FC).withOpacity(0.1) : Colors.transparent,
                                        border: Border.all(
                                          color: _selectedRole == 'buyer' ? const Color(0xFF2575FC) : Colors.grey.shade300,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.shopping_bag_outlined,
                                            size: 18,
                                            color: _selectedRole == 'buyer' ? const Color(0xFF2575FC) : Colors.grey,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            "Buyer",
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: _selectedRole == 'buyer' ? FontWeight.bold : FontWeight.normal,
                                              color: _selectedRole == 'buyer' ? const Color(0xFF2575FC) : Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setState(() => _selectedRole = 'seller'),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: _selectedRole == 'seller' ? const Color(0xFF2575FC).withOpacity(0.1) : Colors.transparent,
                                        border: Border.all(
                                          color: _selectedRole == 'seller' ? const Color(0xFF2575FC) : Colors.grey.shade300,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.storefront_outlined,
                                            size: 18,
                                            color: _selectedRole == 'seller' ? const Color(0xFF2575FC) : Colors.grey,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            "Seller",
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: _selectedRole == 'seller' ? FontWeight.bold : FontWeight.normal,
                                              color: _selectedRole == 'seller' ? const Color(0xFF2575FC) : Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),
                            // Visible reCAPTCHA v2 Checkbox
                            RecaptchaV2Widget(
                              siteKey: "6LfHFYUrAAAAACVr6Xq3VHKv4VJlaYSJgQ9uWCQE", 
                              onVerified: (token) {
                                debugPrint("✅ Verified! Token captured.");
                                setState(() {
                                  _captchaToken = token;
                                });
                              },
                              onError: (err) {
                                debugPrint("❌ reCAPTCHA Error: $err");
                              },
                            ),

                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: auth.isSignupLoading ? null : _handleSignUp,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2575FC),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: auth.isSignupLoading
                                    ? const CircularProgressIndicator(
                                        color: Colors.white)
                                    : const Text(
                                        "Sign Up",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text("Already have an account?"),
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text(
                                    "Login",
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
