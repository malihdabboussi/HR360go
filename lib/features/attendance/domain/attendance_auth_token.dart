const planBNoJwtMessage =
    'Plan B disabled: no compact JWT available for Lambda authorization.';

final _jwtSegmentPattern = RegExp(r'^[A-Za-z0-9_-]+$');

bool isCompactJwt(String? token) {
  if (token == null || token.isEmpty) return false;
  final trimmed = token.trim();
  if (trimmed.length < 20) return false;
  if (trimmed.startsWith('{') || trimmed.startsWith('[')) return false;
  final parts = trimmed.split('.');
  if (parts.length != 3) return false;
  return parts.every((p) => p.isNotEmpty && _jwtSegmentPattern.hasMatch(p));
}

String? resolveCompactJwtForPlanB(String? token) {
  if (!isCompactJwt(token)) return null;
  return token!.trim();
}
