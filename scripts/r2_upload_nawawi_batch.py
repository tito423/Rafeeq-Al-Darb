"""Nawawi round: uploads the 15 newly-built Imam al-Nawawi books
(fetch_authors_batch.py's NAWAWI list) to R2, verifying each with
head_object afterward. Files are already gzip-compressed on disk by
write_book_json (the gzip-to-R2 standing rule) - uploaded as-is, no
Content-Encoding header (the app detects gzip by magic bytes, not by
that header, per the established opaque-byte-stream approach).
"""

import os
import sys

import boto3

NAWAWI_SLUGS = [
    "adab_al_fatwa_wal_mufti",
    "al_adhkar_lil_nawawi",
    "al_arbaun_al_nawawiyyah",
    "al_usul_wal_dawabit",
    "al_ijaz_fi_sharh_sunan_abi_dawud",
    "al_idah_fi_manasik_al_hajj_wal_umrah",
    "al_tibyan_fi_adab_hamalat_al_quran",
    "al_taqrib_wal_taysir",
    "bustan_al_arifin",
    "tahrir_alfaz_al_tanbih",
    "tahqiq_riyad_al_salihin_lil_albani",
    "juz_fih_dhikr_iiqad_al_salaf_fil_huruf_wal_aswat",
    "daqaiq_al_minhaj",
    "fatawa_al_nawawi",
    "minhaj_al_talibin",
]

env = {}
with open(r"E:\My Projects\Rafiq-Al-Darb\scripts\.env") as f:
    for line in f:
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            k, v = line.split("=", 1)
            env[k] = v

s3 = boto3.client(
    "s3",
    endpoint_url=env["R2_ENDPOINT"],
    aws_access_key_id=env["R2_ACCESS_KEY_ID"],
    aws_secret_access_key=env["R2_SECRET_ACCESS_KEY"],
    region_name="auto",
)

BUCKET = "rafeeq-content"

uploaded = 0
failed = []
for slug in NAWAWI_SLUGS:
    path = rf"E:\My Projects\Rafiq-Al-Darb\scripts\book_text_build\{slug}.json"
    try:
        with open(path, "rb") as f:
            data = f.read()
    except FileNotFoundError:
        failed.append(slug)
        continue
    key = f"books/text/{slug}.json"
    s3.put_object(Bucket=BUCKET, Key=key, Body=data, ContentType="application/json")
    uploaded += 1

print(f"Uploaded {uploaded}/{len(NAWAWI_SLUGS)}; missing: {failed}")

print("\n--- verify (head_object) ---")
mismatches = []
for slug in NAWAWI_SLUGS:
    path = rf"E:\My Projects\Rafiq-Al-Darb\scripts\book_text_build\{slug}.json"
    if not os.path.exists(path):
        continue
    local_size = os.path.getsize(path)
    key = f"books/text/{slug}.json"
    head = s3.head_object(Bucket=BUCKET, Key=key)
    r2_size = head["ContentLength"]
    if r2_size != local_size:
        mismatches.append((slug, local_size, r2_size))

if mismatches:
    print("SIZE MISMATCHES:", mismatches)
else:
    print(f"All {len(NAWAWI_SLUGS)} verified: R2 size matches local file exactly.")
