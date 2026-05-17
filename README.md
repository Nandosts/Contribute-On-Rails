# Contribute on Rails

A small Rails app that helps people find contribution-friendly issues across open-source Ruby and Rails projects.

It imports repositories from [`asyraffff/Open-Source-Ruby-and-Rails-Apps`](https://github.com/asyraffff/Open-Source-Ruby-and-Rails-Apps), refreshes open GitHub issues daily, and surfaces issues labeled `good first issue` or `help wanted` updated in the last 12 months by default.

## Stack

- Ruby 4.0.3
- Rails 8.1.3
- PostgreSQL
- Importmap + Turbo + Stimulus
- Solid Queue for background jobs
- Tailwind CSS

## Features

- Daily project catalog sync from the upstream README
- Daily GitHub issue sync per active project
- Default contribution-friendly issue filter (limited to the last 12 months by default)
- Search by title, label, organization, project, and source category
- Grouped issue results by organization and repository
- Searchable project filters, pagination, and random project discovery
- Curated additions for important projects missing from the upstream list
- English UI with Portuguese (`pt-BR`) translations ready
- Security and quality tooling for open-source maintenance

## Catalog sources

The catalog combines the upstream application list with a small, hand-curated set of canonical Ruby and Rails repositories in `config/curated_projects.yml`. The curated file is intentionally selective: it is meant for projects that are important references for the ecosystem, not for bulk-importing every repository from large organizations.

### Fetching All Issues
By default, the application only syncs issues with the labels `good first issue` or `help wanted` to maintain a curated experience for beginners. 
However, you can override this behavior per project by setting the `fetch_all_issues: true` flag in the `config/curated_projects.yml` file:
```yaml
- owner: rails
  repo: rails
  category: Core Ruby and Rails
  fetch_all_issues: true
```

## Setup

```bash
asdf install
bundle install
bin/rails db:prepare
```

Create a GitHub token and export it before running sync jobs:

```bash
export GITHUB_TOKEN=your_token_here
```

Start the app:

```bash
bin/dev
```

## Syncing data

To import or update projects from the curated and upstream catalogs:
```bash
bin/rails runner 'Projects::SyncJob.perform_now'
```

To fetch GitHub issues for all active projects (respecting the `fetch_all_issues` project configurations):
```bash
bin/rails runner 'Issues::SyncJob.perform_now'
```

**Global Fetch Override:**
If you want to bypass the database configurations and force the system to download **all** open issues for **all** active projects, you can pass the global `fetch_all` parameter to the job:
```bash
bin/rails runner 'Issues::SyncJob.perform_now(fetch_all: true)'
```

Recurring production jobs are defined in `config/recurring.yml`.

## Quality checks

```bash
bin/rails test
rubocop -a app test config db
bin/herb lint app/views
bin/brakeman --no-pager
bin/bundler-audit
```

## Project shape

- `Github::ProjectCatalogImporter` parses the upstream project list
- `Projects::SyncService` keeps the local repository catalog current
- `Issues::SyncService` mirrors open issues and labels
- `IssueSearchQuery` centralizes all filtering logic used by the UI

## Contributing

Contributions are welcome. Please keep code, commit messages, and documentation in English; translations can be added under `config/locales/`.

Before opening a pull request, run the quality checks above and keep changes focused.

## License

MIT
