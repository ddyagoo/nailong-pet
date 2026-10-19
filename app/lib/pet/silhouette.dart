import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 奶龙的剪影：从 idle 首帧的 alpha 抠出来的一列列矩形。
///
/// 用来把窗口区域裁成「跟着身形走」的形状，这样奶龙左右两侧的透明区也能
/// 点穿到桌面，而不是被一个长方形挡住。
class Silhouette {
  const Silhouette(this.columns);

  /// 每列一个矩形，坐标是 0..1 的图片归一化坐标。
  final List<Rect> columns;

  /// 解码一张首帧，按列扫出上下边界。
  static Future<Silhouette?> load(String asset, {int columns = 40}) async {
    try {
      final data = await rootBundle.load(asset);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: 280,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (bytes == null) {
        image.dispose();
        codec.dispose();
        return null;
      }

      final w = image.width;
      final h = image.height;
      final raw = bytes.buffer.asUint8List();
      final rects = <Rect>[];
      final colW = (w / columns).ceil();

      for (var c = 0; c < columns; c++) {
        var minY = h;
        var maxY = -1;
        final x0 = c * colW;
        final x1 = (x0 + colW).clamp(0, w);
        for (var x = x0; x < x1; x++) {
          for (var y = 0; y < h; y++) {
            final alpha = raw[(y * w + x) * 4 + 3];
            if (alpha > 40) {
              if (y < minY) minY = y;
              if (y > maxY) maxY = y;
            }
          }
        }
        if (maxY >= minY) {
          rects.add(Rect.fromLTRB(
            c / columns,
            minY / h,
            (c + 1) / columns,
            (maxY + 1) / h,
          ));
        }
      }

      image.dispose();
      codec.dispose();
      return rects.isEmpty ? null : Silhouette(rects);
    } catch (_) {
      return null;
    }
  }

  /// 把剪影铺到 [box]（奶龙在窗口里的矩形）上。
  ///
  /// [scale] 围绕底边中点放大，给 Q 弹留余量；[padX]/[padY] 按 box 尺寸的比例
  /// 往外补一点，盖住列扫描的锯齿（不然屁股/头顶会各被切掉一两个像素）。
  List<Rect> toRects(
    Rect box, {
    double scale = 1.26,
    double padX = 0.012,
    double padY = 0.02,
  }) {
    final cx = box.center.dx;
    final bottom = box.bottom;

    Offset map(Offset p) {
      final x = cx + (p.dx - cx) * scale;
      final y = bottom + (p.dy - bottom) * scale;
      return Offset(x, y);
    }

    final dx = box.width * padX;
    final dy = box.height * padY;

    return [
      for (final c in columns)
        Rect.fromPoints(
          map(Offset(box.left + c.left * box.width - dx / scale,
              box.top + c.top * box.height - dy / scale)),
          map(Offset(box.left + c.right * box.width + dx / scale,
              box.top + c.bottom * box.height + dy / scale)),
        ),
    ];
  }
}
