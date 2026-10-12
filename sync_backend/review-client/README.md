# Paired reviewer authentication client (A-03)

These two browser files are the durable source of the locally tested changes
for `tito423/rafeeq-review`: replace its `index.html` and add `auth.js` together
with the protected Worker. Pushing that repository's main branch publishes
Pages; publication and Worker deployment require the owner's approval.

## Activation prerequisites

1. Obtain the owner's actual Google accounts and their existing reviewer names.
   Configure private `REVIEWERS` JSON containing `name`, `role` (`reviewer` or
   `admin`), and `sub` and/or `email`. Keep real identities and tokens out of git.
   Names must remain exact so existing D1 and device notes retain ownership.
   Missing, invalid, duplicate or ambiguous grants deny access. Prefer a stable
   Google subject; email-only grants require Google's verified authoritative
   Gmail/Workspace email. Administrators can read all reviews but write only
   under their own configured name.
2. Verify the existing OAuth client's authorized JavaScript origin includes
   `https://tito423.github.io`; test real Google sign-in and each role. The real
   SDK rendered locally, but Google rejected the localhost preview origin.
   No real sign-in or public-origin configuration has been verified yet.
3. Verify rate-limit namespace `3870018` is unique in the actual account with
   read-only inspection before any approved deployment.
4. Coordinate approved Worker and Pages activation. The previous anonymous
   client cannot write to the protected API. Reload the network-first site;
   retain local notes and their export before switching accounts.

The client keeps credentials only in memory, sends Bearer authorization only
to review routes, scopes notes by verified Google subject, and leaves the
original `review`/`reviewer` device keys intact as an exportable backup. An
exact matching canonical name can import that backup once. Reauthentication
and rate-limit retries preserve pending edits and deletes.

The existing site introduction and religious content were preserved, including
the older published snapshot's book-count text. These files do not regenerate
or validate that content. Any separately approved content refresh must use the
actual app catalogue; do not run the content generator as an auth migration.

## Local evidence

- Actual Worker/D1 authorization baseline: 7 failing cases and 2 controls;
  final backend suite: 102 passed, no skips; TypeScript clean.
- Client tests cover all seven locales, legacy backup, account isolation,
  pending drafts/deletes, late replies, and retry pacing. Local browser checks
  used generated test JWTs and a controlled Google callback with the actual
  Worker. Two accounts saved/read separate notes; the legacy export matched
  its original bytes. These checks do not prove live Google authentication.
- Full Flutter suite: 1337 passed, 4 existing skips; analyze clean.
