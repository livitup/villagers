# Changelog

All notable changes to Villagers are documented here. This project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-07-03

First public release. Villagers is a Ruby on Rails application that helps hacker
conference village organizers manage volunteer scheduling. This release gathers
the work done during the private beta.

### Authentication & Access

- **OAuth2 single sign-on (hybrid)** with a role-based access gate and a
  self-registration toggle, so a village can authenticate volunteers against its
  own identity provider (#164).
- Upgraded to **Devise 5.0** and fixed Turbo form submissions (#163).
- **Authentication is now required by default** — anonymous requests to
  protected pages redirect to sign-in instead of erroring (#188).
- Conference-lead assignment is now restricted to village admins (#191).

### Roles & Permissions

- **Activity Lead** — an optional, per-conference role granting admin rights over
  a single activity's volunteers and shifts, without conference-wide access (#201).
- **Delegated qualification assignment** — a conference manager can authorize a
  delegate to grant a specific qualification to volunteers (#202).
- Activity leads get an "Activities You Lead" shortcut to manage their activities (#208).

### Scheduling

- **Per-conference shift block size** — set a minimum shift duration; volunteers
  book shifts in whole blocks (e.g. 30-minute blocks) (#194).
- **Collapsed mobile schedule view** with day-jump navigation (#195).
- The program-name header row now floats (sticky) while scrolling the schedule (#198).
- Schedule columns are hidden for programs with no shifts on a given day (#199).
- Long "qualification required" pills now wrap within their column (#196).

### Programs

- Enabling an existing program is now discoverable even when none are available (#207).
- Fixed a 500 error when creating a program whose name matched a program in
  another scope (#205).

### Security

- Cleared bundler-audit advisories by bumping `crass`, `faraday`, and `msgpack` (#193).

### Developer Experience & Infrastructure

- Dockerfile support for MySQL (#209).
- Stabilized CI system tests by switching to modern headless Chrome (#204).
- Extracted the schedule page's inline CSS into a compiled stylesheet (#206).
- Fixed a `bin/rubocop` crash by bumping `rubocop-ast` for prism 1.9.0 (#166).

### Dependencies

- Bump `omniauth-rails_csrf_protection` 1.0.2 → 2.0.1 (#176) and
  `selenium-webdriver` 4.40.0 → 4.45.0 (#174).
- Bump `solid_queue`, `kamal`, `thruster`, `bootsnap`, `propshaft`, `jbuilder`,
  `mailgun-ruby`, and `web-console`, plus the `actions/checkout` and
  `actions/cache` GitHub Actions (#168–#179).

### Thanks

Thanks to our beta testers and contributors — including
[@IvanGirderboot](https://github.com/IvanGirderboot) — for helping shape this
first release.

[0.1.0]: https://github.com/livitup/villagers/releases/tag/v0.1.0
