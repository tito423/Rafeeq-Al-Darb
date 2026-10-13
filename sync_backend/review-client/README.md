# Review site client (`tito423/rafeeq-review`)

The source of the two files the review site needs from this change:
`index.html` (the live site's page, patched) and `review-key.js`. Copy both
into `tito423/rafeeq-review` and push its `main` branch to publish Pages.

## How reviewers get in (owner, 2026-10-13)

No account and no reviewer list. The owner sends the link; a reviewer
writes his name and starts writing notes.

A-03 was that anyone could post under any name. Now the first browser to use
a name calls `POST /review/register` and receives a random key (32 bytes,
base64url). The Worker stores only its SHA-256. Writing notes needs that key
in `Authorization: Bearer`, and the notes are saved under the key's name.
Another person typing the same name is told it is taken and asked for a
different one. Reading notes stays open, as the site always was.

- A browser that already used a name before keys existed claims it silently
  on first load; if someone claimed it first, the name box opens with it.
- A reviewer on a second device, or after clearing the browser, cannot reuse
  his name there (it is taken by his first device); he picks a variant.
- A `401` (key unknown) clears the key and reopens the name box; queued notes
  stay in the browser and go up after a name is set.

Tests: `test/reviewer-auth.test.mjs` (Worker, Miniflare + local D1) and
`test/review-key.test.mjs` (this client module).
