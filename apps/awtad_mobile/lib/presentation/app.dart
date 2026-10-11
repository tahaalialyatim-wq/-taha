import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/database/retail_session.dart';
import '../core/theme/app_theme.dart';
import 'navigation/app_shell.dart';
import 'screens/splash_screen.dart';

class AwtadApp extends StatefulWidget {
  const AwtadApp({super.key, this.sessionFactory});

  final Future<RetailSession> Function()? sessionFactory;

  @override
  State<AwtadApp> createState() => _AwtadAppState();
}

class _AwtadAppState extends State<AwtadApp> {
  Color _seed = AppTheme.brand;
  bool _dark = false;
  bool _splashing = true;
  bool _loading = true;
  String? _error;
  RetailSession? _session;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) {
        return;
      }
      setState(() => _splashing = false);
      _open();
    });
  }

  Future<void> _open() async {
    _session?.close();
    setState(() {
      _session = null;
      _loading = true;
      _error = null;
    });
    try {
      final factory = widget.sessionFactory ?? RetailSession.openDocuments;
      final session = await factory();
      if (!mounted) {
        session.close();
        return;
      }
      setState(() {
        _session = session;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _session?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'الأوتاد للمبيعات',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light(_seed),
      darkTheme: AppTheme.dark(_seed),
      themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: _home(),
    );
  }

  Widget _home() {
    if (_splashing) {
      return const SplashScreen();
    }
    if (_loading) {
      return const PreparingDatabaseScreen();
    }
    if (_error != null || _session == null) {
      return DatabaseFailureScreen(
        onRetry: _open,
        details: _error,
      );
    }
    return AppShell(
      session: _session!,
      seed: _seed,
      dark: _dark,
      onDarkChanged: (value) => setState(() => _dark = value),
      onSeedChanged: (value) => setState(() => _seed = value),
    );
  }
}
