# Contributing

Thanks for considering a contribution to Contribute on Rails.

## Development setup

1. Install the versions declared in `.tool-versions`.
2. Run `bundle install`.
3. Run `bin/rails db:prepare`.
4. Export `GITHUB_TOKEN` when working on sync behavior.

## Before opening a pull request

Run:

```bash
bin/rails test
bin/rubocop
bin/herb lint app/views
bin/brakeman --no-pager
bin/bundler-audit
```

Keep commits focused and use semantic commit messages such as:

- `feat: add issue synchronization`
- `fix: ignore pull requests during issue sync`
- `docs: clarify local setup`

## Language

Code, commit messages, and primary documentation should be written in English. UI translations can be added under `config/locales/`.
