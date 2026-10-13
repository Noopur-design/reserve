import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../data/profile_photo.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_gate.dart';
import '../widgets/common.dart';
import '../widgets/user_avatar.dart';
import 'location_screen.dart';
import 'sign_in_screen.dart';

/// Change name, email and profile photo, or delete the account. Photo changes
/// are staged until "Save Changes" so backing out leaves the profile
/// untouched.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final UserProfile? _initial = context.read<AppState>().user;
  late final _name = TextEditingController(text: _initial?.name ?? '');
  late final _email = TextEditingController(text: _initial?.email ?? '');

  /// Newly picked photo, copied into app storage (on the web: held as a data
  /// URL) but not yet saved.
  String? _pendingPhoto;
  bool _removePhoto = false;
  bool _busy = false;
  bool _dirty = false;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(_updateDirty);
    _email.addListener(_updateDirty);
  }

  @override
  void dispose() {
    // Picked but never saved: don't leave the copy lying around.
    if (_pendingPhoto != null) _deleteQuietly(_pendingPhoto);
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  /// Also rebuilds so the initials preview follows the name as it's typed.
  void _updateDirty() {
    final u = _initial;
    final d = u != null &&
        (_name.text.trim() != u.name ||
            _email.text.trim() != u.email ||
            _pendingPhoto != null ||
            _removePhoto);
    if (mounted) setState(() => _dirty = d);
  }

  static void _deleteQuietly(String? path) {
    // Web photos are data URLs, not files: nothing to clean up.
    if (path == null || kIsWeb || ProfilePhoto.isDataUrl(path)) return;
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {
      // Best effort; a stray file in app storage is harmless.
    }
  }

  bool get _hasPhoto => _pendingPhoto != null || (!_removePhoto && _initial?.photoPath != null);

  Future<void> _photoOptions() async {
    FocusScope.of(context).unfocus();
    Widget option(IconData icon, String label, String value, {Color color = AppColors.ink}) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: IconBubble(icon: icon, size: 46, bg: AppColors.chip, color: color == AppColors.ink ? AppColors.goldText : color),
          title: Text(label, style: T.sans(16.5, color: color)),
          onTap: () => Navigator.pop(context, value),
        );
    final choice = await showAppSheet<String>(
      context,
      title: 'Profile Photo',
      child: Column(children: [
        option(Icons.photo_camera_outlined, 'Take photo', 'camera'),
        option(Icons.photo_library_outlined, 'Choose from gallery', 'gallery'),
        if (_hasPhoto) option(Icons.delete_outline, 'Remove photo', 'remove', color: AppColors.maroon),
      ]),
    );
    if (!mounted || choice == null) return;
    if (choice == 'remove') {
      _deleteQuietly(_pendingPhoto);
      _pendingPhoto = null;
      _removePhoto = true;
      _updateDirty();
      return;
    }
    await _pick(choice == 'camera' ? ImageSource.camera : ImageSource.gallery);
  }

  Future<void> _pick(ImageSource source) async {
    setState(() => _busy = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        // Web keeps the photo inline in local storage, so keep it small.
        maxWidth: kIsWeb ? 512 : 800,
        maxHeight: kIsWeb ? 512 : 800,
        imageQuality: kIsWeb ? 80 : 85,
        preferredCameraDevice: CameraDevice.front,
        requestFullMetadata: false,
      );
      if (picked == null) return; // cancelled
      if (kIsWeb) {
        await _useWebPhoto(picked);
        return;
      }
      final dir = await getApplicationDocumentsDirectory();
      final dot = picked.name.lastIndexOf('.');
      final ext = dot == -1 ? '.jpg' : picked.name.substring(dot).toLowerCase();
      final dest = '${dir.path}${Platform.pathSeparator}avatar_${DateTime.now().millisecondsSinceEpoch}$ext';
      await picked.saveTo(dest);
      // The picker hands back a copy in the cache dir on Android / iOS; tidy
      // it up, but never touch a file outside it (desktop returns originals).
      final tmp = await getTemporaryDirectory();
      if (picked.path.startsWith(tmp.path)) _deleteQuietly(picked.path);
      if (!mounted) {
        _deleteQuietly(dest);
        return;
      }
      _deleteQuietly(_pendingPhoto);
      _pendingPhoto = dest;
      _removePhoto = false;
      _updateDirty();
    } on PlatformException catch (e) {
      if (!mounted) return;
      final denied = e.code.contains('access_denied');
      showToast(
        context,
        source == ImageSource.camera
            ? (denied ? 'Camera access is off. Allow it in Settings to take a photo.' : 'Couldn\'t open the camera')
            : (denied ? 'Photo access is off. Allow it in Settings to choose a photo.' : 'Couldn\'t open your photos'),
      );
    } catch (_) {
      if (mounted) showToast(context, 'Couldn\'t use that photo. Please try another one.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Web: no app documents directory, so the picked (already downscaled)
  /// image is kept as a data URL in the profile.
  Future<void> _useWebPhoto(XFile picked) async {
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    if (bytes.isEmpty) throw const FormatException('empty image');
    if (bytes.length > ProfilePhoto.maxInlineBytes) {
      showToast(context, 'That photo is too large. Please choose a smaller one.');
      return;
    }
    _pendingPhoto = ProfilePhoto.toDataUrl(bytes, mimeType: picked.mimeType);
    _removePhoto = false;
    _updateDirty();
  }

  void _save() {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    final state = context.read<AppState>();
    final oldPhoto = state.user?.photoPath;
    if (_pendingPhoto != null) {
      state.updateProfile(name: _name.text, email: _email.text, photoPath: _pendingPhoto);
      if (oldPhoto != _pendingPhoto) _deleteQuietly(oldPhoto);
    } else if (_removePhoto) {
      state.updateProfile(name: _name.text, email: _email.text, clearPhoto: true);
      _deleteQuietly(oldPhoto);
    } else {
      state.updateProfile(name: _name.text, email: _email.text);
    }
    _pendingPhoto = null; // now owned by the profile, keep it on dispose
    Navigator.pop(context);
    showToast(context, 'Profile updated');
  }

  Future<void> _deleteAccount() async {
    FocusScope.of(context).unfocus();
    final ok = await confirmDialog(
      context,
      'Delete your account?',
      'Your profile, photo and password will be permanently removed from this phone and you\'ll be signed '
          'out. This can\'t be undone.',
      confirm: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    _leaving = true; // keep showing this form while the sign-in page fades in
    context.read<AppState>().deleteAccount();
    Navigator.of(context).pushAndRemoveUntil(fadeRoute(const SignInScreen()), (_) => false);
    showToast(context, 'Your account has been deleted');
  }

  Future<void> _confirmDiscard() async {
    final ok = await confirmDialog(context, 'Discard changes?', 'Your edits to this profile haven\'t been saved.',
        confirm: 'Discard', destructive: true);
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.user ?? (_leaving ? _initial : null);
    if (user == null || _initial == null) {
      return const Scaffold(
        body: GuestGate(header: 'Edit Profile', title: 'Sign in to edit your profile'),
      );
    }
    final preview = UserProfile(
      name: _name.text.trim().isEmpty ? user.name : _name.text.trim(),
      phone: user.phone,
      email: user.email,
      photoPath: _pendingPhoto ?? (_removePhoto ? null : user.photoPath),
    );

    Widget label(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
          child: Text(text, style: T.sans(13.5, color: AppColors.grey, spacing: 1.6, weight: FontWeight.w600)),
        );

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        backgroundColor: AppColors.cream,
        body: SafeArea(
          child: Column(children: [
            const PageHeader(title: 'Edit Profile', underline: true),
            Expanded(
              child: Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
                  children: [
                    Center(
                      child: Pressable(
                        onTap: _busy ? null : _photoOptions,
                        child: SizedBox(
                          width: 132,
                          height: 132,
                          child: Stack(children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 14)],
                              ),
                              child: UserAvatar(size: 128, profile: preview),
                            ),
                            if (_busy)
                              const Positioned.fill(
                                right: 4,
                                bottom: 4,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(color: Color(0x66000000), shape: BoxShape.circle),
                                  child: Center(child: CircularProgressIndicator(color: AppColors.gold)),
                                ),
                              ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.maroon,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.cream, width: 3),
                                ),
                                child: const Icon(Icons.photo_camera_outlined, color: Colors.white, size: 20),
                              ),
                            ),
                          ]),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: TextButton(
                        onPressed: _busy ? null : _photoOptions,
                        child: Text(_hasPhoto ? 'Change photo' : 'Add a photo',
                            style: T.sans(15.5, color: AppColors.goldText, weight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    label('FULL NAME'),
                    AppTextField(
                      hint: 'Your full name',
                      controller: _name,
                      icon: Icons.person_outline,
                      validator: (v) => (v ?? '').trim().length < 2 ? 'Enter your full name' : null,
                    ),
                    const SizedBox(height: 18),
                    label('EMAIL (OPTIONAL)'),
                    AppTextField(
                      hint: 'you@example.com',
                      controller: _email,
                      icon: Icons.mail_outline,
                      keyboard: TextInputType.emailAddress,
                      validator: (v) {
                        final e = (v ?? '').trim();
                        return e.isNotEmpty && !AppState.isValidEmail(e) ? 'Enter a valid email address' : null;
                      },
                    ),
                    const SizedBox(height: 18),
                    label('MOBILE NUMBER'),
                    _ReadOnlyField(
                      icon: Icons.phone_iphone,
                      value: user.displayPhone,
                      trailing: const Icon(Icons.lock_outline, size: 20, color: AppColors.greyLight),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                      child: Text('Your number is your sign-in ID, so it can\'t be changed.',
                          style: T.sans(13, color: AppColors.greyLight)),
                    ),
                    const SizedBox(height: 18),
                    label('DELIVERY CITY'),
                    _ReadOnlyField(
                      icon: Icons.location_on_outlined,
                      value: state.cityLabel,
                      trailing: const Icon(Icons.chevron_right, color: AppColors.grey),
                      onTap: () => push(context, const LocationScreen(changeOnly: true)),
                    ),
                    const SizedBox(height: 28),
                    const Divider(color: AppColors.border, height: 1),
                    const SizedBox(height: 8),
                    ListTile(
                      key: const Key('delete-account'),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      leading: const IconBubble(icon: Icons.delete_outline, size: 46),
                      title: Text('Delete account', style: T.sans(16.5, color: AppColors.maroon, weight: FontWeight.w600)),
                      subtitle: Text('Removes your profile, photo and password from this phone.',
                          style: T.sans(13.5, color: AppColors.grey, height: 1.35)),
                      onTap: _busy ? null : _deleteAccount,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: PrimaryButton(
                label: 'Save Changes',
                arrow: false,
                height: 60,
                fontSize: 21,
                onTap: _busy ? null : _save,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  final IconData icon;
  final String value;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _ReadOnlyField({required this.icon, required this.value, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.creamLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(children: [
              Icon(icon, color: AppColors.grey),
              const SizedBox(width: 12),
              Expanded(
                child: Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: T.sans(16, color: onTap == null ? AppColors.grey : AppColors.ink)),
              ),
              if (trailing != null) trailing!,
            ]),
          ),
        ),
      ),
    );
  }
}
