import '../config/constants.dart';

sealed class QrResult {
  const QrResult();
}

class QrValid extends QrResult {
  final String publicId;
  const QrValid(this.publicId);
}

class QrInvalid extends QrResult {
  final String reason;
  const QrInvalid(this.reason);
}

class QrHandler {
  static const _allowedDomains = ['provenanceverified.org'];
  static const _allowedPaths = ['/verify', '/registry', '/reliance'];
  static const _dangerousSchemes = ['javascript', 'data', 'vbscript', 'ftp', 'file'];

  static QrResult parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const QrInvalid('Empty QR code');
    }
    final trimmed = raw.trim();

    // Reject dangerous schemes immediately.
    final lower = trimmed.toLowerCase();
    for (final s in _dangerousSchemes) {
      if (lower.startsWith('$s:')) return QrInvalid('Unsafe scheme: $s');
    }

    // Check if it looks like a direct PV public ID.
    if (isValidPublicId(trimmed)) {
      return QrValid(trimmed.toUpperCase());
    }

    // Try parsing as URI.
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return const QrInvalid('Unparseable input');

    // pv:// custom scheme.
    if (uri.scheme == 'pv') {
      final segments = uri.pathSegments;
      if (segments.isEmpty) return const QrInvalid('pv:// missing path');
      final candidate = segments.last;
      if (isValidPublicId(candidate)) return QrValid(candidate.toUpperCase());
      return const QrInvalid('pv:// path does not contain valid PV ID');
    }

    // HTTPS only for canonical URLs.
    if (uri.scheme != 'https') {
      return QrInvalid('Unsupported scheme: ${uri.scheme}. Only https:// and pv:// are allowed.');
    }

    // Domain validation.
    final host = uri.host.toLowerCase();
    if (!_allowedDomains.contains(host)) {
      return QrInvalid('Untrusted domain: $host. Only ${_allowedDomains.join(', ')} are trusted.');
    }

    // Path must start with an allowed prefix.
    final path = uri.path;
    final pathOk = _allowedPaths.any((p) => path.startsWith(p));
    if (!pathOk) {
      return const QrInvalid('URL path not in allowed list: /verify, /registry, /reliance');
    }

    // Extract ID: from path segment or query param.
    String? candidate;
    final segments = uri.pathSegments;
    for (final seg in segments.reversed) {
      if (isValidPublicId(seg)) {
        candidate = seg;
        break;
      }
    }
    candidate ??= uri.queryParameters['id'];

    if (candidate == null || !isValidPublicId(candidate)) {
      return const QrInvalid('No valid PV ID found in URL');
    }
    return QrValid(candidate.toUpperCase());
  }

  static bool isValidPublicId(String? id) {
    if (id == null || id.isEmpty) return false;
    final normalized = id.toUpperCase();
    return PvConstants.publicIdPattern.hasMatch(normalized);
  }
}
