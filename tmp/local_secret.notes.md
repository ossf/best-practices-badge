# The file `tmp/local_secret.txt` is NOT a vulnerability

The `local_secret.txt` file is not a vulnerability.
This value is *only* used during
test and development. The fact that its value is public is
irrelevant, since those systems are not publicly accessible, or don't
have any real secrets, or both.

Its presence helps development and testing.

For more information, see the file `docs/assurance-case.md`.
