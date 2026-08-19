class AppConfig {
  final ApiConfig apis;
  final LibraryConfig library;

  AppConfig({required this.apis, required this.library});

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      apis: ApiConfig.fromJson(json['apis'] ?? {}),
      library: LibraryConfig.fromJson(json['library'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'apis': apis.toJson(),
        'library': library.toJson(),
      };
}

class ApiConfig {
  final String quran;
  final String prayerTimes;
  final String mushafPngBase;
  final String quranAudioPrimary;
  final String quranAudioBackup;
  final String tafseer;
  final String azanAudio;
  final String geocoding;

  ApiConfig({
    required this.quran,
    required this.prayerTimes,
    required this.mushafPngBase,
    required this.quranAudioPrimary,
    required this.quranAudioBackup,
    required this.tafseer,
    required this.azanAudio,
    required this.geocoding,
  });

  factory ApiConfig.fromJson(Map<String, dynamic> json) {
    return ApiConfig(
      quran: json['quran'] ?? 'https://api.quran.com/api/v4',
      prayerTimes: json['prayer_times'] ?? 'https://api.aladhan.com/v1',
      mushafPngBase: json['mushaf_png_base'] ??
          'https://raw.githubusercontent.com/tito423/Quran-PNG/main/images/',
      quranAudioPrimary: json['quran_audio_primary'] ?? 'https://cdn.islamic.network/quran/audio/',
      quranAudioBackup: json['quran_audio_backup'] ?? 'https://everyayah.com/data/',
      tafseer: json['tafseer'] ?? 'https://api.alquran.cloud/v1/',
      azanAudio: json['azan_audio'] ?? 'https://praytimes.org/audio/adhan/',
      geocoding: json['geocoding'] ?? 'https://nominatim.openstreetmap.org/reverse',
    );
  }

  Map<String, dynamic> toJson() => {
        'quran': quran,
        'prayer_times': prayerTimes,
        'mushaf_png_base': mushafPngBase,
        'quran_audio_primary': quranAudioPrimary,
        'quran_audio_backup': quranAudioBackup,
        'tafseer': tafseer,
        'azan_audio': azanAudio,
        'geocoding': geocoding,
      };
}

class LibraryConfig {
  final List<LibraryBook> books;
  final List<LibraryWebsite> websites;

  LibraryConfig({required this.books, required this.websites});

  factory LibraryConfig.fromJson(Map<String, dynamic> json) {
    final booksList = json['books'] as List? ?? [];
    final websitesList = json['websites'] as List? ?? [];
    
    // Provide default curated data if JSON is empty or missing
    final defaultWebsites = [
      LibraryWebsite(name: 'طريق الإسلام (Islamway)', url: 'https://ar.islamway.net/'),
      LibraryWebsite(name: 'الإسلام سؤال وجواب (IslamQA)', url: 'https://islamqa.info/ar'),
      LibraryWebsite(name: 'المكتبة الشاملة (Shamela)', url: 'https://shamela.ws/'),
      LibraryWebsite(name: 'تي في قرآن (TVQuran)', url: 'https://www.tvquran.com/ar/'),
    ];

    final defaultBooks = [
      LibraryBook(
        id: 'bukhari',
        title: 'صحيح البخاري',
        author: 'الإمام البخاري',
        description: 'كتاب حديث شريف',
        downloadUrl: 'https://raw.githubusercontent.com/tito423/rafeeq-api/main/hadith/bukhari.json',
        coverUrl: '',
      ),
      LibraryBook(
        id: 'muslim',
        title: 'صحيح مسلم',
        author: 'الإمام مسلم',
        description: 'كتاب حديث شريف',
        downloadUrl: 'https://raw.githubusercontent.com/tito423/rafeeq-api/main/hadith/muslim.json',
        coverUrl: '',
      ),
      LibraryBook(
        id: 'abudawud',
        title: 'سنن أبي داود',
        author: 'الإمام أبو داود',
        description: 'كتاب حديث شريف',
        downloadUrl: 'https://raw.githubusercontent.com/tito423/rafeeq-api/main/hadith/abudawud.json',
        coverUrl: '',
      ),
      LibraryBook(
        id: 'tirmidhi',
        title: 'جامع الترمذي',
        author: 'الإمام الترمذي',
        description: 'كتاب حديث شريف',
        downloadUrl: 'https://raw.githubusercontent.com/tito423/rafeeq-api/main/hadith/tirmidhi.json',
        coverUrl: '',
      ),
      LibraryBook(
        id: 'nasai',
        title: 'سنن النسائي',
        author: 'الإمام النسائي',
        description: 'كتاب حديث شريف',
        downloadUrl: 'https://raw.githubusercontent.com/tito423/rafeeq-api/main/hadith/nasai.json',
        coverUrl: '',
      ),
      LibraryBook(
        id: 'ibnmajah',
        title: 'سنن ابن ماجه',
        author: 'الإمام ابن ماجه',
        description: 'كتاب حديث شريف',
        downloadUrl: 'https://raw.githubusercontent.com/tito423/rafeeq-api/main/hadith/ibnmajah.json',
        coverUrl: '',
      ),
    ];

    return LibraryConfig(
      books: booksList.isEmpty ? defaultBooks : booksList.map((e) => LibraryBook.fromJson(e)).toList(),
      websites: websitesList.isEmpty ? defaultWebsites : websitesList.map((e) => LibraryWebsite.fromJson(e)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'books': books.map((e) => e.toJson()).toList(),
        'websites': websites.map((e) => e.toJson()).toList(),
      };
}

class LibraryBook {
  final String id;
  final String title;
  final String author;
  final String description;
  final String downloadUrl;
  final String coverUrl;

  LibraryBook({
    required this.id,
    required this.title,
    required this.author,
    required this.description,
    required this.downloadUrl,
    required this.coverUrl,
  });

  factory LibraryBook.fromJson(Map<String, dynamic> json) {
    return LibraryBook(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      author: json['author'] ?? '',
      description: json['description'] ?? '',
      downloadUrl: json['download_url'] ?? '',
      coverUrl: json['cover_url'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'author': author,
        'description': description,
        'download_url': downloadUrl,
        'cover_url': coverUrl,
      };
}

class LibraryWebsite {
  final String name;
  final String url;

  LibraryWebsite({required this.name, required this.url});

  factory LibraryWebsite.fromJson(Map<String, dynamic> json) {
    return LibraryWebsite(
      name: json['name'] ?? '',
      url: json['url'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'url': url,
      };
}
