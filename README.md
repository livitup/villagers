# Villagers

Village volunteer scheduling software for hacker conference villages.

## Setup

### Prerequisites

* Ruby (see `.ruby-version`)
* PostgreSQL
* Node.js (see `.node-version`)
* Yarn

### Installation

1. Clone the repository
2. Run `bin/setup`
3. Start the server with `bin/dev`

## Configuration

### Sass Version

Sass is pinned to version `1.94.2` in `package.json` to maintain consistency. Deprecation warnings from Bootstrap's SCSS files are suppressed using the `--quiet-deps` and `--silence-deprecation` flags in the build script. This prevents noise from third-party dependency warnings while still showing warnings from our own code.

## Database Seeds

The application includes seed data for development and testing. Run `bin/rails db:seed` to populate the database with test data.

### Seed Users

**All seed users have the password: `password`**

| Email | Password | Role | Description |
|-------|----------|------|-------------|
| `admin@example.com` | `password` | Village Admin | Can manage all conferences and village settings |
| `coordinator@example.com` | `password` | Conference Lead | Conference Lead for DEF CON 32 |
| `admin1@example.com` | `password` | Conference Admin | Conference Admin for DEF CON 32 |
| `admin2@example.com` | `password` | Conference Admin | Conference Admin for DEF CON 32 |
| `volunteer1@example.com` | `password` | Volunteer | Can view conferences and sign up for shifts |
| `volunteer2@example.com` | `password` | Volunteer | Can view conferences and sign up for shifts |
| `volunteer3@example.com` | `password` | Volunteer | Can view conferences and sign up for shifts |
| `volunteer4@example.com` | `password` | Volunteer | Can view conferences and sign up for shifts |
| `volunteer5@example.com` | `password` | Volunteer | Can view conferences and sign up for shifts |

**Quick Login Reference:**
- **Village Admin**: `admin@example.com` / `password`
- **Conference Lead**: `coordinator@example.com` / `password`
- **Conference Admin**: `admin1@example.com` or `admin2@example.com` / `password`
- **Volunteer**: `volunteer1@example.com` through `volunteer5@example.com` / `password`

### Other Seed Data

- **Village**: Ham Radio Village
- **Conference**: DEF CON 32 (August 8-11, 2024, Las Vegas, NV)

## Development

* Run tests: `bin/rails test`
* Run system tests: `bin/rails test:system`
* Lint code: `bin/rubocop`
