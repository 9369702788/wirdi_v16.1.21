class RadioStation {
  final String id;
  final String nameAr;
  final String nameEn;
  final String streamUrl;
  final String country;
  final String countryCode;
  final String category;
  final bool isOfficial;
  final String? imageUrl;
  final String? stationUuid;

  const RadioStation({
    required this.id, required this.nameAr, required this.nameEn,
    required this.streamUrl, required this.country, required this.countryCode,
    required this.category, this.isOfficial = false,
    this.imageUrl, this.stationUuid,
  });

  factory RadioStation.fromDataRosy(Map<String, dynamic> j) {
    final name = j['name'] as String? ?? '';
    return RadioStation(
      id: 'dr_${j["id"]}',
      nameAr: name, nameEn: name,
      streamUrl: j['radio_url'] as String? ?? '',
      country: _guessCountry(name),
      countryCode: _guessCountryCode(name),
      category: 'quran',
      isOfficial: name.contains('إذاعة'),
      imageUrl: j['image_url'] as String?,
    );
  }

  factory RadioStation.fromUthumany(Map<String, dynamic> j) {
    final name = (j["name"] as String?) ?? "";
    final safeId = name.toLowerCase()
        .replaceAll(" ", "_")
        .replaceAll(RegExp("[^a-z0-9_]"), "");
    return RadioStation(
      id: "ut_$safeId",
      nameAr: name,
      nameEn: name,
      streamUrl: (j["stream_url"] as String?) ?? "",
      country: _guessCountry(name),
      countryCode: _guessCountryCode(name),
      category: _guessCategory(name),
      isOfficial: name.contains("إذاعة"),
    );
  }

  static String _guessCountry(String n) {
    if (n.contains('القاهرة') || n.contains('مصر')) return 'Egypt';
    if (n.contains('السعودية') || n.contains('مكة')) return 'Saudi Arabia';
    if (n.contains('الكويت')) return 'Kuwait';
    if (n.contains('المغرب')) return 'Morocco';
    if (n.contains('الجزائر')) return 'Algeria';
    if (n.contains('تونس')) return 'Tunisia';
    if (n.contains('قطر')) return 'Qatar';
    if (n.contains('الشارقة') || n.contains('الإمارات')) return 'UAE';
    return 'International';
  }

  static String _guessCountryCode(String n) {
    if (n.contains('القاهرة') || n.contains('مصر')) return 'EG';
    if (n.contains('السعودية') || n.contains('مكة')) return 'SA';
    if (n.contains('الكويت')) return 'KW';
    if (n.contains('المغرب')) return 'MA';
    if (n.contains('الجزائر')) return 'DZ';
    if (n.contains('تونس')) return 'TN';
    if (n.contains('قطر')) return 'QA';
    if (n.contains('الشارقة') || n.contains('الإمارات')) return 'AE';
    return 'INT';
  }

  /// Radio-Browser (https://www.radio-browser.info) is a large,
  /// community-maintained, genuinely open directory of internet radio
  /// streams with a documented public API. Field names below
  /// (stationuuid/name/url_resolved/favicon/country/countrycode/tags)
  /// match their documented JSON station object
  /// (https://de1.api.radio-browser.info/) -- NOT verified against a
  /// live response from this sandbox (no network access here), so
  /// please confirm on a real device/build before relying on it as a
  /// primary source.
  factory RadioStation.fromRadioBrowser(Map<String, dynamic> j) {
    final name = ((j['name'] as String?) ?? '').trim();
    final uuid = (j['stationuuid'] as String?) ?? name;
    final streamUrl = (j['url_resolved'] as String?)?.trim().isNotEmpty == true
        ? (j['url_resolved'] as String).trim()
        : ((j['url'] as String?) ?? '').trim();
    final apiCountry = (j['country'] as String?)?.trim() ?? '';
    final apiCountryCode = (j['countrycode'] as String?)?.trim() ?? '';
    return RadioStation(
      id: 'rb_$uuid',
      nameAr: name,
      nameEn: name,
      streamUrl: streamUrl,
      country: apiCountry.isNotEmpty ? apiCountry : _guessCountry(name),
      countryCode: apiCountryCode.isNotEmpty ? apiCountryCode.toUpperCase() : _guessCountryCode(name),
      category: _guessCategory(name),
      isOfficial: false,
      imageUrl: (j['favicon'] as String?)?.trim().isNotEmpty == true ? (j['favicon'] as String).trim() : null,
      stationUuid: uuid,
    );
  }

  factory RadioStation.fromMp3Quran(Map<String, dynamic> j) {
    final name = (j['name'] as String?) ?? '';
    final id = j['id']?.toString() ?? name;
    return RadioStation(
      id: 'mp3q_$id',
      nameAr: name,
      nameEn: name,
      streamUrl: (j['url'] as String?) ?? '',
      country: _guessCountry(name),
      countryCode: _guessCountryCode(name),
      category: 'quran',
      isOfficial: false,
    );
  }

  static String _guessCategory(String n) {
    if (n.contains('محاضر') || n.contains('درس')) return 'lectures';
    if (n.contains('أناشيد') || n.contains('nasheed')) return 'nasheed';
    if (n.contains('مكة') || n.contains('صلاة')) return 'prayers';
    return 'quran';
  }
}
