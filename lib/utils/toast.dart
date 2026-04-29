import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

void Toast(BuildContext context, String message, bool isSuccess) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) {
    return;
  }

  final backgroundColor = isSuccess ? AppColors.success : AppColors.error;
  final icon = isSuccess ? Icons.check_circle_rounded : Icons.error_rounded;

  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        backgroundColor: backgroundColor,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
}
