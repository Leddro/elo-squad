import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_user.freezed.dart';

/// Quem está logado no app (conta Google, via Firebase Auth).
@freezed
abstract class AppUser with _$AppUser {
  const factory AppUser({
    required String uid,
    required String? displayName,
    required String? email,
    required String? photoUrl,
  }) = _AppUser;
}
