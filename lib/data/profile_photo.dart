import 'dart:collection';
import 'dart:convert';

import 'package:flutter/painting.dart';

/// Where a profile photo lives depends on the platform:
///
/// * Android / iOS: a JPEG copied into the app documents directory, stored
///   as its file path.
/// * Web: there is no file system, so the (already downscaled) picked image
///   is stored inline as a `data:image/...;base64,...` URL, which persists in
///   the browser's local storage along with the rest of the account.
///
/// These helpers handle the inline form. They work on every platform, so a
/// data URL always renders, wherever it came from.
class ProfilePhoto {
  ProfilePhoto._();

  /// Largest picked image accepted on the web (after the picker's resize).
  /// Keeps the account record well inside the browser's ~5 MB local storage.
  static const maxInlineBytes = 1536 * 1024;

  /// Whether [photo] is an inline data URL rather than a file path.
  static bool isDataUrl(String? photo) => photo != null && photo.startsWith('data:');

  /// `data:<mime>;base64,<bytes>`. Unknown or non-image types are labelled
  /// JPEG (the decoder sniffs the real format from the bytes anyway).
  static String toDataUrl(List<int> bytes, {String? mimeType}) {
    final mime = (mimeType != null && mimeType.startsWith('image/')) ? mimeType : 'image/jpeg';
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }

  // Decoded providers for the last few data URLs, most recently used last.
  // Rebuilding an avatar then reuses the same MemoryImage (and so the same
  // entry in Flutter's image cache) instead of decoding base64 every build.
  static const _cacheSize = 4;
  static final LinkedHashMap<String, MemoryImage> _providers = LinkedHashMap();

  /// An image provider for a base64 data URL, or null if [dataUrl] is not
  /// one or is malformed.
  static MemoryImage? imageFor(String dataUrl) {
    final hit = _providers.remove(dataUrl);
    if (hit != null) {
      _providers[dataUrl] = hit;
      return hit;
    }
    final comma = dataUrl.indexOf(',');
    if (!isDataUrl(dataUrl) || comma == -1 || !dataUrl.substring(0, comma).endsWith(';base64')) return null;
    try {
      final bytes = base64Decode(dataUrl.substring(comma + 1));
      if (bytes.isEmpty) return null;
      final provider = MemoryImage(bytes);
      _providers[dataUrl] = provider;
      while (_providers.length > _cacheSize) {
        _providers.remove(_providers.keys.first);
      }
      return provider;
    } on FormatException {
      return null;
    }
  }
}
