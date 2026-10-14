# mac-clean

A safe, interactive macOS cleanup script for developers.

`mac-clean` helps reclaim disk space from disposable caches, logs, and build artifacts while deliberately avoiding source code, Git repositories, Xcode Archives, simulator data, Docker data, device backups, Time Machine snapshots, and other persistent user data.

## Why this exists

macOS "System Data" can grow significantly over time, especially on development machines. Instead of manually hunting through cache folders, this script scans a conservative set of locations, shows their sizes, and asks before cleaning each one.

The goal is not maximum deletion. The goal is useful cleanup with a clear safety boundary.

## Install with Homebrew (recommended)

Install `mac-clean` on macOS with a **single command**:

```bash
brew install yaohuangguan/tap/mac-clean
```

Homebrew automatically adds the project's maintained tap. The following commands then work from any terminal:

```bash
mac-clean --help      # options and usage
mac-clean --version   # installed version
mac-clean --dry-run   # safe preview: no files are deleted
mac-clean             # interactive cleanup
```

Alternatively, once the tap is registered with `brew tap yaohuangguan/tap`, use `brew install mac-clean`.
The unqualified `brew install mac-clean` command cannot work on a brand-new Homebrew installation until the formula is available in a previously added tap or in the official `homebrew/core` repository.

The official tap is [yaohuangguan/homebrew-tap](https://github.com/yaohuangguan/homebrew-tap); it installs a versioned, SHA-256-verified GitHub release rather than downloading a moving script.

## Quick run

If you have already reviewed the source:

```bash
curl -fsSL https://assets.samyao.me/uploads/scripts/mac-clean.sh | bash
```

Because piping a remote script directly into Bash should always be treated carefully, first-time users are encouraged to inspect it before running:

```bash
curl -fsSL https://assets.samyao.me/uploads/scripts/mac-clean.sh -o mac-clean.sh
less mac-clean.sh
bash mac-clean.sh
```

You can also run the GitHub-hosted source directly:

```bash
curl -fsSL https://raw.githubusercontent.com/yaohuangguan/mac-clean/master/mac-clean.sh | bash
```

## What it cleans

| Category | Location / command | Behaviour |
|---|---|---|
| User app caches | `~/Library/Caches` | Deletes cache contents |
| User logs | `~/Library/Logs` | Deletes log contents |
| Xcode DerivedData | `~/Library/Developer/Xcode/DerivedData` | Deletes generated Xcode build/index data |
| npm cache | `npm cache clean --force` | Uses npm's configured cache path |
| pnpm unused store data | `pnpm store prune` | Prunes unreferenced package data |
| pip cache | `python3 -m pip cache purge` | Purges Python download/build cache |
| Gradle cache | `~/.gradle/caches` | Deletes Gradle cache contents |
| Homebrew download cache | `brew --cache` | Deletes downloaded Homebrew cache contents |

Each cleanup item is measured before and after so the script can report logical space reclaimed.

## What it intentionally does NOT delete

The script does not remove:

- source code or Git repositories
- Documents, Desktop, Downloads, or arbitrary personal files
- Xcode Archives
- iOS DeviceSupport
- CoreSimulator devices or simulator data
- Docker images, containers, volumes, or build data
- iPhone / iPad backups
- Time Machine snapshots
- `~/Library/Application Support`
- `~/Library/Containers`
- `~/Library/Group Containers`
- `/System`

Some of these locations may still be shown in the report so you can see where disk space is being used without deleting anything automatically.

## Report-only areas

The script reports sizes for:

- Xcode Archives
- iOS DeviceSupport
- CoreSimulator
- iPhone / iPad backups
- Application Support
- App Containers
- Group Containers
- Docker storage via `docker system df`, when Docker is available
- the largest folders directly under `~/Library`

This is useful when the actual storage problem is not cache data.

## Interactive behaviour

The current version uses:

```text
[Y/n]
```

That means:

- Enter → clean
- `y` → clean
- `n` → skip

Each category is handled independently.

> Note: the default answer is **YES**, so read each prompt before pressing Enter.

## Why interaction works with `curl | bash`

When a script is piped into Bash, standard input is already being used to feed the script itself. To keep prompts interactive, `mac-clean` reads confirmation input directly from:

```text
/dev/tty
```

This allows:

```bash
curl -fsSL https://assets.samyao.me/uploads/scripts/mac-clean.sh | bash
```

to remain interactive.

If no readable interactive terminal is available, the script exits instead of continuing blindly.

## Cleanup summary

At the end, the script reports:

- reclaimed space for each cleaned category
- total logical data removed
- filesystem free-space change
- elapsed time
- disk usage after cleanup

The logical amount removed may differ from the actual filesystem free-space increase because of APFS behaviour, purgeable space, swap activity, open files, and background processes.

## Requirements

Core requirements:

- macOS
- Bash
- an interactive terminal

Optional tools are detected automatically:

- npm
- pnpm
- Python 3 + pip
- Homebrew
- Docker

If one of these tools is not installed, its relevant section is skipped.

## Security

Never blindly execute shell scripts downloaded from the internet, including this one.

The repository exists so the full source can be reviewed before execution. If you are using the CDN command, you can compare the downloaded file with the source in this repository first.

Recommended first run:

```bash
curl -fsSL https://assets.samyao.me/uploads/scripts/mac-clean.sh -o mac-clean.sh
less mac-clean.sh
bash mac-clean.sh
```

## Design philosophy

The priority order for this project is:

1. Transparency
2. Safety
3. Useful cleanup
4. Maximum reclaimed space

If a directory may contain meaningful user or development state, this script prefers to report it rather than delete it.

## License

MIT License. See [LICENSE](./LICENSE).
