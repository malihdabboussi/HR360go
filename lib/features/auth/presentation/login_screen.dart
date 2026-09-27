import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../config/env.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/updates/app_update_dialog.dart';
import '../../../core/widgets/hr360_logo.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _loading = false;
  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _checkingUpdates = false;
  String? _error;
  String? _versionLabel;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final credsStore = ref.read(savedCredentialsStoreProvider);
    final updateService = ref.read(appUpdateServiceProvider);

    final remember = await credsStore.isRememberEnabled();
    final saved = await credsStore.load();
    final version = await updateService.currentVersion();

    if (!mounted) return;
    setState(() {
      _rememberMe = remember || saved != null;
      _versionLabel = version.displayLabel;
      if (saved != null) {
        _emailController.text = saved.email;
        _passwordController.text = saved.password;
      }
    });

    // Silent prompt only when LATEST_APP_VERSION is configured and newer.
    final result = await updateService.checkForUpdates();
    if (!mounted || !result.updateAvailable) return;
    await showAppUpdateDialog(
      context,
      result: result,
      service: updateService,
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      await ref.read(authRepositoryProvider).login(
            email: email,
            password: password,
          );

      final creds = ref.read(savedCredentialsStoreProvider);
      if (_rememberMe) {
        await creds.save(email: email, password: password);
      } else {
        await creds.clear();
      }

      ref.invalidate(sessionProvider);
      if (mounted) context.go('/home');
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _checkForUpdates() async {
    if (_checkingUpdates) return;
    setState(() => _checkingUpdates = true);
    try {
      final service = ref.read(appUpdateServiceProvider);
      final result = await service.checkForUpdates();
      if (!mounted) return;
      if (result.latestConfigured == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Current ${result.current.displayLabel}. '
              'Set LATEST_APP_VERSION in .env to enable update checks.',
            ),
          ),
        );
        return;
      }
      await showAppUpdateDialog(
        context,
        result: result,
        service: service,
        userInitiated: true,
      );
    } finally {
      if (mounted) setState(() => _checkingUpdates = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final shortHeight = MediaQuery.sizeOf(context).height < 700;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppTheme.spaceLg,
                shortHeight ? AppTheme.spaceMd : AppTheme.spaceLg,
                AppTheme.spaceLg,
                AppTheme.spaceLg + bottomInset,
              ),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Center(
                        child: Hr360Logo(
                          width: shortHeight || bottomInset > 0 ? 220 : 300,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        Env.isConfigured
                            ? 'Employee check-in & self-service'
                            : 'Configure API_BASE_URL and AES_KEY_HEX',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppDecorations.muted(context),
                            ),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(labelText: 'Email'),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [
                          AutofillHints.username,
                          AutofillHints.email,
                        ],
                        onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                      ),
                      const SizedBox(height: AppTheme.spaceMd),
                      TextFormField(
                        controller: _passwordController,
                        focusNode: _passwordFocus,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: () {
                              setState(
                                () => _obscurePassword = !_obscurePassword,
                              );
                            },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 4),
                      CheckboxListTile(
                        value: _rememberMe,
                        onChanged: _loading
                            ? null
                            : (v) => setState(() => _rememberMe = v ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(
                          'Remember email & password',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: AppTheme.spaceSm),
                        Text(
                          _error!,
                          style: const TextStyle(color: AppColors.danger),
                        ),
                      ],
                      const SizedBox(height: AppTheme.spaceMd),
                      FilledButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Sign in'),
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: _checkingUpdates ? null : _checkForUpdates,
                        icon: _checkingUpdates
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.system_update_alt, size: 18),
                        label: const Text('Check for updates'),
                      ),
                      if (_versionLabel != null)
                        Text(
                          _versionLabel!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: AppDecorations.muted(context),
                              ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
