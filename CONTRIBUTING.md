# Contributing to Eigen

## Rules

1. **Strict Ownership**: Do not edit another person's folder (`engine/`, `app/`, `docs/`, or `tests/`) without a reviewed Pull Request.
2. **No Exceptions Cross the Boundary**: C++ must catch _all_ exceptions and return a status code. A C++ crash takes down the entire JVM.
3. **Naming Convention**: Use `snake_case` everywhere across the codebase (C++, Java, Bash, and filenames), except for Git branch descriptions which must use `kebab-case`.

## Git Workflow

1. **Start Fresh**: Always begin your session with `git checkout main && git pull`.
2. **Branch Naming**: Use the format `<type>/<short-description>` with `kebab-case` descriptions.
   - Prefixes: `feat/`, `fix/`, `refactor/`, `test/`, `docs/`, `build/`, `chore/`
   - Examples: `fix/jni-memory-leak`, `test/matrix-edge-cases`, `build/cmake-maven-pipeline`
3. **Commits**: Commit small and often with descriptive messages (e.g., `Lexer: add support for matrix literals`).
4. **Pull Requests**:
   - Every PR requires at least **one review** from a teammate outside the modified folder (e.g., Java dev reviews C++ PRs).
   - All tests must pass before merging.
   - Branch protection is enabled on `main`.

## Testing Requirements

Before any PR is merged, the author must verify:

- [ ] C++ tests pass with no AddressSanitizer reports (`ctest --test-dir engine/build --output-on-failure`).
- [ ] Java tests pass (`mvn test` in the `app/` directory).
- [ ] The application builds and runs successfully on all systems.

## Questions?

If you are unsure about a design decision, ask in the team chat _before_ writing the code.
