# Development

This file describes how to run the integration test locally.

## Prerequisites

- Docker (Docker Desktop on macOS) — ensure the daemon is running.
- Docker Compose v2 (`docker compose`).

## Run the integration test

Make the test script executable (only needed once) and run it:

```bash
chmod +x tests/integration_test.sh
bash tests/integration_test.sh
```

What the script does:

- Builds the Docker image and prints the build output.
- Starts the Caddy container with an isolated project name.
- Runs a set of HTTP assertions, including `.env` substitution inside an imported Caddy config, and prints a `Passed: X/Y` summary.
- Tears down containers and volumes on exit.

Notes:

- Default test port is `8484`. To change it, edit the `TEST_PORT` variable at the top of [tests/integration_test.sh](tests/integration_test.sh).
- If the test fails, re-run the script and inspect the compose logs.
