import 'package:flutter/material.dart';

/// A small, custom-drawn cow-head glyph.
///
/// No cow icon exists in Flutter's Material icon set — `Icons.sync_alt`
/// (previously used as a Cow stand-in on the score badges) reads as
/// "compare/exchange arrows", not a cow — and no cow-head image asset lives
/// under `assets/`. Drawn as a single-tone silhouette (ears, horns, head,
/// muzzle, with two nostril "holes" cut via [Path.combine]) so it stays
/// legible tinted any accent color on any background, matching how [Icon]
/// renders a built-in [IconData] at the same small sizes.
class CowHeadIcon extends StatelessWidget {
  const CowHeadIcon({super.key, this.size = 16, this.color});

  /// The glyph's width and height; drawn to exactly fill this square.
  final double size;

  /// Defaults to the ambient [IconTheme] color, matching [Icon]'s own
  /// default-color behavior.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? IconTheme.of(context).color ?? Colors.black;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _CowHeadPainter(color: resolvedColor)),
    );
  }
}

class _CowHeadPainter extends CustomPainter {
  _CowHeadPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // All geometry below is authored against a fixed 24x24 viewbox, then
    // scaled to whatever square [size] the icon is actually rendered at.
    final scale = size.shortestSide / 24;
    canvas.save();
    canvas.scale(scale);

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final hornPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final leftEar = Path()..addOval(const Rect.fromLTWH(1.5, 7.5, 6, 7.5));
    final rightEar = Path()..addOval(const Rect.fromLTWH(16.5, 7.5, 6, 7.5));

    final face = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(5, 8.5, 14, 10),
          const Radius.circular(4.5),
        ),
      );
    final muzzle = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(6, 15, 12, 6.5),
          const Radius.circular(3.2),
        ),
      );

    var silhouette = Path.combine(PathOperation.union, leftEar, rightEar);
    silhouette = Path.combine(PathOperation.union, silhouette, face);
    silhouette = Path.combine(PathOperation.union, silhouette, muzzle);

    final nostrils = Path()
      ..addOval(const Rect.fromLTWH(8.6, 17.4, 1.9, 2.4))
      ..addOval(const Rect.fromLTWH(13.5, 17.4, 1.9, 2.4));
    silhouette = Path.combine(PathOperation.difference, silhouette, nostrils);

    canvas.drawPath(silhouette, fillPaint);

    final leftHorn = Path()
      ..moveTo(6.2, 8.6)
      ..quadraticBezierTo(3.2, 6.4, 3.6, 2.6);
    final rightHorn = Path()
      ..moveTo(17.8, 8.6)
      ..quadraticBezierTo(20.8, 6.4, 20.4, 2.6);
    canvas.drawPath(leftHorn, hornPaint);
    canvas.drawPath(rightHorn, hornPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CowHeadPainter oldDelegate) =>
      oldDelegate.color != color;
}
