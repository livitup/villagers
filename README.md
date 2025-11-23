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

### Seed Users (all passwords are "password")

1. **Village Admin**
   - Email: `admin@example.com`
   - Password: `password`
   - Role: Village Administrator (can manage all conferences)

2. **Conference Lead (Coordinator)**
   - Email: `coordinator@example.com`
   - Password: `password`
   - Role: Conference Lead for DEF CON 32

3. **Conference Admins**
   - Email: `admin1@example.com`
   - Password: `password`
   - Role: Conference Admin for DEF CON 32
   
   - Email: `admin2@example.com`
   - Password: `password`
   - Role: Conference Admin for DEF CON 32

4. **Volunteers**
   - Email: `volunteer1@example.com` through `volunteer5@example.com`
   - Password: `password`
   - Role: Volunteer (can view conferences and sign up for shifts)

### Other Seed Data

- **Village**: Ham Radio Village
- **Conference**: DEF CON 32 (August 8-11, 2024, Las Vegas, NV)

## Development

* Run tests: `bin/rails test`
* Run system tests: `bin/rails test:system`
* Lint code: `bin/rubocop`
