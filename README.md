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

## Development

* Run tests: `bin/rails test`
* Run system tests: `bin/rails test:system`
* Lint code: `bin/rubocop`
