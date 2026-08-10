# Security (Top level page)

## Vulnerability reporting (security issues)

If you find a significant vulnerability, or evidence of one,
please report it privately.

We prefer that you use the [GitHub mechanism for privately reporting a vulnerability](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing/privately-reporting-a-security-vulnerability#privately-reporting-a-security-vulnerability). Under the
[main repository's security tab](https://github.com/ossf/best-practices-badge/security), in the left sidebar, under "Reporting", click
 Advisories, then click "Report a vulnerability" to open the advisory form.

If you can't do that,
please send an email to the security contacts that you have such
information, and we'll tell you the next steps.
For now, the security contacts are:
David A. Wheeler <dwheelerNOSPAM@dwheeler.com> and
Jason Dossett <jdossettNOSPAM@utdallas.edu>.
(remove the NOSPAM markers).
If for some reason that doesn't work, as this is an OpenSSF project,
contact the OpenSSF security reporting email address,
which is <securityNOSPAM@openssf.org> (remove NOSPAM).

If you report via email,
please use an email system (like Gmail) that supports
hop-to-hop (transport) encryption.
The preferred approach is an email system that uses
Mail Transfer Agent Strict Transport Security (MTA-STS), as this
always uses TLS to authenticate destinations and encrypts contents.
If you can't do that, use STARTTLS.
Your email client should use encryption to communicate with
your email system (i.e., if you use a web-based email client then use HTTPS,
and if you use email client software then configure it to use encryption).
Hop-to-hop encryption isn't as strong as end-to-end encryption,
but we've decided that it's strong enough for this purpose
and it's much easier to get everyone to use it.

We will gladly give credit to anyone who reports a vulnerability
so that we can fix it.
If you want to remain anonymous or pseudonymous instead,
please let us know that; we will gladly respect your wishes.

We gladly welcome patches to fix such vulnerabilities!
See [CONTRIBUTING.md](CONTRIBUTING.md) for information
about contributions.

## Security requirements and security assurance case

For a description in more detail about the security requirements
of this system, and the security assurance case that explains
why we think we this system is adequately secure, see our
[security assurance case](docs/assurance-case.md).
