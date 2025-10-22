/// Public-facing metadata for an author shown in subscriber experiences.
class PublicAuthorProfile {
  const PublicAuthorProfile({
    required this.id,
    required this.name,
    required this.displayName,
    required this.avatarUrl,
    required this.tagline,
    required this.summary,
    required this.coverImageUrl,
  });

  final String id;
  final String? name;
  final String? displayName;
  final String? avatarUrl;
  final String? tagline;
  final String? summary;
  final String? coverImageUrl;

  /// Friendly name prioritising the public display name and falling back
  /// to the account name. Used throughout the blog UI.
  String get resolvedDisplayName => (displayName?.trim().isNotEmpty ?? false)
      ? displayName!.trim()
      : (name?.trim().isNotEmpty ?? false)
          ? name!.trim()
          : 'Autor/a en Narra';

  bool get hasTagline => tagline?.trim().isNotEmpty == true;
  bool get hasSummary => summary?.trim().isNotEmpty == true;
  bool get hasCoverImage => coverImageUrl?.trim().isNotEmpty == true;

  PublicAuthorProfile copyWith({
    String? displayName,
    String? name,
    String? avatarUrl,
    String? tagline,
    String? summary,
    String? coverImageUrl,
  }) {
    return PublicAuthorProfile(
      id: id,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      tagline: tagline ?? this.tagline,
      summary: summary ?? this.summary,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
    );
  }

  factory PublicAuthorProfile.fromSupabase(Map<String, dynamic> data) {
    final settings = data['user_settings'] as Map<String, dynamic>?;

    return PublicAuthorProfile(
      id: data['id'] as String? ?? '',
      name: data['name'] as String?,
      displayName:
          settings != null ? settings['public_author_name'] as String? : null,
      avatarUrl: data['avatar_url'] as String?,
      tagline: settings != null
          ? settings['public_author_tagline'] as String?
          : null,
      summary: settings != null
          ? settings['public_author_summary'] as String?
          : null,
      coverImageUrl: settings != null
          ? settings['public_blog_cover_url'] as String?
          : null,
    );
  }
}
