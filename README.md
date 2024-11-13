# SubKt Builder

Automatically build [SubKt](https://github.com/TypesettingTools/SubKt) projects.

## Usage

The `subkt-builder` action
is used to build [SubKt](https://github.com/TypesettingTools/SubKt) projects.
It works by resolving the dependencies
of the `mux` (or other specified) task
and running them,
returning the artifacts as build outputs.

To use the action,
create a basic workflow file:

```yaml
# .github/workflows/subkt-build.yml
name: Build SubKt Project

on:
  push:
    paths:
      - "**/*.ass"
  pull_request:
    paths:
      - "**/*.ass"

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: LightArrowsEXE/subkt-builder@v1
        with:
          # Optional: specify a different mux task (default: 'mux')
          mux-task: "mux"
          # Optional: only build episodes with changes (default: false)
          incremental: true
```

If you want to run specific tasks directly
without dependency resolution:

```yaml
# .github/workflows/subkt-build.yml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: LightArrowsEXE/subkt-builder@v1
        with:
          # Empty mux-task disables dependency resolution
          mux-task: ""
          # Comma-separated list of task types to run (e.g., 'merge,swap' will run these tasks for all episodes)
          tasks: "merge,swap"
```

## Parameters

The following parameters are available:

| Parameter     | Required | Description                                                                                          |
| ------------- | -------- | ---------------------------------------------------------------------------------------------------- |
| `mux-task`    | No       | The muxing task to execute the dependencies of. If empty, no dependency resolution will be performed |
| `incremental` | No       | Only build episodes with changes (only used if mux-task is specified)                                |
| `tasks`       | No       | Comma-separated list of task types to run (e.g., 'merge,swap' will run these tasks for all episodes) |

## Outputs

The action uploads all files
from the `build/` directory
as artifacts,
excluding temporary files
and Gradle-specific directories.
These artifacts can be downloaded
from the GitHub Actions interface
or used in subsequent workflow steps.

Example of accessing the artifacts
in a subsequent job:

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: LightArrowsEXE/subkt-builder@v1
        with:
          tasks: "merge,swap"

  deploy:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: build-artifacts
          path: build
      # Use the artifacts...
```
