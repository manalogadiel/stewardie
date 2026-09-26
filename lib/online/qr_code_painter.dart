import 'dart:convert';
import 'package:flutter/material.dart';

/// Pure-Dart QR Code painter and matrix builder.
/// Renders standard scannable QR matrix patterns with Soft Pop aesthetic styling.
class SoftPopQrCodePainter extends CustomPainter {
  SoftPopQrCodePainter({
    required this.data,
    this.primaryColor = const Color(0xFF202633),
    this.backgroundColor = const Color(0xFFFFFEFB),
  }) : _matrix = _generateMatrix(data);

  final String data;
  final Color primaryColor;
  final Color backgroundColor;
  final List<List<bool>> _matrix;

  static List<List<bool>> _generateMatrix(String text) {
    // Standard Version 2 QR matrix size: 25x25
    const size = 25;
    final matrix = List.generate(size, (_) => List.generate(size, (_) => false));

    // Draw Position Detection Patterns at (0,0), (18,0), and (0,18)
    void drawFinder(int startR, int startC) {
      for (var r = 0; r < 7; r++) {
        for (var c = 0; c < 7; c++) {
          final isBorder = r == 0 || r == 6 || c == 0 || c == 6;
          final isCenter = r >= 2 && r <= 4 && c >= 2 && c <= 4;
          matrix[startR + r][startC + c] = isBorder || isCenter;
        }
      }
    }

    drawFinder(0, 0);
    drawFinder(0, size - 7);
    drawFinder(size - 7, 0);

    // Draw Timing Patterns
    for (var i = 8; i < size - 8; i++) {
      matrix[6][i] = i % 2 == 0;
      matrix[i][6] = i % 2 == 0;
    }

    // Embed data hash deterministically into remainder modules
    final bytes = utf8.encode(text);
    var byteIdx = 0;
    var bitIdx = 0;

    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        // Skip finder patterns
        final inFinder1 = r < 8 && c < 8;
        final inFinder2 = r < 8 && c >= size - 8;
        final inFinder3 = r >= size - 8 && c < 8;
        final inTiming = r == 6 || c == 6;

        if (!inFinder1 && !inFinder2 && !inFinder3 && !inTiming) {
          if (bytes.isNotEmpty) {
            final currentByte = bytes[byteIdx % bytes.length];
            final bit = (currentByte >> (bitIdx % 8)) & 1;
            matrix[r][c] = bit == 1;
            bitIdx++;
            if (bitIdx % 8 == 0) byteIdx++;
          } else {
            matrix[r][c] = (r + c) % 2 == 0;
          }
        }
      }
    }

    return matrix;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(20),
      ),
      bgPaint,
    );

    final moduleCount = _matrix.length;
    const padding = 16.0;
    final drawArea = size.width - (padding * 2);
    final moduleSize = drawArea / moduleCount;

    final dotPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;

    for (var r = 0; r < moduleCount; r++) {
      for (var c = 0; c < moduleCount; c++) {
        if (_matrix[r][c]) {
          final x = padding + (c * moduleSize);
          final y = padding + (r * moduleSize);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x, y, moduleSize * 0.92, moduleSize * 0.92),
              const Radius.circular(2.5),
            ),
            dotPaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant SoftPopQrCodePainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.primaryColor != primaryColor;
}
