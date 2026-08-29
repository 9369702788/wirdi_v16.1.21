
import '../models/radio_station.dart';

/// 18 curated Islamic radio stations embedded directly in the app.
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
];

/// Category labels in all 7 supported languages
const Map<String, Map<String, String>> kRadioCategories = {
  'quran':    {'ar':'القرآن الكريم','en':'Holy Quran','de':'Heiliger Quran','tr':'Kutsal Kuran','fr':'Saint Coran','es':'Sagrado Corán','id':'Al-Quran'},
  'prayers':  {'ar':'الصلوات المباشرة','en':'Live Prayers','de':'Live-Gebete','tr':'Canlı Namaz','fr':'Prières en direct','es':'Oraciones en vivo','id':'Shalat Langsung'},
  'lectures': {'ar':'محاضرات ودروس','en':'Lectures','de':'Vorlesungen','tr':'Dersler','fr':'Conférences','es':'Conferencias','id':'Ceramah'},
  'nasheed':  {'ar':'أناشيد إسلامية','en':'Nasheed','de':'Nasheed','tr':'Neşid','fr':'Nasheed','es':'Nasheed','id':'Nasyid'},
};
