"""P3-43 follow-up (2026-09-05): the owner asked directly to "fetch and
organize all my books needed as I mentioned" — the original, genuinely
open-ended ask from `PHASE3_FEEDBACK.md`'s "A2" ("the library only has 5
books... I want you to download them all, Shamela-style"). Rather than
keep adding one title at a time, this pulls a real, large batch from the
same 3 already-established authors (Ibn Taymiyyah, al-Hakim al-Tirmidhi,
Ibn Abi al-Dunya) directly off their real shamela.ws author pages:

  - Ibn Abi al-Dunya (shamela author 273): literally EVERY one of his 61
    real listed works except the 2 already shipped and 2 genuine
    duplicates (a second edition of the same title already covered, and
    a short excerpt that's a subset of an already-shipped book) — every
    one of his real books is a short/medium focused treatise, no
    multi-volume mega-works, so "all" is honestly achievable for this
    author.
  - al-Hakim al-Tirmidhi (author 647): the 3 remaining real candidates
    from his page not already shipped.
  - Ibn Taymiyyah (author 54): every real listed work EXCEPT the ones
    genuinely too risky/large for this per-page-walk pipeline — any
    entry whose own shamela.ws listing doesn't give a page count at all
    (almost always a sign it's actually a multi-volume collection split
    across linked ids, e.g. "مجموع الفتاوى", "منهاج السنة النبوية",
    "درء تعارض العقل والنقل" — walking those with a linked-list crawler
    risks silently merging unrelated volumes or running for hours), and
    the 2 true outliers over 600 printed pages. Already-shipped titles
    and duplicate editions of the same work are also skipped.

Every id below was read directly off shamela.ws's real author-page
listing (`author_54_books2.txt`/`author_273_books2.txt` in this
session's scratchpad, dumped 2026-09-05), not invented — same discipline
as every other title this project has shipped. Reuses `build_book_text.
py`'s own parser/walker (`build_book`, `verify_and_print`) so the output
format and per-page HTML handling are identical to the already-shipped 11
books, just orchestrated over a much larger id list with per-book
failure isolation (one bad id must not abort the whole batch) and a
machine-readable summary for review afterward instead of a hand-read
transcript.
"""

import json
import os
import sys
import traceback
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(__file__))
from build_book_text import (  # noqa: E402
    build_book,
    fetch_meta_card,
    verify_and_print,
    write_book_json,
)

OUT_DIR = os.path.join(os.path.dirname(__file__), "book_text_build")
SUMMARY_PATH = os.path.join(os.path.dirname(__file__), "batch_summary.jsonl")

# (book_id, slug) — slug becomes the catalog `id` / output filename.
IBN_ABI_AL_DUNYA = [
    (13187, "islah_al_mal"),
    (6022, "istina_al_maruf"),
    (8207, "al_amr_bil_maruf_ibn_abi_al_dunya"),
    (12704, "al_ahwal"),
    (13003, "al_awliya_ibn_abi_al_dunya"),
    (6225, "al_ikhlas_wal_niyyah"),
    (12990, "al_ikhwan"),
    (12994, "al_ishraf_fi_manazil_al_ashraf"),
    (12996, "al_itibar_wa_aqab_al_surur"),
    (13009, "al_tawadu_wal_khumul"),
    (8253, "al_tawbah_ibn_abi_al_dunya"),
    (8254, "al_tawakkul_ala_allah"),
    (9306, "al_ju"),
    (13014, "al_hilm"),
    (13024, "al_rida_an_allah_biqadaihi"),
    (8256, "al_riqqah_wal_buka"),
    (8216, "al_zuhd_ibn_abi_al_dunya"),
    (13036, "al_shukr"),
    (8259, "al_sabr_wal_thawab_alayh"),
    (26356, "al_uzlah_wal_infirad"),
    (3732, "al_aql_wa_fadluh"),
    (8266, "al_uqubat"),
    (13044, "al_umr_wal_shayb"),
    (9307, "al_faraj_bad_al_shiddah"),
    (10628, "al_qubur_ibn_abi_al_dunya"),
    (22347, "al_qanaah_wal_taaffuf"),
    (13057, "al_mutamannin"),
    (13058, "al_muhtadirin"),
    (13064, "al_marad_wal_kaffarat"),
    (8273, "al_matar_wal_rad_wal_barq"),
    (13070, "al_manamat"),
    (13075, "al_nafaqah_ala_al_iyal"),
    (13076, "al_hamm_wal_huzn"),
    (28237, "al_hawatif"),
    (13077, "al_wajal_wal_tawthuq_bil_amal"),
    (13078, "al_wara"),
    (8220, "al_yaqin_ibn_abi_al_dunya"),
    (13113, "husn_al_zann_billah"),
    (26874, "hilm_muawiyah"),
    (8228, "dhamm_al_baghy"),
    (21546, "dhamm_al_dunya"),
    (8241, "dhamm_al_ghibah_wal_namimah"),
    (13117, "dhamm_al_muskir"),
    (8230, "dhamm_al_malahi"),
    (12737, "sifat_al_jannah_ibn_abi_al_dunya"),
    (13128, "sifat_al_nar"),
    (10799, "fadail_ramadan_ibn_abi_al_dunya"),
    (11030, "qira_al_dayf"),
    (13149, "qada_al_hawaij"),
    (8242, "kalam_al_layali_wal_ayyam"),
    (12936, "mujabu_al_dawah"),
    (12739, "muhasabat_al_nafs"),
    (13152, "mudarat_al_nas"),
    (12751, "maqtal_ali"),
    (8061, "makaid_al_shaytan"),
    (13180, "makarim_al_akhlaq_ibn_abi_al_dunya"),
    (13183, "man_asha_bad_al_mawt"),
]

AL_HAKIM_AL_TIRMIDHI = [
    (37033, "riyadat_al_nafs"),
    (25950, "al_manahi"),
    (6893, "al_amthal_min_al_kitab_wal_sunnah"),
]

IBN_TAYMIYYAH = [
    (22812, "ahadith_al_qusas"),
    (1512, "amrad_al_qulub_wa_shifauha"),
    (9370, "al_arbaun_al_taymiyyah"),
    (30903, "al_amr_bil_maruf_ibn_taymiyyah"),
    (37816, "al_ikhnaiyyah"),
    (9220, "al_iklil_fi_al_mutashabih_wal_tawil"),
    (7564, "al_iman_ibn_taymiyyah"),
    (303, "al_intisar_li_ahl_al_athar"),
    (6827, "al_tuhfah_al_iraqiyyah"),
    (22666, "al_tadmuriyyah"),
    (7263, "al_hisbah_fil_islam"),
    (2908, "al_radd_ala_man_qala_bi_fana_al_jannah_wal_nar"),
    (7631, "al_risalah_al_akmaliyyah"),
    (10784, "al_risalah_al_arshiyyah"),
    (7635, "al_risalah_al_madaniyyah"),
    (6826, "al_zuhd_wal_wara_wal_ibadah"),
    (31237, "al_siyasah_al_shariyyah"),
    (21499, "al_furqan_bayn_awliya_al_rahman_wa_awliya_al_shaytan"),
    (792, "al_qasidah_al_taiyyah_fil_qadar"),
    (21578, "al_kalim_al_tayyib"),
    (327, "takhrij_al_kalim_al_tayyib"),
    (96844, "al_masail_al_maridiniyyah"),
    (8596, "al_nusayriyyah_tughat_suriya"),
    (8983, "al_wasitah_bayn_al_haqq_wal_khalq"),
    (264, "tahqiq_al_iman"),
    (301, "tahqiq_al_ihtijaj_bil_qadar"),
    (22667, "tahqiq_al_qawl_fi_isa_kalimat_allah"),
    (291, "jawab_al_itiradat_al_misriyyah"),
    (21565, "jawab_fi_al_half_bighayr_allah"),
    (11150, "hijab_al_marah_wa_libasuha_fil_salah"),
    (11162, "huquq_al_al_al_bayt"),
    (892, "ras_al_husayn"),
    (11216, "risalah_fi_usul_al_din"),
    (38157, "risalah_fi_fadl_al_khulafa_al_rashidin"),
    (4118, "raf_al_malam_an_al_aimmah_al_alam"),
    (6919, "ziyarat_al_qubur_wal_istinjad_bil_maqbur"),
    (11238, "sujud_al_tilawah"),
    (11240, "sunnat_al_jumuah"),
    (11248, "sharh_al_aqidah_al_isfahaniyyah"),
    (11258, "sharh_hadith_al_nuzul"),
    (17073, "sharh_umdat_al_fiqh_sifat_al_salah"),
    (133364, "fasl_fi_tazkiyat_al_nafs"),
    (22808, "fadl_abi_bakr_al_siddiq"),
    (22648, "qaidah_dhikr_malabis_al_nabi"),
    (11285, "qaidah_jamiah_fi_tawhid_allah"),
    (22650, "qaidah_hasanah_fil_baqiyat_al_salihat"),
    (12769, "qaidah_azimah_fil_farq_bayn_ibadat_ahl_al_islam"),
    (11288, "qaidah_fil_inghimas_fil_aduw"),
    (12153, "qaidah_fil_sabr"),
    (11289, "qaidah_fil_mahabbah"),
    (147669, "qaidah_mukhtasarah_fi_qital_al_kuffar"),
    (11290, "qaidah_mukhtasarah_fi_wujub_taat_allah"),
    (11578, "masalah_fil_murabatah_bil_thughur"),
    (22651, "masalah_fil_kanais"),
    (147670, "masalah_fi_tawhid_al_falasifah"),
    (22668, "masalah_fima_idha_kana_fil_abd_mahabbah"),
    (12081, "muqaddimah_fi_usul_al_tafsir"),
    (147665, "manasik_al_hajj_ibn_taymiyyah"),
    (8630, "naqd_maratib_al_ijma"),
    (22649, "qaidah_jalilah_fil_tawassul_wal_wasilah"),
]

# --- round 2 (2026-09-05, same day): the owner explicitly asked for "all
# all the authors specially ibn alqayyem and ibn aljawzy and all the rest"
# — both already have one book each in the catalog (al_fawaid, sayd_al_
# khatir). Same discipline as round 1: every id read directly off their
# real shamela.ws author pages (author 14 / author 51), one edition per
# real distinct work (both wrote the same title under 2+ Shamela editions
# constantly — picked whichever real edition is shortest/cleanest rather
# than shipping true duplicates), and — the single biggest exclusion
# category for these two specifically — every "?"-page-count entry
# skipped as a genuine multi-volume risk. That excludes some of their
# most *famous* works (زاد المعاد, مدارج السالكين, إعلام الموقعين, صفة
# الصفوة, الموضوعات, تفسير زاد المسير...) — not an oversight, a real
# consequence of how those specific works are multi-volume on Shamela
# and this pipeline walks one linked chain of pages, not a whole shelf.
IBN_AL_QAYYIM = [
    (10713, "asma_muallafat_ibn_taymiyyah"),
    (134, "ighathat_al_lahfan_fi_hukm_talaq_al_ghadban"),
    (928, "al_amthal_fil_quran_ibn_al_qayyim"),
    (7572, "al_tibyan_fi_aqsam_al_quran"),
    (1477, "al_jami_fi_amthal_al_quran"),
    (158, "al_daa_wal_dawa"),
    (14211, "al_risalah_al_tabukiyyah"),
    (6462, "al_ruh_ibn_al_qayyim"),
    (23649, "al_tibb_al_nabawi"),
    (11495, "al_turuq_al_hukmiyyah"),
    (18169, "al_furusiyyah_al_muhammadiyyah"),
    (18318, "al_kalam_ala_masalat_al_sama"),
    (8566, "al_manar_al_munif"),
    (216, "al_wabil_al_sayyib"),
    (6266, "tuhfat_al_mawdud_bi_ahkam_al_mawlud"),
    (6829, "jala_al_afham"),
    (11147, "hadi_al_arwah_ila_bilad_al_afrah"),
    (11797, "risalat_ibn_al_qayyim_ila_ahad_ikhwanih"),
    (257, "raf_al_yadayn_fil_salah"),
    (11229, "rawdat_al_muhibbin"),
    (12021, "shifa_al_alil"),
    (30842, "sifat_al_munafiqin"),
    (6841, "sigh_al_hamd"),
    (12029, "tariq_al_hijratayn"),
    (11274, "uddat_al_sabirin"),
    (11329, "faidah_jalilah_fi_qawaid_al_asma_al_husna"),
    (18152, "fatya_fi_sighat_al_hamd"),
    (11375, "nuniyyat_ibn_al_qayyim"),
    (5705, "hidayat_al_hayara"),
]

IBN_AL_JAWZI = [
    (11068, "akhbar_al_humqa_wal_mughaffalin"),
    (6952, "akhbar_al_zuraf_wal_mutamajinin"),
    (21563, "akhbar_al_nisa_ibn_al_jawzi"),
    (22, "amar_al_ayan"),
    (22002, "ikhbar_ahl_al_rusukh_fil_fiqh"),
    (9369, "ilam_al_alim_bi_naskh_al_hadith"),
    (6938, "al_adhkiya"),
    (9379, "al_birr_wal_silah_ibn_al_jawzi"),
    (6858, "al_tadhkirah_fil_waz"),
    (6789, "al_thabat_ind_al_mamat"),
    (22340, "al_hathth_ala_hifz_al_ilm"),
    (3617, "al_qussas_wal_mudhakkirin"),
    (122409, "al_mujtaba_min_al_mujtana"),
    (6940, "al_mudhish"),
    (8554, "al_musaffa_bi_akuff_ahl_al_rusukh"),
    (26892, "al_muqliq_ibn_al_jawzi"),
    (2506, "bahr_al_dumu"),
    (6948, "bustan_al_waizin"),
    (10927, "tarikh_bayt_al_maqdis"),
    (10450, "tadhkirat_al_arib_fi_tafsir_al_gharib"),
    (26894, "tazim_al_fatya"),
    (16541, "taqwim_al_lisan"),
    (11438, "talbis_iblis"),
    (6700, "talqih_fuhum_ahl_al_athar"),
    (11023, "tanbih_al_naim_al_ghamr"),
    (5748, "tanwir_al_ghabash"),
    (26677, "hifz_al_umr"),
    (313, "fadail_bayt_al_maqdis"),
    (1402, "funun_al_afnan_fi_uyun_ulum_al_quran"),
    (10437, "muthir_al_gharam_al_sakin"),
    (9619, "mashyakhat_ibn_al_jawzi"),
    (8160, "mawaiz_ibn_al_jawzi_al_yaqutah"),
    (38121, "nawasikh_al_quran"),
]

# --- round 3 (2026-09-05, same day): "proceed with all other author's
# books download" — Imam al-Nawawi already has one book in the catalog
# (رياض الصالحين). Same discipline: every id read directly off his real
# shamela.ws author page (author 44), "?"-page-count entries excluded as
# multi-volume risk (this is where المجموع شرح المهذب، تهذيب الأسماء
# واللغات، روضة الطالبين، شرح صحيح مسلم، خلاصة الأحكام all live — all
# genuinely multi-volume), duplicate editions of an already-covered title
# picked once, and the one printMatches=False edition excluded.
#
# Deliberately NOT expanding "Ibn Qudamah al-Maqdisi" this round: the
# existing mukhtasar_minhaj_al_qasidin entry credits "الإمام موفق الدين
# ابن قدامة المقدسي", but that book's real shamela.ws author link
# (author 2586) is titled "المقدسي، نجم الدين" — a different laqab
# (Najm al-Din, not Ibn Qudamah's own Muwaffaq al-Din) — a real identity
# mismatch found by checking, not assumed away. Mining that author's
# other works under an unverified identity risks attributing someone
# else's writings to Ibn Qudamah; flagged to the owner instead of guessed
# at.
NAWAWI = [
    (6345, "adab_al_fatwa_wal_mufti"),
    (1956, "al_adhkar_lil_nawawi"),
    (12836, "al_arbaun_al_nawawiyyah"),
    (6285, "al_usul_wal_dawabit"),
    (5064, "al_ijaz_fi_sharh_sunan_abi_dawud"),
    (96232, "al_idah_fi_manasik_al_hajj_wal_umrah"),
    (1969, "al_tibyan_fi_adab_hamalat_al_quran"),
    (5586, "al_taqrib_wal_taysir"),
    (12719, "bustan_al_arifin"),
    (7043, "tahrir_alfaz_al_tanbih"),
    (512, "tahqiq_riyad_al_salihin_lil_albani"),
    (11137, "juz_fih_dhikr_iiqad_al_salaf_fil_huruf_wal_aswat"),
    (6134, "daqaiq_al_minhaj"),
    (497, "fatawa_al_nawawi"),
    (12096, "minhaj_al_talibin"),
]

ALL_BOOKS = (
    [(bid, slug, "ibn_abi_al_dunya") for bid, slug in IBN_ABI_AL_DUNYA]
    + [(bid, slug, "al_hakim_al_tirmidhi") for bid, slug in AL_HAKIM_AL_TIRMIDHI]
    + [(bid, slug, "ibn_taymiyyah") for bid, slug in IBN_TAYMIYYAH]
    + [(bid, slug, "ibn_al_qayyim") for bid, slug in IBN_AL_QAYYIM]
    + [(bid, slug, "ibn_al_jawzi") for bid, slug in IBN_AL_JAWZI]
    + [(bid, slug, "nawawi") for bid, slug in NAWAWI]
)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    want = sys.argv[1:]
    items = ALL_BOOKS
    if want:
        wanted_slugs = set(want)
        items = [it for it in items if it[1] in wanted_slugs]

    with open(SUMMARY_PATH, "a", encoding="utf-8") as summary:
        for i, (book_id, slug, author_key) in enumerate(items, 1):
            print(f"\n=== [{i}/{len(items)}] {slug}  (shamela {book_id}, {author_key}) ===")
            try:
                meta_card = fetch_meta_card(book_id)
                source_label = (
                    f"المكتبة الشاملة — {meta_card['title'] or slug}، "
                    f"{meta_card['author'] or author_key}"
                )
                editor_m = None
                for line in meta_card["card"].splitlines():
                    if line.startswith("المحقق:") and "-" not in line.split(":", 1)[1].strip()[:2]:
                        editor_m = line.split(":", 1)[1].strip()
                    if line.startswith("الناشر:"):
                        source_label += f"، {line.split(':', 1)[1].strip()}"
                if editor_m:
                    source_label += f"، تحقيق {editor_m}"

                doc = build_book(slug, book_id, source_label)
                out = os.path.join(OUT_DIR, f"{slug}.json")
                before, after = write_book_json(doc, out)
                print(f"  wrote {out}  ({after/1024:.0f} KB gzip, {before/1024:.0f} KB raw)")
                verify_and_print(doc)

                n_paras = sum(len(p["paras"]) for p in doc["pages"])
                empty_pages = sum(1 for p in doc["pages"] if not p["paras"])
                record = {
                    "slug": slug,
                    "book_id": book_id,
                    "author_key": author_key,
                    "titleAr": meta_card["title"],
                    "authorAr": meta_card["author"],
                    "sourceLabel": source_label,
                    "pageCount": len(doc["pages"]),
                    "sectionCount": len(doc["toc"]),
                    "paraCount": n_paras,
                    "emptyPages": empty_pages,
                    "printMatches": doc["meta"]["printMatches"],
                    "printReliable": doc["meta"]["printReliable"],
                    "sizeBytes": after,
                    "sizeBytesRaw": before,
                    "status": "ok",
                    "builtAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                }
            except Exception as e:  # noqa: BLE001 — one bad id must not kill the batch
                print(f"  !! FAILED: {e}")
                traceback.print_exc()
                record = {
                    "slug": slug,
                    "book_id": book_id,
                    "author_key": author_key,
                    "status": "failed",
                    "error": str(e),
                    "builtAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                }
            summary.write(json.dumps(record, ensure_ascii=False) + "\n")
            summary.flush()

    print(f"\nDone. Summary appended to {SUMMARY_PATH}")


if __name__ == "__main__":
    main()
