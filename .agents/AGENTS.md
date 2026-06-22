# AGENTS.md — Contribute on Rails — Open Source Repository Finder

This file defines technical, architectural, and behavioral guidelines for AI agents and developers working on the Contribute on Rails codebase.

---

## Overview

A small open-source Rails application that helps people find contribution-friendly issues across open-source Ruby and Rails projects.
* Sourced from a combination of the upstream app list and curated local catalogs.
* Fetches and mirrors open GitHub issues daily.
* Targets issues labeled `good first issue` or `help wanted` updated in the last 12 months.

The codebase, tests, commits, and API interactions are written in English. Translations are managed under `config/locales/` (e.g. `pt-BR`).

Default environment: Development / Production.

---

## Technology Stack

* Ruby 4.0.3 (Compatible with local installs like 3.3.5)
* Rails 8.1.3
* PostgreSQL
* Propshaft (Asset Pipeline)
* Importmap + Turbo + Stimulus
* Solid Cache (Caching)
* Solid Queue (Background Jobs)
* Solid Cable (PubSub/WebSockets)
* Tailwind CSS v4
* Minitest (Testing)
* Pagy (Pagination)

---

## Core Principles

You are a senior Ruby on Rails developer.

Guidelines:
* Be direct and objective.
* No motivational text, filler, or redundancy.
* Prioritize clear, idiomatic, and readable Rails 8 code.
* Avoid overly clever solutions; prefer simplicity and ease of maintenance.
* This is an open-source project: ensure good class/method documentation but keep actual code comments minimal (use comments only to document non-obvious design decisions).
* Explain trade-offs only when requested or highly relevant.

---

## Language and Naming Convention (MANDATORY)

All codebase modifications, code symbols, variables, methods, and class definitions MUST be written in English.

Rules:
* Code symbols and variable names must clearly describe their purpose.
* Avoid abbreviations (e.g. use `temporary_variable` instead of `tmp_var`).
* Maintain clean English syntax.
* Translations of user-facing UI elements must be separated into the YAML translation files under `config/locales/`.

---

## Code Style

### Ruby / Rails
* Follow official Rails conventions.
* Keep controllers, models, and jobs thin.
* Use query objects (e.g., `IssueSearchQuery`) to isolate search/filtering logic.
* Keep methods small, focused, and single-purpose.
* Avoid comments — document the *why* (decisions) rather than the *what* (the code itself).
* Respect RuboCop styles.

### Architecture
* Keep integration clients (e.g., `Github::IssuesClient`) decoupled from database models.
* Use services (e.g., `Issues::SyncService`) to orchestrate API calls, payload parsers, and Active Record insertions.

---

## Frontend

### Hotwire / Turbo & Stimulus
* Prefer Turbo Frames over full-page reloads.
* Keep page states responsive and accessible.
* Use Stimulus controllers for client-side interactions (e.g., dropdowns, custom select tags).

### Tailwind CSS v4
* Use utility classes.
* Avoid custom CSS unless absolutely necessary.
* Always check if `tailwind.config.js` exists before altering classes (Note: Tailwind v4 compiles assets without a traditional config file if using importmap-rails integration defaults).

---

## Security

* Always use strong parameters.
* Validate and sanitize all external data.
* Enforce Content Security Policy (CSP) compliance: any `<script>` tag must include the `nonce` attribute using `nonce="<%= request.content_security_policy_nonce %>"`.
* Regularly run security scans with Brakeman.

---

## Commands

### Development
* `bin/dev`
* `bin/rails server`
* `bin/rails console`
* `bin/rails db:prepare`

### Data Syncing
* `bin/rails runner 'Projects::SyncJob.perform_now'`
* `bin/rails runner 'Issues::SyncJob.perform_now'`
* `bin/rails runner 'Issues::SyncJob.perform_now(fetch_all: true)'`

### Testing
* `bin/rails test`

### Code Quality
* `bundle exec rubocop -a app test config db`
* `bin/herb lint app/views`
* `bundle exec brakeman --no-pager`
* `bundle exec bundler-audit`

---

## Testing

* Use Minitest (Rails default testing framework).
* Maintain test coverage at 100% (using SimpleCov).
* In tests that run background jobs or services printing console progress, mock/capture stdout using `StringIO` to avoid polluting the test output.
* Mock external HTTP requests carefully (using stubs on `Net::HTTP` or predefined payloads).

---

## Communication

* Answer in Portuguese (pt-BR) if the user communicates in Portuguese.
* Do not explain obvious Rails concepts unless requested.
* When suggesting changes, show the final code.
* Clearly warn about risks.

---

## Git & Commits (CRITICAL RULES)

### Commits
* Commit messages must follow the **Conventional Commits** history pattern in **English** (e.g. `feat: ...`, `fix: ...`, `perf: ...`, `docs: ...`).
* Keep titles short and descriptive.

### Direct Push
* **NEVER** use `git push` or suggest pushing changes directly. All code delivery must go through pull requests or the defined deployment integration flow.

---

## Purpose of This Document

This document serves as a single source of truth for:
* AI agents (giving precise instruction sets on styling and conventions).
* Code reviews and developer guidelines.
