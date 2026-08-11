# Contributing

This repository follows the Smart Helpdesk AI specification in `README.md` and `README.vi.md`.

## Development Principles

- Keep changes scoped to the current implementation step.
- Preserve existing user changes and avoid unrelated rewrites.
- Prefer simple, testable code over premature abstraction.
- Keep secrets in local `.env` files only. Use `.env.example` for placeholders.
- Add or update tests when changing behavior.

## Expected Checks

Run the most relevant checks for the area you changed:

- Backend or AI service: formatting, linting, and `pytest` once configured.
- Web Admin: formatting, linting, and build/test commands once configured.
- Mobile: `dart format`, `flutter analyze`, and `flutter test` once configured.
- Documentation-only changes: review Markdown and confirm links/paths are accurate.

## Monorepo Layout

- `web`: Flutter Web Admin Dashboard and chat widget demo.
- `mobile`: Flutter Mobile App for staff.
- `backend/api`: FastAPI backend and orchestration API.
- `backend/ai`: FastAPI AI microservice for classification, RAG, and document processing.
- `packages/shared`: Shared API contracts, schemas, and documentation.
- `infra`: Supabase migrations and deployment notes.
- `docs`: Architecture and API documentation.
