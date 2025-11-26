# Villagers - Claude Code Configuration

## Project Overview

Ruby on Rails app for hacker conference village organizers to manage volunteer scheduling. Open source project designed for any village (e.g., Ham Radio Village, DEF CON villages).

## Technology Stack

- **Framework**: Ruby on Rails 7
- **Database**: PostgreSQL
- **Frontend**: Bootstrap
- **Authentication**: Devise
- **Authorization**: Pundit

## Development Workflow

### Git Hygiene (CRITICAL)

1. **NEW REQUEST = NEW ISSUE**: Every feature/bug starts with a GitHub issue
2. **NEW ISSUE = NEW BRANCH**: Each issue gets its own branch
3. **Before new branch**:
   ```bash
   git checkout main
   git pull
   ```
4. **Branch naming**: `git checkout -b issue-{number}-{descriptive-name}`
5. **One issue per branch**: Never mix multiple issues in one branch
6. **Always branch from main**: Never from another feature branch unless explicitly requested
7. **No direct commits to main**: All work goes through branches and PRs
8. **Link PRs to issues**: Include `Closes #<issue-number>` in PR body to auto-close issue on merge

### Test-Driven Development (MANDATORY)

Follow TDD for all new functionality:

1. **Write a failing test first** - Define expected behavior before implementation
2. **Write minimum code to pass** - Only enough to make the test green
3. **Refactor** - Clean up while keeping tests green
4. **Repeat** - Next test for next piece of functionality

Do NOT write implementation code before tests. The test file should be created and failing before the implementation file exists.

### Before Commits and PRs (MANDATORY)

Before suggesting ANY commit or PR:

1. **Run ALL tests**: `bin/rails test:all` (includes system tests)
2. **Verify 0 failures, 0 errors** - Do not proceed if tests fail
3. **Run linter**: `bin/rubocop -a`
4. **Fix any remaining rubocop warnings manually**

### PRs Require Explicit Approval

**Do NOT create PRs automatically.** When you believe work is ready:
1. Commit changes to the branch
2. Push to remote
3. **ASK the user** if they want you to create a PR
4. Wait for explicit confirmation before running `gh pr create`

This allows the user to manually test changes before the PR is created, avoiding multiple commit/push cycles.

### Testing Commands

- `bin/rails test:all` - Run ALL tests including system tests (REQUIRED before commits/PRs)
- `bin/rails test` - Run unit/controller/integration tests only (faster, for iterating)
- `bin/rails test test/path/to/file_test.rb` - Run specific test file
- `bin/rails test test/models/` - Run directory tests
- `bin/rails test:system` - System tests only

### Code Quality

- `bin/rubocop -a` - Auto-fix linting issues
- All routes must have smoke tests

## Rails Best Practices

- Use RESTful routes
- Follow MVC pattern
- Use Pundit for authorization with explicit `policy_class` where needed
- **Route Ordering**: Place custom routes BEFORE `resources` to avoid conflicts
- **Delete Links**: Use `data: { turbo_method: :delete }` for Rails 7/Turbo compatibility

### Navbar Updates

When creating a new model, add navbar dropdown with:
- Link to index action
- Link to new/create action (permission-gated via Pundit)
- Follow pattern in `app/views/shared/_navbar.html.erb`

## Authorization (Pundit)

### Policies
- `ConferencePolicy`, `VillagePolicy`, `ProgramPolicy`, `ConferenceProgramPolicy`, `ApplicationPolicy`

### Authorization Methods
- `user&.village_admin?`
- `user&.conference_lead?(conference)`
- `user&.conference_admin?(conference)`
- `user&.conference_lead_or_admin?(conference)`
- `user&.can_manage_conference?(conference)`

## Core Data Model

### Hierarchy
- **Village** → has_many **Conferences** → has_many **ConferencePrograms** (join table to Programs)
- **Programs** are village-level, enabled per conference via ConferenceProgram
- **ConferenceProgram** stores: `public_description`, `day_schedules` (JSONB)

### Roles
1. **Village Admin**: Global permissions, can manage everything
2. **Conference Lead**: Nominated by village admin, manages their conference(s)
3. **Conference Admin**: Delegated by lead, same permissions for assigned conference
4. **Volunteer**: Any registered user, can sign up for shifts

### Key Models
- `Village`: name, setup_complete
- `Conference`: name, location, start_date, end_date, conference_hours_start/end
- `Program`: name, description (village-level)
- `ConferenceProgram`: conference_id, program_id, public_description, day_schedules
- `User`: email, name, handle, phone, twitter, signal, discord

## Not Yet Implemented

- Timeslots (15-minute blocks)
- Volunteer signups/shifts
- Qualifications (global and conference-specific)
- Calendar view (outlook agenda style)
- Calendar export (iCal/Google Calendar)
- Email notifications
- Leaderboard

## Commands (Pre-authorized)

```bash
# Git
git status, git add, git commit, git push, git checkout, git branch, git merge, git fetch, git diff

# Rails
bin/rails test:all
bin/rails test test/path/to/file_test.rb
bin/rails db:migrate
bin/rails db:seed
bin/rails console
bin/rails server
bin/dev

# Code quality
bin/rubocop
bin/rubocop -a

# GitHub CLI
gh pr view, gh pr checkout, gh pr create, gh pr list
gh issue view, gh issue create, gh issue list
```
