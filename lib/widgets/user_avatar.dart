import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../data/profile_photo.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// The one avatar used everywhere for the current user: their chosen photo,
/// otherwise their initials, or a person icon for guests.
///
/// Pass [profile] to preview an unsaved profile (Edit Profile); by default
/// the signed-in user from [AppState] is shown.
class UserAvatar extends StatelessWidget {
  final double size;
  final UserProfile? profile;
  const UserAvatar({super.key, this.size = 56, this.profile});

  @override
  Widget build(BuildContext context) {
    final user = profile ?? context.select<AppState, UserProfile?>((s) => s.user);
    final ring = size >= 80 ? 2.0 : 1.4;

    Widget inner;
    if (user == null) {
      inner = Container(
        color: AppColors.chip,
        alignment: Alignment.center,
        child: Icon(Icons.person_outline_rounded, size: size * 0.54, color: AppColors.goldText),
      );
    } else {
      final initials = _Initials(text: user.initials, size: size);
      final path = user.photoPath;
      // Web stores the photo inline as a data URL (see ProfilePhoto); phones
      // store a file path.
      final inline = ProfilePhoto.isDataUrl(path) ? ProfilePhoto.imageFor(path!) : null;
      if (inline != null) {
        inner = Image(
          image: inline,
          fit: BoxFit.cover,
          width: size,
          height: size,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => initials,
        );
      } else {
        inner = (path != null && _exists(path))
            ? Image.file(
                File(path),
                fit: BoxFit.cover,
                width: size,
                height: size,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => initials,
              )
            : initials;
      }
    }

    return Semantics(
      label: user == null ? 'Guest profile' : 'Profile photo of ${user.name}',
      image: true,
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(ring),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: user == null ? AppColors.border : AppColors.gold,
        ),
        child: ClipOval(child: SizedBox.expand(child: inner)),
      ),
    );
  }

  static bool _exists(String path) {
    // No file system on the web (and a data URL is never a file).
    if (kIsWeb || ProfilePhoto.isDataUrl(path)) return false;
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }
}

class _Initials extends StatelessWidget {
  final String text;
  final double size;
  const _Initials({required this.text, required this.size});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7E1C28), AppColors.maroonDark],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.2),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            textScaler: TextScaler.noScaling,
            style: T.serif(size * 0.4, color: AppColors.cream, weight: FontWeight.w500, spacing: 0.5),
          ),
        ),
      ),
    );
  }
}
