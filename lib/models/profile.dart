class UserProfile {
  const UserProfile({
    this.nickname = '小罗',
    this.signature = '一点点记录自己的生活。',
    this.birthday = '',
    this.homeText = '记录属于自己的每一天。',
    this.avatarPath = '',
  });
  final String nickname;
  final String signature;
  final String birthday;
  final String homeText;
  final String avatarPath;
  UserProfile copyWith({
    String? nickname,
    String? signature,
    String? birthday,
    String? homeText,
    String? avatarPath,
  }) => UserProfile(
    nickname: nickname ?? this.nickname,
    signature: signature ?? this.signature,
    birthday: birthday ?? this.birthday,
    homeText: homeText ?? this.homeText,
    avatarPath: avatarPath ?? this.avatarPath,
  );
}
