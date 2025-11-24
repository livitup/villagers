# Villagers Architecture & Development Guidelines

## Project Overview

Villagers is a Ruby on Rails application for hacker conference village organizers to manage volunteer scheduling. It allows village organizers to specify groups of volunteers they need, and volunteers to sign up for shifts at conferences.

**Target Audience**: Open source project for any village to use (e.g., Ham Radio Village, Hardware Hacking Village at DEF CON). Everything must be configurable, including the village name.

## Technology Stack

- **Framework**: Ruby on Rails
- **Database**: PostgreSQL
- **Frontend**: Bootstrap
- **Authentication**: Devise
- **Authorization**: Pundit
- **Development Workflow**: GitHub tickets → branch → PR → merge via GitHub website

## Core Entities & Data Model

### 1. Village
- The organization using the app instance
- **Attributes**: `name` (configurable), `setup_complete` (boolean)
- **Setup**: Initial configuration via web browser (Rails way) when app is first installed
- **Note**: Everything should be configurable for open source reuse

### 2. Conference
- An event where the village has a presence
- **Attributes**:
  - `name` (string)
  - `location` (string)
  - `start_date` (date)
  - `end_date` (date)
  - `conference_hours_start` (time) - when conference opens each day
  - `conference_hours_end` (time) - when conference closes each day
- **Relationships**:
  - `belongs_to :village`
  - `has_many :conference_roles`
  - `has_many :users, through: :conference_roles`
  - `has_many :conference_programs` (join table for programs)
  - `has_many :programs, through: :conference_programs`
- **Validation**: `end_date` must be after `start_date`

### 3. Programs
- Things that the village does at conferences (e.g., "Ham Test", "Radio Operations")
- **Status**: ✅ Implemented (Issue #8, PR #42)
- **Design Decision**: Programs are **village-level** (shared across conferences)
- **Conference-Specific Programs**: Conference leads/admins can create conference-specific programs (Issue #51 - not yet implemented)
- **Conference-Specific Overrides**: 
  - When a program is enabled for a conference, use a join table (`conference_programs`)
  - This join table stores conference-specific attributes like `public_description`
  - Conference leads/admins can update conference-specific details without affecting the village-level program
- **Data Model**:
  - `Program` model (village-level):
    - `name` (string) - unique within village
    - `description` (text) - default village-level description
    - `village_id` (belongs_to village)
  - `ConferenceProgram` join table (✅ Implemented - Issue #9, PR #50):
    - `conference_id` (belongs_to conference)
    - `program_id` (belongs_to program)
    - `public_description` (text) - conference-specific description override
    - `day_schedules` (jsonb) - day-specific schedules with structure: `{ "0": { "enabled": true, "start": "09:00", "end": "17:00" } }`
      - Day index (0, 1, 2...) corresponds to day of conference (0 = first day)
      - Each day can have `enabled` (boolean), `start` (time string), `end` (time string)
    - Unique index on `[conference_id, program_id]`
- **Requirements**:
  - Village-level object (managed by village admins)
  - When linked to a conference via join table, admin defines what days/hours that program runs
  - Not all programs run on all days
  - Conference lead/admins can enable programs as active at a conference
  - Conference lead/admins can update conference-specific program details (e.g., public description)
  - Separate timeslots for each program that's active at the conference

### 4. Timeslots
- 15-minute blocks of time during conference open hours
- **Status**: Not yet implemented
- **Design Decision**: Timeslots are created **when a program is added/enabled for a conference**
  - Each conference/program combination has its own set of timeslots
  - Timeslots belong to a specific conference and program combo
  - Created automatically when a program is enabled for a conference
- **Proposed Data Model**:
  - `Timeslot` model:
    - `conference_id` (belongs_to conference)
    - `program_id` (belongs_to program) - via conference_program
    - `start_time` (datetime) - specific date/time for this 15-minute slot
    - `end_time` (datetime) - start_time + 15 minutes
    - `max_volunteers` (integer) - max number of volunteers for this slot
    - `current_volunteers_count` (integer, cached) - current signups
    - Index on `[conference_id, program_id, start_time]`
- **Requirements**:
  - 15-minute increments
  - Belongs to a specific conference and program combination
  - For each day the conference runs (based on program's enabled days/hours for that conference)
  - During conference's open hours only
  - Conference lead/admins can set max number of volunteers per timeslot
  - Timeslots are generated based on:
    - Conference dates
    - Conference open hours (conference_hours_start to conference_hours_end)
    - Program's enabled days/hours for that specific conference

### 5. Users (Volunteers)
- Registered users of the system
- **Attributes**:
  - `email` (mandatory, unique)
  - `name` (string)
  - `handle` (string)
  - `phone` (string, optional)
  - `twitter` (string, optional)
  - `signal` (string, optional)
  - `discord` (string, optional)
  - Devise authentication fields
- **Relationships**:
  - `has_many :user_roles` (for village-level roles)
  - `has_many :roles, through: :user_roles`
  - `has_many :conference_roles` (for conference-specific roles)
  - `has_many :volunteer_signups` (for timeslot signups)
- **Requirements**:
  - Can sign up for multiple program/timeslot combos
  - Cannot sign up for more than one at the same actual date/time
  - Can view calendar (outlook agenda style) for any conference
  - Can export their volunteer shifts to phone calendar
  - Volunteer history tracking
  - Leaderboard showing people who volunteer for the most stuff

### 6. Qualifications
- Requirements for volunteers to staff certain activities
- **Status**: Not yet implemented
- **Example**: "Volunteer Examiner" qualification required for "Ham Test" activity
- **Design Decision**: Qualifications can be **global (village-level)** or **conference-specific**
  - **Global Qualifications**: Granted at village level, flow down to all conferences
    - Example: Accredited volunteer examiner has qualification for any conference with "exams" program
    - Managed by village admins
  - **Conference-Specific Qualifications**: Defined and granted at conference level
    - Managed by conference leads/admins
    - Only apply to that specific conference
  - **Removal of Flow-Down Qualifications**: Conference admins can remove global qualifications for their conference only
    - Does not affect the volunteer's global qualification
    - Only affects that specific conference
- **Proposed Data Model**:
  - `Qualification` model (village-level):
    - `name` (string)
    - `description` (text)
    - `village_id` (belongs_to village)
  - `UserQualification` model (global):
    - `user_id` (belongs_to user)
    - `qualification_id` (belongs_to qualification)
    - Unique index on [user_id, qualification_id]
  - `ConferenceQualification` model (conference-specific):
    - `conference_id` (belongs_to conference)
    - `name` (string)
    - `description` (text)
  - `ConferenceUserQualification` model (conference-specific grants):
    - `user_id` (belongs_to user)
    - `conference_qualification_id` (belongs_to conference_qualification)
    - Unique index on [user_id, conference_qualification_id]
  - `QualificationRemoval` model (removes global qualification for specific conference):
    - `user_id` (belongs_to user)
    - `qualification_id` (belongs_to qualification)
    - `conference_id` (belongs_to conference)
    - Unique index on [user_id, qualification_id, conference_id]
- **Requirements**:
  - Village admins can CRUD global qualifications
  - Village admins can grant global qualifications to users
  - Conference leads/admins can CRUD conference-specific qualifications
  - Conference leads/admins can grant conference-specific qualifications to users
  - Conference leads/admins can remove global qualifications for their conference only
  - Some programs may require qualifications for volunteers to staff
  - When checking if user can sign up, check both global and conference-specific qualifications

### 7. Volunteer Signups/Shifts
- Records of volunteers signing up for program/timeslot combos
- **Status**: Not yet implemented
- **Proposed Data Model**:
  - `VolunteerSignup` model:
    - `user_id` (belongs_to user)
    - `timeslot_id` (belongs_to timeslot)
    - `created_at` (timestamp)
    - Unique index on `[user_id, timeslot_id]`
    - Validation: user cannot have overlapping signups (same start_time)
- **Requirements**:
  - Automatic signup once user requests (no approval needed)
  - Volunteers select from calendar view
  - Cannot sign up for overlapping timeslots
  - Conference leads/admins can manually add or delete volunteers from shifts

## Role-Based Access Control

### Roles

1. **Village Admin**
   - Can set up new conferences
   - Can CRUD qualifications
   - Can grant qualifications to users
   - Can manage all conferences
   - Can nominate conference leads
   - Can CRUD village-level programs
   - Global permissions across all conferences

2. **Conference Lead**
   - Nominated by village admin when creating conference
   - Can set conference attributes (e.g., what programs will be available)
   - Can enable/disable programs for their conference
   - Can update conference-specific program details (e.g., public_description)
   - Can delegate conference admins
   - Can manually add or delete volunteers from shifts
   - Can set max volunteers per timeslot/program combo
   - Permissions limited to their assigned conference(s)
   - Can manage multiple conferences independently

3. **Conference Admin**
   - Delegated by conference lead
   - Same permissions as conference lead, but only for their assigned conference
   - Can set conference attributes
   - Can enable/disable programs for their conference
   - Can update conference-specific program details
   - Can manually add or delete volunteers from shifts
   - Can set max volunteers per timeslot/program combo
   - Permissions limited to their assigned conference(s)

4. **Volunteer**
   - Any registered user
   - Can view calendar for any conference
   - Can sign up for shifts (if qualified)
   - Can manage their own interests/signups
   - Can export their shifts to calendar

**Note**: No limit to number of conferences a user can be lead, admin, or volunteer for - all independent.

## User Interface Requirements

### Calendar View
- **Style**: Outlook agenda style
- **Layout**: Vertical days split into 15-minute increments
- **Scope**: For whatever days the conference is running
- **Access**: Any registered user can view calendar for any conference
- **Functionality**: Volunteers select open timeslot/program options from calendar

### Dashboard
- **For**: Conference leads/admins
- **Content**: Cards showing vital information related to that conference
- **Reports needed**:
  - Who should be where and when
  - What shifts are unmanned
  - Other organizer reports (TBD)

### Calendar Export
- **Feature**: Users can export their volunteer shifts to phone calendar
- **Design Decision**: Support **both** iCal (.ics) and Google Calendar formats
  - Users can choose which format to export
  - iCal format is widely supported by most calendar applications
  - Google Calendar format for direct integration

## Email Notifications

- **Status**: Ticket opened for implementation
- **Details**: TBD - will determine what emails to send later

## Development Practices

### Workflow
1. **NEW REQUEST = NEW ISSUE**: Every new feature, bug fix, or change request must start with a new GitHub issue
2. **NEW ISSUE = NEW BRANCH**: Each issue gets its own unique branch - never work on multiple unrelated things in the same branch
3. **Before starting new branch**: 
   - Switch to main: `git checkout main`
   - Pull latest: `git pull`
   - Ensure you're up to date with origin
4. Create unique branch from main: `git checkout -b issue-{number}-{descriptive-name}`
5. Work the ticket in the branch - only work on that specific issue
6. **CRITICAL**: All tests must pass before creating PR
7. Run `bin/rubocop -a` before every PR or push to existing PR
8. Fix any rubocop warnings that can't be auto-fixed
9. Create PR linking to the issue
10. Merge via GitHub website

### Git Hygiene Rules
- **One issue per branch**: Never mix multiple issues/features in one branch
- **New request = new branch**: If asked to do something new while on an existing branch, create a new issue and branch first
- **Always branch from main**: Never branch from another feature branch unless explicitly requested
- **Clean up after merge**: Delete local branches after PR is merged (optional, but good practice)
- **No work on main**: Never commit directly to main - all work goes through branches and PRs

### Testing
- **Requirement**: Test-driven design (TDD)
- **Requirement**: All tests must pass before PR - **UNACCEPTABLE** to create PR with failing tests
- **Requirement**: All routes must have smoke tests - basic tests that verify routes don't throw errors (even if they redirect)
  - Smoke tests ensure routes are accessible and don't crash
  - Should test all actions (index, show, new, create, edit, update, destroy) for each resource
  - Can be minimal - just verify the route responds (200, 302, etc.) without errors
- **Workflow**:
  - During development: Run specific test files (e.g., `bin/rails test test/models/program_test.rb`)
  - Before declaring done: Run `bin/rails test:all` to verify all tests pass
- **Commands**:
  - `bin/rails test:all` - run all tests (use this before finalizing)
  - `bin/rails test test/path/to/file_test.rb` - run specific test file
  - `bin/rails test test/models/` - run all tests in a directory
  - `bin/rails test:system` - run system tests only

### Code Quality
- **Linting**: Run `bin/rubocop -a` before every PR or push
- **Auto-fix**: Use `-a` flag to auto-correct issues
- **Manual fixes**: Fix any remaining warnings manually before PR
- **Verification**: Ensure rubocop passes with no offenses before finalizing

### Rails Best Practices
- Follow Rails conventions
- Use RESTful routes
- Follow MVC pattern
- Use Rails helpers and partials appropriately
- Follow ActiveRecord associations and validations
- Use Pundit for authorization (explicit `policy_class` where needed)
- **Route Ordering**: When using custom routes with `resources`, place custom routes BEFORE the `resources` line to avoid conflicts (e.g., `get "programs/new"` before `resources :conference_programs`)
- **Delete Links**: Use `data: { turbo_method: :delete }` instead of `method: :delete` for Rails 7/Turbo compatibility

### Navbar Updates
- **When creating a new model**: Add a new dropdown in the navbar with:
  - Link to index action (e.g., "All Programs")
  - Link to new/create action (e.g., "New Program") - only if user has permission
  - All links must respect roles using Pundit policies (e.g., `policy(Program).create?`)
- **When adding functionality to existing model**: Add new links to the existing dropdown
- **Authorization**: All navbar links must check permissions - only show links the user can access
- **Pattern**: Follow the existing dropdown structure (see `app/views/shared/_navbar.html.erb`)

## Authorization (Pundit)

### Current Implementation
- Explicit `policy_class: ConferencePolicy` in all authorize calls
- Avoid `policy_scope` in index actions (causes issues)
- Policies:
  - `ConferencePolicy` - for conference authorization
  - `VillagePolicy` - for village authorization
  - `ProgramPolicy` - for program authorization (village-level)
  - `ConferenceProgramPolicy` - for conference program authorization
  - `ApplicationPolicy` - base policy class

### Authorization Methods
- `user&.village_admin?` - check village admin role
- `user&.conference_lead?(conference)` - check conference lead role
- `user&.conference_admin?(conference)` - check conference admin role
- `user&.conference_lead_or_admin?(conference)` - check either lead or admin
- `user&.can_manage_conference?(conference)` - check if user can manage (village admin OR lead/admin)

## Commands Authorized to Run Without Asking

Based on development workflow, the following commands are authorized:

### Git Commands
- `git status`
- `git add`
- `git commit`
- `git push`
- `git checkout`
- `git branch`
- `git merge`
- `git fetch`
- `git diff`
- `git stash`
- `git revert`

### Rails Commands
- `bin/rails test:all`
- `bin/rails test test/path/to/file_test.rb` (specific test files)
- `bin/rails test:system`
- `bin/rails db:migrate`
- `bin/rails db:seed`
- `bin/rails console`
- `bin/rails server`

### Code Quality
- `bin/rubocop`
- `bin/rubocop -a`

### GitHub CLI
- `gh pr view`
- `gh pr checkout`
- `gh pr create`
- `gh pr list`
- `gh issue view`
- `gh issue create`
- `gh issue list`

### General
- `bin/dev` (development server)
- `bin/setup`

## Current Implementation Status

### ✅ Implemented
- Village model and setup flow
- User authentication (Devise)
- Conference CRUD with authorization
- Role-based access control (village admin, conference lead, conference admin, volunteer)
- Pundit authorization policies
- User profile fields (name, handle, email, phone, twitter, signal, discord)
- Database seeds for development
- Programs model and management (Issue #8, PR #42)
- ConferenceProgram join table with day-specific schedules (Issue #9, PR #50)
- User permissions/roles display feature (Issue #43, PR #46)

### 🚧 Not Yet Implemented
- Conference-specific program creation for leads/admins (#51)
- Conference location city/state dropdown (#52)
- Timeslots model and generation (#37)
- Volunteer signups/shifts (#38)
- Calendar view (outlook agenda style) (#39)
- Qualifications model and management (global and conference-specific) (#40)
- Calendar export functionality (iCal and Google Calendar) (#41)
- Email notifications (#16)
- Volunteer history and leaderboard (#17)
- Conference dashboard for leads/admins (#18)
- Reports for conference organizers (#19)
- Conference lead dashboard card (#49)

## Questions to Clarify

1. ~~**Programs**: Village-level or conference-specific? How does "enabling" work?~~ ✅ **RESOLVED**: Village-level with conference-specific overrides via join table
2. ~~**Timeslots**: When/how are they created? Automatic or on-demand?~~ ✅ **RESOLVED**: Created when program is enabled for conference
3. ~~**Qualifications**: Program-specific or general? Can one qualification apply to multiple programs?~~ ✅ **RESOLVED**: Can be global (village-level) or conference-specific. Global qualifications flow down to all conferences. Conference admins can remove flow-down qualifications for their conference only.
4. ~~**Calendar Export**: Preferred format (iCal, Google Calendar, both)?~~ ✅ **RESOLVED**: Both formats supported
5. ~~**Initial Setup**: What exactly needs to be configured in the setup flow?~~ ✅ **RESOLVED**: Village name and first admin user (already implemented in ticket #3)

## Notes

- Most events are 2-3 days
- Calendar should show vertical days with 15-minute increments
- Users can only volunteer for one activity per 15-minute timeslot
- Signups are automatic (no approval workflow)
- Conference leads/admins can override/manually manage volunteer assignments
- Programs are village-level but can have conference-specific descriptions/details
- Timeslots are generated per conference/program combination when program is enabled
- ConferenceProgram uses `day_schedules` (JSONB) for day-specific scheduling, not separate fields
- Route ordering matters: custom routes must come before `resources` to avoid conflicts
- Rails 7/Turbo requires `data: { turbo_method: :delete }` for delete links, not `method: :delete`

