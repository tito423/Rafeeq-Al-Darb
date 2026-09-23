# -*- coding: utf-8 -*-
"""How much of R2's free tier this month has used — read live, never guessed.

The owner, 2026-09-23: «مش عاوز ادفع فلس واحد» and «اعمل التوكنز الزيادة عشان
تبقى دايما متابعه». R2 bills three things, each with a monthly free
allowance; ingress and egress are free:

    storage      10 GB-month
    Class A      1,000,000 operations  (writes and lists: PutObject,
                 UploadPart, ListObjects…)
    Class B      10,000,000 operations (reads: GetObject, HeadObject…)

Storage is measured here by listing the bucket (the S3 key can do that).
The operation counts come from Cloudflare's GraphQL Analytics API, which the
R2 S3 key cannot read — it needs the account API token in `scripts/.env`
(`CF_API_TOKEN`) to carry **Account Analytics: Read**. Without it this script
says so and stops; it never estimates a number it could not read.

The window is the calendar month so far, in UTC. Cloudflare resets the R2
free allowance monthly; the exact dates of the billing cycle are shown under
Manage Account -> Billing, and are read here too if the token carries
**Billing: Read**.

    py -3 scripts/r2_usage.py

Writes nothing but `_r2_usage_report.txt` (UTF-8, trap #10), and never prints
a credential or the account id.
"""

import datetime as dt
import io
import json
import os
import ssl
import urllib.error
import urllib.request

from r2_common import BUCKET, ca_bundle, load_env, r2_client

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPORT = os.path.join(ROOT, "_r2_usage_report.txt")
FREE = {"storage_gb": 10, "class_a": 1_000_000, "class_b": 10_000_000}

# Cloudflare's own split of R2 actions into the two billed classes.
CLASS_A = {"ListBuckets", "PutBucket", "ListObjects", "ListObjectsV2",
           "PutObject", "CopyObject", "CompleteMultipartUpload",
           "CreateMultipartUpload", "ListMultipartUploads", "UploadPart",
           "UploadPartCopy", "ListParts", "PutBucketEncryption",
           "PutBucketCors", "PutBucketLifecycleConfiguration",
           "LifecycleStorageTierTransition"}
CLASS_B = {"HeadBucket", "HeadObject", "GetObject", "UsageSummary",
           "GetBucketEncryption", "GetBucketLocation", "GetBucketCors",
           "GetBucketLifecycleConfiguration"}


def _api(env, url, body=None):
    req = urllib.request.Request(
        url,
        data=None if body is None else json.dumps(body).encode(),
        method="GET" if body is None else "POST",
        headers={"Authorization": "Bearer " + env["CF_API_TOKEN"],
                 "Content-Type": "application/json",
                 "User-Agent": "RafeeqAlDarb (https://github.com/tito423/Rafeeq-Al-Darb)"})
    ctx = ssl.create_default_context(cafile=ca_bundle())
    try:
        with urllib.request.urlopen(req, context=ctx, timeout=60) as r:
            return json.loads(r.read())
    except urllib.error.HTTPError as e:
        return {"success": False, "http": e.code}


def class_a_used():
    """(Class A operations used in the current billing period, period end) —
    read live, or (None, None) when it cannot be read. For the mirror script's
    guard: it must stop before the free allowance, not after."""
    env = load_env()
    sub = _api(env, "https://api.cloudflare.com/client/v4/accounts/%s/subscriptions"
               % env["CF_ACCOUNT_ID"])
    if not (sub.get("success") and sub.get("result")):
        return None, None
    s0 = sub["result"][0]
    ps, pe = s0.get("current_period_start"), s0.get("current_period_end")
    if not ps:
        return None, None
    now = dt.datetime.now(dt.timezone.utc)
    q = ("query($acc:String!,$s:Time!,$e:Time!){viewer{accounts(filter:"
         "{accountTag:$acc}){ops:r2OperationsAdaptiveGroups(limit:1000,"
         "filter:{datetime_geq:$s,datetime_leq:$e}){sum{requests}"
         "dimensions{actionType}}}}}")
    res = _api(env, "https://api.cloudflare.com/client/v4/graphql",
               {"query": q, "variables": {
                   "acc": env["CF_ACCOUNT_ID"],
                   "s": ps.replace("+00:00", "Z"),
                   "e": now.strftime("%Y-%m-%dT%H:%M:%SZ")}})
    if res.get("errors") or not res.get("data"):
        return None, pe
    groups = res["data"]["viewer"]["accounts"][0]["ops"]
    return sum(g["sum"]["requests"] for g in groups
               if g["dimensions"]["actionType"] in CLASS_A), pe


def main():
    env = load_env()
    out = []
    now = dt.datetime.now(dt.timezone.utc)
    start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    out.append("R2 usage — read %s UTC" % now.strftime("%Y-%m-%d %H:%M"))

    total = n = 0
    for page in r2_client().get_paginator("list_objects_v2").paginate(Bucket=BUCKET):
        for o in page.get("Contents", []):
            total += o["Size"]
            n += 1
    out.append("storage now      %.3f GB in %d objects   (free %d GB)  -> %.0f %%"
               % (total / 1e9, n, FREE["storage_gb"],
                  100 * total / 1e9 / FREE["storage_gb"]))

    # The billing period first: the free allowance is counted over IT, not
    # over the calendar month. Read live on 2026-09-23 it ran from the 24th
    # to the 24th, so a calendar-month count would have been the wrong sum.
    sub = _api(env, "https://api.cloudflare.com/client/v4/accounts/%s/subscriptions"
               % env["CF_ACCOUNT_ID"])
    if sub.get("success") and sub.get("result"):
        s0 = sub["result"][0]
        ps, pe = s0.get("current_period_start"), s0.get("current_period_end")
        out.append("billing period   %s -> %s  (%s)"
                   % (ps, pe, (s0.get("rate_plan") or {}).get("public_name", "?")))
        if ps:
            start = dt.datetime.fromisoformat(ps.replace("Z", "+00:00"))
    else:
        out.append("billing period   NOT READ — the token lacks 'Billing: Read'; "
                   "counting the calendar month instead.")

    q = ("query($acc:String!,$s:Time!,$e:Time!){viewer{accounts(filter:"
         "{accountTag:$acc}){ops:r2OperationsAdaptiveGroups(limit:1000,"
         "filter:{datetime_geq:$s,datetime_leq:$e}){sum{requests}"
         "dimensions{actionType}}}}}")
    res = _api(env, "https://api.cloudflare.com/client/v4/graphql",
               {"query": q, "variables": {
                   "acc": env["CF_ACCOUNT_ID"],
                   "s": start.strftime("%Y-%m-%dT%H:%M:%SZ"),
                   "e": now.strftime("%Y-%m-%dT%H:%M:%SZ")}})
    if res.get("errors") or not res.get("data"):
        out.append("operations       NOT READ — the token lacks "
                   "'Account Analytics: Read' (Cloudflare: My Profile -> API "
                   "Tokens -> Edit). Nothing is estimated in its place.")
    else:
        groups = res["data"]["viewer"]["accounts"][0]["ops"]
        a = sum(g["sum"]["requests"] for g in groups
                if g["dimensions"]["actionType"] in CLASS_A)
        b = sum(g["sum"]["requests"] for g in groups
                if g["dimensions"]["actionType"] in CLASS_B)
        odd = sorted({g["dimensions"]["actionType"] for g in groups}
                     - CLASS_A - CLASS_B)
        out.append("counted from     %s UTC to now" % start.strftime("%Y-%m-%d %H:%M"))
        out.append("Class A          %d of %d  -> %.2f %%"
                   % (a, FREE["class_a"], 100 * a / FREE["class_a"]))
        out.append("Class B          %d of %d  -> %.2f %%"
                   % (b, FREE["class_b"], 100 * b / FREE["class_b"]))
        # Deletes are not billed at all on R2; anything else unknown is shown.
        free = {x for x in odd if x.startswith("Delete")}
        if free:
            out.append("not billed       %s" % ", ".join(sorted(free)))
        if set(odd) - free:
            out.append("unclassified     %s" % ", ".join(sorted(set(odd) - free)))

    text = "\n".join(out)
    io.open(REPORT, "w", encoding="utf-8").write(text + "\n")
    print(text.encode("ascii", "replace").decode())


if __name__ == "__main__":
    main()
