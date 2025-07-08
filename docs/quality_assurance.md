### Quality attribute scenarios
See [quality-assurance/quality-attribute-scenarios.md](quality-assurance/quality-attribute-scenarios.md)

### Automated tests

**Tools used:**
- `pytest` — unit and integration testing
- `TestClient` — for simulating API requests and integration testing in Dart backend
- `flutter_test` — for writing and executing unit tests in Flutter
- `flake8` — for checking Python code style
- `bandit` — for Python security linting

**Types of tests:**
- Unit test for Python ([/Unit Tests/Process_Command.py](https://github.com/Kazualov/endoscopy_tool/blob/Tests/Unit%20Tests/Process_Command.py))
- Integration tests ([Integration_Tests](https://github.com/Kazualov/endoscopy_tool/tree/Tests/Integration_Tests))
- Unit tests for Flutter ([test](https://github.com/Kazualov/endoscopy_tool/tree/Tests/test))
- Static analysis tools in CI pipeline ([workflow](https://github.com/Kazualov/endoscopy_tool/actions/runs/16092200891/workflow))

### User acceptance tests
See [quality-assurance/user-acceptance-tests.md](quality-assurance/user-acceptance-tests.md)
