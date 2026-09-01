import 'package:flutter/material.dart';

class PresenceAvatar extends StatelessWidget {
  const PresenceAvatar({
    super.key,
    required this.name,
    required this.isOnline,
    this.isIdle = false,
    this.imageUrl,
    this.radius = 22,
  });

  final String name;
  final bool isOnline;
  final bool isIdle;
  final String? imageUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final validImage = imageUrl != null && imageUrl!.trim().isNotEmpty;

    return Semantics(
      label: '$name is ${isIdle ? 'idle' : isOnline ? 'online' : 'offline'}',
      child: SizedBox.square(
        dimension: radius * 2,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: radius,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              foregroundImage: validImage ? NetworkImage(imageUrl!) : null,
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: radius * 0.72,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: radius * 0.48,
                height: radius * 0.48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isIdle
                      ? const Color(0xFFF59E0B)
                      : isOnline
                      ? const Color(0xFF22C55E)
                      : const Color(0xFF94A3B8),
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2.5,
                  ),
                  boxShadow: isOnline
                      ? [
                          BoxShadow(
                            color: (isIdle
                                    ? const Color(0xFFF59E0B)
                                    : const Color(0xFF22C55E))
                                .withValues(alpha: 0.35),
                            blurRadius: 6,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
