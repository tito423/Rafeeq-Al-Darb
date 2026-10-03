/// The books each shelf opens on: «ابدأ بها».
///
/// Owner, 2026-10-03: «في كل قسم تحط فيه اشهر وافضل ١٠ كتب بشروحاتهم … خلي
/// قسم المكتبة جذاب لاي قارئ مهما كان سنه او نضجه». A shelf of thirty titles
/// sorted by alphabet tells a newcomer nothing about where to start, so each
/// shelf below lists its ten best-known books, EASIEST FIRST (a matn before
/// its sharh, a short work before the encyclopaedia), and `books_tab.dart`
/// shows them in this order under their own heading, above the rest.
///
/// التزكية والرقائق is left as it is (the owner's word: «ماعدا الزهد والرقائق
/// سيبه»), and طالب العلم is a graded path of its own ([LibraryBook.shelfOrder]).
/// An id here that is not in the catalogue is skipped, never an error.
library;

import 'book_category.dart';

const Map<BookCategory, List<String>> featuredBookIds = {
  BookCategory.hadith: [
    'al_arbaun_an_nawawiyyah',
    'sharh_al_arbain_ibn_daqiq',
    'riyad_as_salihin',
    'dalil_al_falihin',
    'umdat_al_ahkam',
    'ihkam_al_ahkam',
    'subul_al_salam',
    'al_tajrid_al_sarih',
    'fath_al_bari',
    'sharh_al_nawawi_ala_muslim',
  ],
  BookCategory.fiqh: [
    'fath_al_qarib_al_mujib',
    'kifayat_al_akhyar',
    'maraqi_al_falah',
    'al_ikhtiyar_li_talil_al_mukhtar',
    'al_thamar_al_dani',
    'bulghat_al_salik',
    'al_uddah_sharh_al_umdah',
    'al_rawd_al_murbi',
    'al_fiqh_ala_al_madhahib_al_arbaa',
    'bidayat_al_mujtahid',
  ],
  BookCategory.aqidah: [
    'nur_al_zalam',
    'tahqiq_al_maqam',
    'al_aqaid_al_islamiyyah_ibn_badis',
    'tuhfat_al_murid',
    'sharh_al_aqidah_al_tahawiyyah',
    'qawaid_al_aqaid',
    'al_iqtisad_fil_itiqad',
    'al_ibanah_ashari',
    'minah_al_rawd_al_azhar',
    'lawami_al_anwar',
  ],
  BookCategory.tafsir: [
    'tafsir_al_jalalayn',
    'al_tashil_ibn_juzayy',
    'tafsir_ibn_kathir',
    'tafsir_al_baghawi',
    'tafsir_al_nasafi',
    'zad_al_masir',
    'asbab_al_nuzul_wahidi',
    'fath_al_qadir_shawkani',
    'tafsir_al_qurtubi',
    'tafsir_al_tabari',
  ],
  BookCategory.seerah: [
    'nur_al_yaqin',
    'al_rahiq_al_makhtum',
    'jawami_al_seerah',
    'khulasat_siyar_sayyid_al_bashar',
    'al_fusul_fi_seerat_ar_rasul',
    'seerat_ibn_hisham',
    'al_rawd_al_unuf',
    'zad_al_maad',
    'al_shifa_qadi_iyad',
    'al_mawahib_al_ladunniyyah',
  ],
  BookCategory.tarikh: [
    'qisas_al_anbiya_ibn_kathir',
    'tarikh_al_khulafa_suyuti',
    'al_ibar_dhahabi',
    'wafayat_al_ayan',
    'al_bidaya_wan_nihaya',
    'tarikh_ibn_khaldun',
    'al_kamil_fil_tarikh',
    'tarikh_al_tabari',
    'futuh_al_buldan',
    'talqih_fuhum_ahl_al_athar',
  ],
  BookCategory.adab: [
    'adab_al_dunya_wal_din',
    'al_akhlaq_wal_siyar',
    'adab_al_ishrah_ghazzi',
    'al_samt_wa_adab_al_lisan',
    'at_tibyan_hamalat_al_quran',
    'rawdat_al_uqala',
    'ghidha_al_albab',
    'al_adab_al_shariyyah',
    'al_mustatraf',
    'uyun_al_akhbar',
  ],
};
