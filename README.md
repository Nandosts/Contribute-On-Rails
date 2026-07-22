# Contribute on Rails
![contribute-on-rails-sample](https://github.com/user-attachments/assets/8eded37d-94ca-41ae-a758-9abba3cfaf0c)

A small Rails app that helps people find contribution-friendly issues across open-source Ruby and Rails projects.

It curates an extensive catalog of canonical Ruby and Rails open-source projects, incrementally refreshes their open GitHub issues, and helps contributors find opportunities using transparent, removable filters.

## Stack

- Ruby 4.0.3
- Rails 8.1.3
- PostgreSQL
- Importmap + Turbo + Stimulus
- Tailwind CSS

## Features

- Project catalog sync from a curated YAML file
- Incremental GitHub issue sync with periodic full reconciliation
- Persistent New Contributor filter that preselects the `good first issue` and `help wanted` labels
- Unrestricted issue and label exploration when the New Contributor filter is disabled
- Search by title, label, organization, project, and source category
- Browser-local saved searches with an optional default filter combination
- Grouped issue results by organization and repository
- Searchable project filters, pagination, and random project discovery
- Hand-curated catalog of important Ruby and Rails ecosystem projects
- English UI with Portuguese (`pt-BR`) translations ready
- Security and quality tooling for open-source maintenance

## Catalog sources

The catalog relies entirely on a hand-curated set of canonical Ruby and Rails repositories defined in `config/curated_projects.yml`. The curated list is intentionally selective: it is meant for projects that are important references for the ecosystem, ensuring high-quality contribution opportunities while protecting GitHub API rate limits.

## Setup

```bash
asdf install
bundle install
bin/rails db:prepare
```

Copy the example environment file and fill in your variables:

```bash
cp .env.example .env
```

### Key Environment Variables

* `GITHUB_TOKEN`: A GitHub Personal Access Token (classic or fine-grained) to fetch issues and prevent API rate-limiting.
* `SYNC_TOKEN`: A secret used by the external cron service in the `Authorization: Bearer` header.

Start the app:

```bash
bin/dev
```

## Syncing data

To synchronize the catalog and all active projects locally:
```bash
bin/rails runner 'Syncs::Runner.new.call'
```

The production deployment is intentionally queue-free. An external cron service makes one authenticated request and waits for the synchronization result:

```bash
curl --fail-with-body --request POST \
  --header "Authorization: Bearer $SYNC_TOKEN" \
  https://contribute-on-rails.fly.dev/api/syncs
```

Pass `force_full=true` only when a full reconciliation is required. PostgreSQL advisory locking prevents overlapping runs.

## Quality checks

```bash
bin/rails test
bin/rubocop
bin/herb lint app/views
bin/brakeman --no-pager
bin/bundler-audit
```

## Project shape

- `Projects::SyncService` keeps the local repository catalog current
- `Issues::SyncService` incrementally mirrors open issues and labels page by page
- `Syncs::Runner` protects the synchronous cron execution with a PostgreSQL advisory lock
- `IssueSearchQuery` centralizes all filtering logic used by the UI

## Contributing

Contributions are welcome. Please keep code, commit messages, and documentation in English; translations can be added under `config/locales/`.

Before opening a pull request, run the quality checks above and keep changes focused.

## License

MIT
