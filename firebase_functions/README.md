## Firebase custom claim for Supabase

Supabase maps your JWT `role` claim to a Postgres role when calling the Data API / Storage / Realtime.

Firebase ID tokens **do not include** a `role` claim by default, so you must set:

- `role = authenticated`

You can do this using Firebase Auth blocking functions (Identity Platform) or a normal Cloud Function.

This repo does **not** deploy functions automatically. Use this as a reference only.

