import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.brand,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Spacer(),
              Icon(Icons.landscape, color: Colors.white, size: 72),
              SizedBox(height: 16),
              Text(
                'الأوتاد',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'للمبيعات',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 20),
              ),
              SizedBox(height: 8),
              Text(
                'AWTAD RETAIL',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white54,
                  letterSpacing: 2,
                ),
              ),
              Spacer(),
              Text(
                'إدارة متجرك ... بكل سهولة',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PreparingDatabaseScreen extends StatelessWidget {
  const PreparingDatabaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  const CircleAvatar(
                    radius: 56,
                    backgroundColor: AppTheme.mintSurface,
                    child: Icon(
                      Icons.storage,
                      size: 48,
                      color: AppTheme.brand,
                    ),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: AppTheme.brandSoft,
                      child: const Icon(
                        Icons.check,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'جاري تهيئة قاعدة البيانات',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'جاري إعداد قاعدة البيانات المحلية للتأكد من جاهزيتها للاستخدام.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              const LinearProgressIndicator(color: AppTheme.brand),
              const SizedBox(height: 12),
              const Text('قد تستغرق هذه العملية بضع لحظات ...'),
            ],
          ),
        ),
      ),
    );
  }
}

class DatabaseFailureScreen extends StatelessWidget {
  const DatabaseFailureScreen({
    super.key,
    required this.onRetry,
    this.details,
  });

  final VoidCallback onRetry;
  final String? details;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            const CircleAvatar(
              radius: 40,
              backgroundColor: Color(0xFFFFEBEE),
              child: Icon(
                Icons.error_outline,
                color: AppTheme.errorAccent,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'فشل تهيئة قاعدة البيانات',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'تعذر تهيئة قاعدة البيانات المحلية. يرجى التحقق من مساحة التخزين وإعادة المحاولة.',
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            FilledButton(
              onPressed: onRetry,
              child: const Text('إعادة المحاولة'),
            ),
            if (details != null)
              TextButton(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('تفاصيل'),
                      content: Text(details!),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('إغلاق'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('مزيد من التفاصيل'),
              ),
          ],
        ),
      ),
    );
  }
}
