import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/db/app_database.dart';
import '../shell/home_shell.dart';
import 'auth_service.dart';
import 'biometric_service.dart';
import 'change_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.app, required this.auth, required this.bio});
  final AppDatabase app;
  final AuthService auth;
  final BiometricService bio;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _hide = true, _busy = false;
  String? _error;
  bool _bioReady = false;
  Map<String, Object?>? _lastBioUser;

  @override
  void initState() {
    super.initState();
    _checkBio();
  }

  /// يظهر زر البصمة فقط إذا دعمه الجهاز وكان مفعّلاً لحساب نشط.
  Future<void> _checkBio() async {
    if (!await widget.bio.isSupported()) return;
    final users = await widget.app.db.query('users', where: "status = 'active'");
    for (final u in users) {
      if (await widget.bio.isEnabledFor(u['id'] as String)) {
        if (mounted) setState(() { _bioReady = true; _lastBioUser = u; });
        return;
      }
    }
  }

  Future<void> _submit() async {
    setState(() { _busy = true; _error = null; });
    final r = await widget.auth.login(_user.text, _pass.text);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r.status) {
      case LoginStatus.ok:
        _enter(r.user!);
      case LoginStatus.locked:
        setState(() => _error = 'تم إيقاف الدخول مؤقتاً حتى ${TimeOfDay.fromDateTime(r.lockedUntil!).format(context)}');
      case LoginStatus.suspended:
        setState(() => _error = 'هذا الحساب موقوف');
      case LoginStatus.badCredentials:
        // رسالة واحدة دائماً (عدّاد المحاولات كان يكشف وجود الحساب)
        setState(() => _error = 'اسم المستخدم أو كلمة المرور غير صحيحة');
    }
  }

  Future<void> _bioLogin() async {
    if (_lastBioUser == null) return;
    if (await widget.bio.authenticate()) {
      _enter(_lastBioUser!);
    } else if (mounted) {
      setState(() => _error = 'تعذّر التحقق بالبصمة، استخدم كلمة المرور');
    }
  }

  void _enter(Map<String, Object?> user) {
    final next = user['must_change_password'] == 1
        ? ChangePasswordScreen(app: widget.app, auth: widget.auth, user: user, forced: true, bio: widget.bio)
        : HomeShell(app: widget.app, auth: widget.auth, bio: widget.bio, user: user);
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => next));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SvgPicture.asset('assets/brand/logo.svg', height: 140),
                  const SizedBox(height: 24),
                  TextField(controller: _user, textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'اسم المستخدم', prefixIcon: Icon(Symbols.person))),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _pass, obscureText: _hide, onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور', prefixIcon: const Icon(Symbols.lock),
                      suffixIcon: IconButton(
                          icon: Icon(_hide ? Symbols.visibility : Symbols.visibility_off),
                          onPressed: () => setState(() => _hide = !_hide)),
                    ),
                  ),
                  if (_error != null) Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_error!, style: TextStyle(color: cs.error)),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(onPressed: _busy ? null : _submit, child: const Text('تسجيل الدخول')),
                  if (_bioReady) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _bioLogin,
                      icon: const Icon(Symbols.fingerprint),
                      label: const Text('الدخول بالبصمة'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size(64, 48)),
                    ),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
