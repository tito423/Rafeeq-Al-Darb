# Classifier prompt for one batch (SAMIN_REVIEW.md step 3)

You are an expert in Qur'anic i'rab. Read the batch file named in your task
(`scripts/own_irab/pk/bNNN.txt`). Each `###` packet is ONE word, shown in
[brackets] inside its ayah, with:
- `OURS`: our i'rab of that word.
- `ALT <book>`: another named book's different view (may be absent).
- `SAMIN`: what al-Samin «الدر المصون» says (a cut; `silent` = nothing on it;
  `(no direct quote; page start)` = the start of his page on the ayah, which may
  or may not concern this word).
- `JADWAL`, `DARWISH`: passages from those books near the word (`-` = none found).

For each packet decide ONE verdict about OURS:
- `OURS_OK`   - a source in the packet states the same analysis as OURS
                 (role and case), or al-Samin lists it among the permitted views.
- `OURS_WRONG`- a source in the packet states a different analysis AND gives a
                 reason OURS cannot stand, or OURS contradicts the ayah's own vowel
                 or grammar on its face (e.g. calls a منصوب word فاعل).
- `NO_SOURCE` - nothing in the packet speaks to this word's role; OURS is not
                 contradicted but not confirmed either.
- `UNCLEAR`   - the sources speak but you cannot tell.

Rules: judge only from the packet text and sound grammar; never invent a source.
A difference only in the mahall of a clause, or in what a jar-majrur attaches to,
is NOT `OURS_WRONG`. Do not rewrite anything.

Write your answer with the Write tool to `scripts/own_irab/pk/out_bNNN.tsv`,
one line per packet, tab-separated, no header:
`id<TAB>verdict<TAB>evidence`
where evidence is at most 20 words quoted from the packet (book: «quote»), or `-`.
Then reply with only: `bNNN: <count> lines`.
