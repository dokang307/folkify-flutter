class Lesson {
  final String id;   // slug — dùng cho routing
  final String uuid; // UUID — dùng cho API complete lesson
  final String title;
  final String duration;
  final String level;
  final String description;
  final List<String> steps;
  final List<String> tips;
  final int xp;
  final String? youtubeUrl;
  final String? youtubeVideoId;
  final String? channelName;
  final bool completed;
  /// Gói tối thiểu để mở bài: FREE / BASIC / PRO.
  final String requiredPlan;
  /// Backend đã tính sẵn theo gói hiệu lực của user.
  final bool locked;

  const Lesson({
    required this.id,
    this.uuid = '',
    required this.title,
    required this.duration,
    required this.level,
    required this.description,
    required this.steps,
    required this.tips,
    required this.xp,
    this.youtubeUrl,
    this.youtubeVideoId,
    this.channelName,
    this.completed = false,
    this.requiredPlan = 'FREE',
    this.locked = false,
  });

  factory Lesson.fromSummaryJson(Map<String, dynamic> json) => Lesson(
        id: json['slug'] as String,
        uuid: json['id'] as String? ?? '',
        title: json['title'] as String,
        duration: json['duration'] as String? ?? '',
        level: json['level'] as String? ?? '',
        description: '',
        steps: const [],
        tips: const [],
        xp: json['xp'] as int? ?? 0,
        completed: json['completed'] as bool? ?? false,
        requiredPlan: json['requiredPlan'] as String? ?? 'FREE',
        locked: json['locked'] as bool? ?? false,
      );

  factory Lesson.fromDetailJson(Map<String, dynamic> json) => Lesson(
        id: json['slug'] as String,
        uuid: json['id'] as String? ?? '',
        title: json['title'] as String,
        duration: json['duration'] as String? ?? '',
        level: json['level'] as String? ?? '',
        description: json['description'] as String? ?? '',
        steps: (json['steps'] as List?)?.map((e) => e as String).toList() ?? const [],
        tips: (json['tips'] as List?)?.map((e) => e as String).toList() ?? const [],
        xp: json['xp'] as int? ?? 0,
        youtubeUrl: json['youtubeUrl'] as String?,
        youtubeVideoId: json['youtubeVideoId'] as String?,
        channelName: json['channelName'] as String?,
        requiredPlan: json['requiredPlan'] as String? ?? 'FREE',
      );
}

class Song {
  final String title;
  final String artist;
  final String duration;

  const Song({
    required this.title,
    required this.artist,
    required this.duration,
  });

  factory Song.fromJson(Map<String, dynamic> json) => Song(
        title: json['title'] as String? ?? '',
        artist: json['artist'] as String? ?? '',
        duration: json['duration'] as String? ?? '',
      );
}

class Instrument {
  final String id; // slug — dùng cho routing
  final String name;
  final String englishName;
  final String region;
  final String category;
  final String emoji;
  final String color;
  final String imageUrl;
  final String shortDesc;
  final String description;
  final String origin;
  final String material;
  final String soundRange;
  final int difficulty;
  final int popularity;
  final List<Lesson> lessons;
  final List<Song> songs;
  final List<String> facts;

  const Instrument({
    required this.id,
    required this.name,
    required this.englishName,
    required this.region,
    required this.category,
    required this.emoji,
    required this.color,
    required this.imageUrl,
    required this.shortDesc,
    required this.description,
    required this.origin,
    required this.material,
    required this.soundRange,
    required this.difficulty,
    required this.popularity,
    required this.lessons,
    required this.songs,
    required this.facts,
  });

  factory Instrument.fromJson(Map<String, dynamic> json) => Instrument(
        id: json['slug'] as String,
        name: json['name'] as String,
        englishName: json['englishName'] as String? ?? '',
        region: json['region'] as String? ?? '',
        category: json['category'] as String? ?? '',
        emoji: json['emoji'] as String? ?? '🎵',
        color: json['color'] as String? ?? '#1a5c2e',
        imageUrl: json['imageUrl'] as String? ?? '',
        shortDesc: json['shortDesc'] as String? ?? '',
        description: json['description'] as String? ?? '',
        origin: json['origin'] as String? ?? '',
        material: json['material'] as String? ?? '',
        soundRange: json['soundRange'] as String? ?? '',
        difficulty: json['difficulty'] as int? ?? 1,
        popularity: json['popularity'] as int? ?? 1,
        lessons: (json['lessons'] as List?)
                ?.map((e) => Lesson.fromSummaryJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        songs: (json['songs'] as List?)
                ?.map((e) => Song.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        facts: (json['facts'] as List?)?.map((e) => e as String).toList() ?? const [],
      );
}

class InstrumentSummary {
  final String id; // slug — dùng cho routing
  final String name;
  final String englishName;
  final String category;
  final String emoji;
  final String color;
  final String imageUrl;
  final String shortDesc;
  final int difficulty;
  final int popularity;
  final int lessonCount;

  const InstrumentSummary({
    required this.id,
    required this.name,
    required this.englishName,
    required this.category,
    required this.emoji,
    required this.color,
    required this.imageUrl,
    required this.shortDesc,
    required this.difficulty,
    required this.popularity,
    required this.lessonCount,
  });

  factory InstrumentSummary.fromJson(Map<String, dynamic> json) => InstrumentSummary(
        id: json['slug'] as String,
        name: json['name'] as String,
        englishName: json['englishName'] as String? ?? '',
        category: json['category'] as String? ?? '',
        emoji: json['emoji'] as String? ?? '🎵',
        color: json['color'] as String? ?? '#1a5c2e',
        imageUrl: json['imageUrl'] as String? ?? '',
        shortDesc: json['shortDesc'] as String? ?? '',
        difficulty: json['difficulty'] as int? ?? 1,
        popularity: json['popularity'] as int? ?? 1,
        lessonCount: json['lessonCount'] as int? ?? 0,
      );
}
