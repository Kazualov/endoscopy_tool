### Continuous Integration

This project uses **GitHub Actions** for Continuous Integration (CI). The CI workflows are triggered on every push and pull request.

#### CI Workflow

The CI pipeline consists of the following jobs:

- **Lint Python** (`lint-python`)
- **Lint Flutter** (`lint-flutter`)
- **Build Flutter App for Windows** (`build-flutter`)
- **Python Tests with coverage** (`test-python`)
- **Flutter Tests with coverage** (`test-flutter`)
- **Security Check with Safety** (`security-check`)

The full CI workflow file can be found here:  
👉 [`CI`](https://github.com/Kazualov/endoscopy_tool/actions/runs/16092200891)

#### Static Analysis Tools

| Tool             | Language | Purpose                                                              |
|------------------|----------|----------------------------------------------------------------------|
| `flake8`         | Python   | Static analysis for Python code to enforce PEP8 style and catch bugs. |
| `flutter analyze`| Dart     | Analyzes Dart code for potential errors and style violations.        |

#### Testing Tools

| Tool              | Language | Purpose                                                             |
|-------------------|----------|---------------------------------------------------------------------|
| `pytest`          | Python   | Runs unit and integration tests.                                   |
| `pytest-cov`      | Python   | Collects and reports Python test coverage.                         |
| `flutter test`    | Dart     | Runs Flutter unit and widget tests.                                |
| `lcov` + `genhtml`| Dart     | Generates HTML coverage reports for Flutter test results.          |

#### Security Tools

| Tool    | Language | Purpose                                              |
|---------|----------|------------------------------------------------------|
| `safety`| Python   | Checks for known security vulnerabilities in dependencies. |

#### CI Workflow

The full CI workflow file can be found here:  
👉 [CI](https://github.com/Kazualov/endoscopy_tool/blob/Tests/.github/workflows/ci.yml)


#### CI Workflow Runs

You can view the status and history of all CI runs here:  
👉 [GitHub Actions - Workflow Runs](https://github.com/Kazualov/endoscopy_tool/actions)

