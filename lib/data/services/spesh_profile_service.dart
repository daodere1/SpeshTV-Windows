import 'package:dio/dio.dart';
import 'package:server_core/server_core.dart';

const speshProfileAvatars = [
  'blue',
  'gold',
  'teal',
  'purple',
  'coral',
  'green',
  'pink',
  'slate',
];

class SpeshViewingProfile {
  const SpeshViewingProfile({
    required this.id,
    required this.name,
    required this.avatar,
    required this.isPrimary,
  });
  final String id, name, avatar;
  final bool isPrimary;
  factory SpeshViewingProfile.fromJson(Map<String, dynamic> json) =>
      SpeshViewingProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        avatar: json['avatar'] as String,
        isPrimary: json['isPrimary'] == true,
      );
}

/// Immutable original login. Never replaced with a managed profile token.
class SpeshProfileOwner {
  const SpeshProfileOwner({
    required this.serverId,
    required this.userId,
    required this.baseUrl,
    required this.token,
  });
  final String serverId, userId, baseUrl, token;
}

class SpeshProfileSelection {
  const SpeshProfileSelection(this.profile, this.userId, this.token);
  final SpeshViewingProfile profile;
  final String userId, token;

  /// Confirm the token's actual Users/Me identity before installing a session.
  void validateIdentity(ServerUser user) {
    if (user.id != userId) {
      throw StateError('Profile identity could not be confirmed.');
    }
    if (!profile.isPrimary && user.policy?.isAdministrator == true) {
      throw StateError(
        'A managed profile cannot use an administrator identity.',
      );
    }
  }
}

class SpeshProfilesApi {
  SpeshProfilesApi(this.owner, this.device, {Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 30),
            ),
          );
  final SpeshProfileOwner owner;
  final DeviceInfo device;
  final Dio _dio;
  Future<Response<dynamic>> _request(
    String suffix, {
    String method = 'GET',
    Object? data,
  }) => _dio.request(
    '${owner.baseUrl.replaceFirst(RegExp(r'/+$'), '')}/Spesh/Profiles$suffix',
    data: data,
    options: Options(
      method: method,
      headers: {
        'Authorization': buildServerAuthorizationHeader(
          scheme: 'MediaBrowser',
          deviceInfo: device,
          accessToken: owner.token,
        ),
        'Cache-Control': 'no-store',
      },
    ),
  );
  Future<List<SpeshViewingProfile>> list() async {
    final response = await _request('');
    return (response.data['profiles'] as List)
        .map(
          (e) =>
              SpeshViewingProfile.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<void> save({
    SpeshViewingProfile? profile,
    required String name,
    required String avatar,
  }) async {
    final normalized = name.trim();
    if (normalized.isEmpty ||
        normalized.runes.length > 24 ||
        !speshProfileAvatars.contains(avatar)) {
      throw ArgumentError(
        'Choose a name of 1–24 characters and a supported avatar.',
      );
    }
    await _request(
      profile == null ? '' : '/${Uri.encodeComponent(profile.id)}',
      method: profile == null ? 'POST' : 'PUT',
      data: {'name': normalized, 'avatar': avatar},
    );
  }

  Future<SpeshProfileSelection> select(SpeshViewingProfile profile) async {
    final response = await _request(
      '/${Uri.encodeComponent(profile.id)}/Select',
      method: 'POST',
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    final selected = SpeshViewingProfile.fromJson(
      Map<String, dynamic>.from(data['profile'] as Map),
    );
    final userId = data['userId'] as String;
    final token = data['accessToken'] as String?;
    if (selected.id != profile.id ||
        selected.isPrimary != profile.isPrimary ||
        userId.isEmpty ||
        (selected.isPrimary &&
            (selected.id != 'main' ||
                userId != owner.userId ||
                token != null)) ||
        (!selected.isPrimary &&
            (userId == owner.userId ||
                token == null ||
                token.isEmpty ||
                token == owner.token))) {
      throw StateError('Invalid profile identity response.');
    }
    return SpeshProfileSelection(
      selected,
      userId,
      selected.isPrimary ? owner.token : token!,
    );
  }

  void dispose() => _dio.close(force: true);
}
