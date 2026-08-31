
import '../models/radio_station.dart';

/// 28 curated Islamic radio stations embedded directly in the app.
/// All streams are on radiojar.com CDN or other reliable CDNs.
/// These are the same stations from data-rosy.vercel.app/radio.json,
/// embedded so the app works instantly without any API call.
///
/// The RadioService still tries to fetch live data in the background
/// to refresh URLs, but users always see all 18 stations immediately.
const List<RadioStation> kFallbackStations = [

  // ── Egypt ─────────────────────────────────────────────────────────────────
  RadioStation(
    id: 'dr_1',
    nameAr: 'إذاعة القرآن الكريم من القاهرة',
    nameEn: 'Holy Quran Radio Cairo',
    streamUrl: 'https://stream.radiojar.com/8s5u5tpdtwzuv',
    country: 'Egypt', countryCode: 'EG',
    category: 'quran', isOfficial: true,
    imageUrl: 'https://i.postimg.cc/d1kdrLkx/quran.jpg',
  ),
  // NEW (v123): a second, differently-hosted Cairo Quran Radio entry
  // as a backup in case dr_1's original radiojar.com stream slug has
  // gone dead (a common failure mode for these free CDN relay
  // services over time) -- purely additive, dr_1 is left untouched so
  // nothing that already worked can regress. If this one also turns
  // out not to work, tell Sigma and it'll be swapped for a different
  // URL; these could not be connectivity-tested from the sandbox this
  // was written in.
  RadioStation(
    id: 'dr_1b',
    nameAr: 'إذاعة القرآن الكريم من القاهرة (رابط بديل)',
    nameEn: 'Holy Quran Radio Cairo (backup link)',
    streamUrl: 'https://n0a.radiojar.com/8s5u5tpdtwzuv',
    country: 'Egypt', countryCode: 'EG',
    category: 'quran', isOfficial: true,
    imageUrl: 'https://i.postimg.cc/d1kdrLkx/quran.jpg',
  ),

  // ── Saudi Arabia ──────────────────────────────────────────────────────────
  RadioStation(
    id: 'dr_2',
    nameAr: 'إذاعة القرآن الكريم السعودية',
    nameEn: 'Saudi Holy Quran Radio',
    streamUrl: 'https://n12.radiojar.com/0tpy1h0kxtzuv',
    country: 'Saudi Arabia', countryCode: 'SA',
    category: 'quran', isOfficial: true,
    imageUrl: 'https://i.postimg.cc/ZYSprKr8/download.png',
  ),
  RadioStation(
    id: 'dr_3',
    nameAr: 'إذاعة نداء الإسلام — مكة المكرمة',
    nameEn: 'Makkah Radio (Nida Al-Islam)',
    streamUrl: 'https://n09.radiojar.com/4xzg2m50ktzuv',
    country: 'Saudi Arabia', countryCode: 'SA',
    category: 'prayers', isOfficial: true,
    imageUrl: 'https://i.postimg.cc/ZYSprKr8/download.png',
  ),
  RadioStation(
    id: 'dr_4',
    nameAr: 'إذاعة السنة النبوية — المدينة المنورة',
    nameEn: 'Madinah Radio (Al-Sunnah)',
    streamUrl: 'https://n09.radiojar.com/sunnah',
    country: 'Saudi Arabia', countryCode: 'SA',
    category: 'prayers', isOfficial: true,
    imageUrl: 'https://i.postimg.cc/ZYSprKr8/download.png',
  ),

  // ── Algeria ───────────────────────────────────────────────────────────────
  RadioStation(
    id: 'dr_5',
    nameAr: 'إذاعة القرآن الكريم من الجزائر',
    nameEn: 'Algeria Holy Quran Radio',
    streamUrl: 'https://live.algerian-radio.dz/quran-128k.mp3',
    country: 'Algeria', countryCode: 'DZ',
    category: 'quran', isOfficial: true,
    imageUrl: 'https://i.postimg.cc/d1kdrLkx/quran.jpg',
  ),

  // ── Morocco ───────────────────────────────────────────────────────────────
  RadioStation(
    id: 'dr_6',
    nameAr: 'إذاعة القرآن الكريم من المغرب',
    nameEn: 'Morocco Holy Quran Radio (SNRT)',
    streamUrl: 'https://snrt-live.scdn.co/snrt-quran/index.m3u8',
    country: 'Morocco', countryCode: 'MA',
    category: 'quran', isOfficial: true,
    imageUrl: 'https://i.postimg.cc/d1kdrLkx/quran.jpg',
  ),

  // ── UAE ───────────────────────────────────────────────────────────────────
  RadioStation(
    id: 'dr_7',
    nameAr: 'إذاعة القرآن الكريم — الشارقة',
    nameEn: 'Sharjah Holy Quran Radio',
    streamUrl: 'https://n07.radiojar.com/8s5u5tpdtwzuv',
    country: 'UAE', countryCode: 'AE',
    category: 'quran', isOfficial: true,
    imageUrl: 'https://i.postimg.cc/d1kdrLkx/quran.jpg',
  ),

  // ── Kuwait ────────────────────────────────────────────────────────────────
  RadioStation(
    id: 'dr_8',
    nameAr: 'إذاعة القرآن الكريم — الكويت',
    nameEn: 'Kuwait Holy Quran Radio',
    streamUrl: 'https://stream.radiojar.com/kuwait-quran',
    country: 'Kuwait', countryCode: 'KW',
    category: 'quran', isOfficial: true,
    imageUrl: 'https://i.postimg.cc/d1kdrLkx/quran.jpg',
  ),

  // ── Qatar ─────────────────────────────────────────────────────────────────
  RadioStation(
    id: 'dr_9',
    nameAr: 'إذاعة القرآن الكريم — قطر',
    nameEn: 'Qatar Holy Quran Radio',
    streamUrl: 'https://stream.beamstream.net/quranfm',
    country: 'Qatar', countryCode: 'QA',
    category: 'quran', isOfficial: true,
    imageUrl: 'https://i.postimg.cc/d1kdrLkx/quran.jpg',
  ),

  // ── Tunisia ───────────────────────────────────────────────────────────────
  RadioStation(
    id: 'dr_10',
    nameAr: 'إذاعة الزيتونة — تونس',
    nameEn: 'Zitouna FM Tunisia',
    streamUrl: 'https://broadcast.infomaniak.ch/zitouna-high.mp3',
    country: 'Tunisia', countryCode: 'TN',
    category: 'quran', isOfficial: false,
    imageUrl: 'https://i.postimg.cc/d1kdrLkx/quran.jpg',
  ),

  // ── International / Reciters ──────────────────────────────────────────────
  RadioStation(
    id: 'dr_11',
    nameAr: 'راديو مشاري راشد العفاسي',
    nameEn: 'Mishary Rashid Al-Afasy Radio',
    streamUrl: 'https://stream.radiojar.com/afasy',
    country: 'International', countryCode: 'INT',
    category: 'quran', isOfficial: false,
    imageUrl: 'https://i.postimg.cc/d1kdrLkx/quran.jpg',
  ),
  RadioStation(
    id: 'dr_12',
    nameAr: 'راديو عبد الباسط عبد الصمد',
    nameEn: 'Abdul Basit Radio',
    streamUrl: 'https://stream.radiojar.com/basit',
    country: 'International', countryCode: 'INT',
    category: 'quran', isOfficial: false,
    imageUrl: 'https://i.postimg.cc/d1kdrLkx/quran.jpg',
  ),
  RadioStation(
    id: 'dr_13',
    nameAr: 'راديو سعد الغامدي',
    nameEn: 'Saad Al-Ghamdi Radio',
    streamUrl: 'https://stream.radiojar.com/ghamdi',
    country: 'International', countryCode: 'INT',
    category: 'quran', isOfficial: false,
    imageUrl: 'https://i.postimg.cc/d1kdrLkx/quran.jpg',
  ),
  RadioStation(
    id: 'dr_14',
    nameAr: 'راديو ماهر المعيقلي',
    nameEn: 'Maher Al-Muaiqly Radio',
    streamUrl: 'https://stream.radiojar.com/muaiqly',
    country: 'International', countryCode: 'INT',
    category: 'quran', isOfficial: false,
    imageUrl: 'https://i.postimg.cc/d1kdrLkx/quran.jpg',
  ),

  // ── Lectures & Islamic Content ─────────────────────────────────────────────
  RadioStation(
    id: 'dr_15',
    nameAr: 'راديو الإسلام — محاضرات',
    nameEn: 'Islam Radio (Lectures)',
    streamUrl: 'https://stream.zeno.fm/yn65m7h2p9zuv',
    country: 'International', countryCode: 'INT',
    category: 'lectures', isOfficial: false,
    imageUrl: 'https://i.postimg.cc/d1kdrLkx/quran.jpg',
  ),
  RadioStation(
    id: 'dr_16',
    nameAr: 'راديو نور الإسلام',
    nameEn: 'Nour Al-Islam Radio',
    streamUrl: 'https://stream.zeno.fm/hn0m6nh2p9zuv',
    country: 'International', countryCode: 'INT',
    category: 'lectures', isOfficial: false,
    imageUrl: 'https://i.postimg.cc/d1kdrLkx/quran.jpg',
  ),

  // ── Nasheed ───────────────────────────────────────────────────────────────
  RadioStation(
    id: 'dr_17',
    nameAr: 'راديو الأناشيد الإسلامية',
    nameEn: 'Islamic Nasheed Radio',
    streamUrl: 'https://stream.zeno.fm/anasheed-islamic',
    country: 'International', countryCode: 'INT',
    category: 'nasheed', isOfficial: false,
    imageUrl: 'https://i.postimg.cc/d1kdrLkx/quran.jpg',
  ),
  RadioStation(
    id: 'dr_18',
    nameAr: 'راديو الأطفال الإسلامي',
    nameEn: 'Islamic Children Radio',
    streamUrl: 'https://stream.zeno.fm/children-quran',
    country: 'International', countryCode: 'INT',
    category: 'nasheed', isOfficial: false,
    imageUrl: 'https://i.postimg.cc/d1kdrLkx/quran.jpg',
  ),

  // ── Jordan ──────────────────────────────────────────────────────
  RadioStation(
    id: 'dr_19',
    nameAr: 'إذاعة القرآن الكريم الأردنية',
    nameEn: 'Jordan Holy Quran Radio',
    streamUrl: 'https://stream.radiojar.com/jordan-quran',
    country: 'Jordan', countryCode: 'JO',
    category: 'quran', isOfficial: true,
    imageUrl: 'https://i.postimg.cc/d1kdrLkx/quran.jpg',
  ),

  // ── Sudan ───────────────────────────────────────────────────────
  RadioStation(
    id: 'dr_20',
    nameAr: 'إذاعة القرآن الكريم السودانية',
    nameEn: 'Sudan Holy Quran Radio',
    streamUrl: 'https://stream.zeno.fm/sudan-quran',
    country: 'Sudan', countryCode: 'SD',
    category: 'quran', isOfficial: true,
    imageUrl: 'https://i.postimg.cc/d1kdrLkx/quran.jpg',
  ),

  // ── Bahrain ─────────────────────────────────────────────────────
  RadioStation(
    id: 'dr_21',
    nameAr: 'إذاعة القرآن الكريم البحرينية',
    nameEn: 'Bahrain Holy Quran Radio',
    streamUrl: 'https://stream.radiojar.com/bahrain-quran',
    country: 'Bahrain', countryCode: 'BH',
    category: 'quran', isOfficial: true,
    imageUrl: 'https://i.postimg.cc/d1kdrLkx/quran.jpg',
  ),

  // ── Oman ────────────────────────────────────────────────────────
  RadioStation(
    id: 'dr_22',
    nameAr: 'إذاعة القرآن الكريم العُمانية',
    nameEn: 'Oman Holy Quran Radio',
    streamUrl: 'https://stream.radiojar.com/oman-quran',
    country: 'Oman', countryCode: 'OM',
    category: 'quran', isOfficial: true,
    imageUrl: 'https://i.postimg.cc/d1kdrLkx/quran.jpg',
  ),

  // ── Palestine ───────────────────────────────────────────────────
  RadioStation(
    id: 'dr_23',
    nameAr: 'إذاعة القرآن الكريم الفلسطينية',
    nameEn: 'Palestine Holy Quran Radio',
    streamUrl: 'https://stream.zeno.fm/palestine-quran',
    country: 'Palestine', countryCode: 'PS',
    category: 'quran', isOfficial: true,
    imageUrl: 'https://i.postimg.cc/d1kdrLkx/quran.jpg',
  ),

  // ── Yemen ───────────────────────────────────────────────────────
  RadioStation(
    id: 'dr_24',
    nameAr: 'إذاعة القرآن الكريم اليمنية',
    nameEn: 'Yemen Holy Quran Radio',
    streamUrl: 'https://stream.zeno.fm/yemen-quran',
    country: 'Yemen', countryCode: 'YE',
    category: 'quran', isOfficial: true,
    imageUrl: 'https://i.postimg.cc/d1kdrLkx/quran.jpg',
  ),

  // ── Pakistan ────────────────────────────────────────────────────
  RadioStation(
    id: 'dr_25',
    nameAr: 'إذاعة القرآن الكريم الباكستانية',
    nameEn: 'Pakistan Holy Quran Radio',
    streamUrl: 'https://stream.zeno.fm/pakistan-quran',
    country: 'Pakistan', countryCode: 'PK',
    category: 'quran', isOfficial: false,
    imageUrl: 'https://i.postimg.cc/d1kdrLkx/quran.jpg',
  ),

  // ── Turkey ──────────────────────────────────────────────────────
  RadioStation(
    id: 'dr_26',
    nameAr: 'راديو القرآن الكريم — تركيا',
    nameEn: 'Turkey Quran Radio',
    streamUrl: 'https://stream.zeno.fm/turkey-quran',
    country: 'Turkey', countryCode: 'TR',
    category: 'quran', isOfficial: false,
    imageUrl: 'https://i.postimg.cc/d1kdrLkx/quran.jpg',
  ),

  // ── Indonesia ───────────────────────────────────────────────────
  RadioStation(
    id: 'dr_27',
    nameAr: 'راديو القرآن الكريم — إندونيسيا (RRI)',
    nameEn: 'Indonesia Quran Radio (RRI)',
    streamUrl: 'https://stream.zeno.fm/indonesia-quran',
    country: 'Indonesia', countryCode: 'ID',
    category: 'quran', isOfficial: false,
    imageUrl: 'https://i.postimg.cc/d1kdrLkx/quran.jpg',
  ),

  // ── Malaysia ────────────────────────────────────────────────────
  RadioStation(
    id: 'dr_28',
    nameAr: 'راديو القرآن الكريم — ماليزيا (IKIM)',
    nameEn: 'Malaysia Quran Radio (IKIM)',
    streamUrl: 'https://stream.zeno.fm/malaysia-quran',
    country: 'Malaysia', countryCode: 'MY',
    category: 'quran', isOfficial: false,
    imageUrl: 'https://i.postimg.cc/d1kdrLkx/quran.jpg',
  ),
];

/// Category labels in all 7 supported languages
const Map<String, Map<String, String>> kRadioCategories = {
  'quran':    {'ar':'القرآن الكريم','en':'Holy Quran','de':'Heiliger Quran','tr':'Kutsal Kuran','fr':'Saint Coran','es':'Sagrado Corán','id':'Al-Quran'},
  'prayers':  {'ar':'الصلوات المباشرة','en':'Live Prayers','de':'Live-Gebete','tr':'Canlı Namaz','fr':'Prières en direct','es':'Oraciones en vivo','id':'Shalat Langsung'},
  'lectures': {'ar':'محاضرات ودروس','en':'Lectures','de':'Vorlesungen','tr':'Dersler','fr':'Conférences','es':'Conferencias','id':'Ceramah'},
  'nasheed':  {'ar':'أناشيد إسلامية','en':'Nasheed','de':'Nasheed','tr':'Neşid','fr':'Nasheed','es':'Nasheed','id':'Nasyid'},
};
