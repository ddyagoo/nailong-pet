import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// 查 GitHub Releases 最新版本（Windows 原生版用）。
///
/// Android 走 Kotlin 那份，逻辑一样，两边都读同一个仓库。
class UpdateInfo {
  const UpdateInfo({
    required this.hasUpdate,
    required this.tag,
    required this.current,
    required this.url,
    required this.notes,
  });

  final bool hasUpdate;
  final String tag;
  final String current;
  final String url;
  final String notes;
}

class UpdateService {
  static const repo = 'ddyagoo/nailong-pet';
  static const _api = 'https://api.github.com/repos/$repo/releases/latest';
  static const _releases = 'https://github.com/$repo/releases';

  /// 网络失败返回 null，调用方按「检查失败」处理。
  static Future<UpdateInfo?> check() async {
    try {
      final res = await http.get(
        Uri.parse(_api),
        headers: const {
          'User-Agent': 'nailong-pet',
          'Accept': 'application/vnd.github+json',
        },
      ).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;

      final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final tag = (json['tag_name'] as String? ?? '').trim();
      final url = json['html_url'] as String? ?? _releases;
      final notes = (json['body'] as String? ?? '').trim();
      final info = await PackageInfo.fromPlatform();
      final current = info.version;

      return UpdateInfo(
        hasUpdate: tag.isNotEmpty && _isNewer(tag, current),
        tag: tag,
        current: current,
        url: url,
        notes: notes,
      );
    } catch (_) {
      return null;
    }
  }

  /// `v0.2.0` 比 `0.1.9` 新；比较前先去掉前缀和非数字尾巴。
  static bool _isNewer(String tag, String current) {
    List<int> parse(String v) {
      final clean = v.replaceFirst(RegExp(r'^[vV]'), '').split('+').first;
      return clean
          .split('.')
          .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
          .toList();
    }

    final a = parse(tag);
    final b = parse(current);
    for (var i = 0; i < 3; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  static Future<void> openReleasePage(UpdateInfo info) async {
    final uri = Uri.tryParse(info.url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
