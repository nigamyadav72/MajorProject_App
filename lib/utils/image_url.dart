import '../config/app_config.dart';

String resolveImageUrl(String? path) {
  if (path == null || path.isEmpty) return '';
  if (path.startsWith('http://') || path.startsWith('https://')) return path;
  const base = AppConfig.backendBaseUrl;
  final p = path.startsWith('/') ? path : '/$path';
  return base.endsWith('/') ? '$base${p.substring(1)}' : '$base$p';
}
