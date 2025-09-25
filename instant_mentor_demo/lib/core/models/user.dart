enum UserRole {
  student('student'),
  mentor('mentor'),
  admin('admin');

  const UserRole(this.name);

  final String name;

  static UserRole fromString(String role) {
    return switch (role.toLowerCase()) {
      'student' => UserRole.student,
      'mentor' => UserRole.mentor,
      'admin' => UserRole.admin,
      _ => throw ArgumentError('Invalid user role: $role'),
    };
  }

  bool get isStudent => this == UserRole.student;
  bool get isMentor => this == UserRole.mentor;
  bool get isAdmin => this == UserRole.admin;
}

class User {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? profileImage;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final bool isActive;

  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.profileImage,
    required this.createdAt,
    this.lastLoginAt,
    this.isActive = true,
  });

  User copyWith({
    String? id,
    String? name,
    String? email,
    UserRole? role,
    String? profileImage,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    bool? isActive,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      profileImage: profileImage ?? this.profileImage,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role.name,
      'profileImage': profileImage,
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'isActive': isActive,
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: UserRole.fromString(json['role'] as String),
      profileImage: json['profileImage'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastLoginAt: json['lastLoginAt'] != null
          ? DateTime.parse(json['lastLoginAt'] as String)
          : null,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'User(id: $id, name: $name, email: $email, role: $role)';
  }
}

class Mentor {
  final String id;
  final String name;
  final String email;
  final String? profileImage;
  final DateTime createdAt;
  final List<String> specializations;
  final List<String> qualifications;
  final double hourlyRate;
  final double rating;
  final int totalSessions;
  final bool isAvailable;
  final double totalEarnings;
  final String bio;
  final int yearsOfExperience;

  const Mentor({
    required this.id,
    required this.name,
    required this.email,
    this.profileImage,
    required this.createdAt,
    required this.specializations,
    required this.qualifications,
    required this.hourlyRate,
    required this.rating,
    required this.totalSessions,
    required this.isAvailable,
    required this.totalEarnings,
    required this.bio,
    required this.yearsOfExperience,
  });

  Mentor copyWith({
    String? id,
    String? name,
    String? email,
    String? profileImage,
    DateTime? createdAt,
    List<String>? specializations,
    List<String>? qualifications,
    double? hourlyRate,
    double? rating,
    int? totalSessions,
    bool? isAvailable,
    double? totalEarnings,
    String? bio,
    int? yearsOfExperience,
  }) {
    return Mentor(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      profileImage: profileImage ?? this.profileImage,
      createdAt: createdAt ?? this.createdAt,
      specializations: specializations ?? this.specializations,
      qualifications: qualifications ?? this.qualifications,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      rating: rating ?? this.rating,
      totalSessions: totalSessions ?? this.totalSessions,
      isAvailable: isAvailable ?? this.isAvailable,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      bio: bio ?? this.bio,
      yearsOfExperience: yearsOfExperience ?? this.yearsOfExperience,
    );
  }

  User toUser() => User(
        id: id,
        name: name,
        email: email,
        role: UserRole.mentor,
        profileImage: profileImage,
        createdAt: createdAt,
      );
}

/// Authentication credentials for login
class LoginCredentials {
  final String email;
  final String password;

  const LoginCredentials({
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
    };
  }
}

/// Registration data for signup
class RegisterData {
  final String name;
  final String email;
  final String password;
  final UserRole role;

  const RegisterData({
    required this.name,
    required this.email,
    required this.password,
    required this.role,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'password': password,
      'role': role.name,
    };
  }
}

/// Authentication token information
class AuthToken {
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;

  const AuthToken({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  bool get isNearExpiry =>
      DateTime.now().add(const Duration(minutes: 5)).isAfter(expiresAt);

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'expiresAt': expiresAt.toIso8601String(),
    };
  }

  factory AuthToken.fromJson(Map<String, dynamic> json) {
    return AuthToken(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
  }
}

/// Session model containing user and token information
class Session {
  final User user;
  final AuthToken token;

  const Session({
    required this.user,
    required this.token,
  });

  bool get isValid => !token.isExpired && user.isActive;

  Session copyWith({
    User? user,
    AuthToken? token,
  }) {
    return Session(
      user: user ?? this.user,
      token: token ?? this.token,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'token': token.toJson(),
    };
  }

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      token: AuthToken.fromJson(json['token'] as Map<String, dynamic>),
    );
  }
}
