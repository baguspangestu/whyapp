import 'package:flutter/material.dart';

import '../../../../core/utils/date_time_utils.dart';
import '../../domain/entities/chat_message.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mine = message.isMine;
    final textColor = isDark ? const Color(0xFFE9EDEF) : const Color(0xFF111B21);
    final metaColor = mine
        ? (isDark ? const Color(0xFFB6C4C9) : const Color(0xFF667781))
        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.85);
    final incomingColor = isDark
        ? const Color(0xFF202C3B)
        : Colors.white;
    final outgoingColor = isDark
        ? const Color(0xFF6B1D3A)
        : const Color(0xFFFCE4EC);

    return Semantics(
      label: mine
          ? 'Your message: ${message.content}'
          : '${message.senderName}: ${message.content}',
      child: Padding(
        padding: EdgeInsets.only(
          top: 3,
          bottom: 5,
          left: mine ? 58 : 6,
          right: mine ? 6 : 58,
        ),
        child: Row(
          mainAxisAlignment: mine
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(10, 7, 8, 5),
                    decoration: BoxDecoration(
                      color: mine ? outgoingColor : incomingColor,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(mine ? 9 : 2),
                        topRight: Radius.circular(mine ? 2 : 9),
                        bottomLeft: const Radius.circular(9),
                        bottomRight: const Radius.circular(9),
                      ),
                      border: mine
                          ? null
                          : Border.all(
                              color: theme.colorScheme.outlineVariant
                                  .withValues(alpha: isDark ? 0.25 : 0.5),
                            ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.18 : 0.07,
                          ),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(
                          message.content,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: textColor,
                            height: 1.28,
                            letterSpacing: 0.05,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              DateTimeUtils.formatTime(message.createdAt),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: metaColor,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (mine) ...[
                              const SizedBox(width: 4),
                              Icon(
                                message.status == 'SENDING'
                                    ? Icons.schedule_rounded
                                    : message.status == 'FAILED'
                                    ? Icons.error_outline_rounded
                                    : message.isDelivered
                                    ? Icons.done_all_rounded
                                    : Icons.done_rounded,
                                size: 15,
                                color: message.status == 'FAILED'
                                    ? Theme.of(context).colorScheme.error
                                    : message.isRead
                                    ? const Color(0xFF53BDEB)
                                    : metaColor,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 1,
                    left: mine ? null : -5,
                    right: mine ? -5 : null,
                    child: CustomPaint(
                      size: const Size(9, 12),
                      painter: _BubbleTailPainter(
                        color: mine ? outgoingColor : incomingColor,
                        pointsRight: mine,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  const _BubbleTailPainter({required this.color, required this.pointsRight});

  final Color color;
  final bool pointsRight;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (pointsRight) {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height * 0.72);
    } else {
      path
        ..moveTo(size.width, 0)
        ..lineTo(0, size.height)
        ..lineTo(size.width, size.height * 0.72);
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _BubbleTailPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.pointsRight != pointsRight;
  }
}
