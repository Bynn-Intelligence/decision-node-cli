# Changelog

All notable changes to `dn` are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/). Each release's notes are its
section below.

## [0.2.2] - 2026-10-15

- A Depth Vision reading with other than seven directions is shown as it was sent, as JSON, rather than in words.

## [0.2.1] - 2026-10-15

- Depth Vision and Segment Vision: `--booster bynn_depth` with `--depth-grid`, and `--booster bynn_segment` with `--segment-prompt`; on a terminal their readings are written out: the distance straight ahead and in seven directions, and each match with its score, centre and distance.
- `--ocr-prompt`, `--face-collection` and `--face-threshold` are listed in the help, and the README lists every booster.

## [0.2.0] - 2026-10-14

- `dn usage key` and `dn usage list`: each key's usage and cost for a period, by hour, day or month and by model or channel, filtered by label, device, key, kind and status, with `--all` to read every page.
- `dn keys`: make, list, change and revoke Decisions-only keys for your devices with a Manage device keys key, and revoke a group by label, counted first with `--dry-run`.
- An error whose answer has `details` prints them, such as the models a publishable key may ask or when a key's daily spend cap resets. A key's spent daily cap is not retried.

## [0.1.1] - 2026-10-13

- Builds for 32-bit ARM Linux: `armv7` for a Raspberry Pi 2 or later on a 32-bit system, and `armv6` for the Pi Zero and Pi 1, as archives, and a `.deb` (`armhf`) and `.rpm` package that run on every Pi. The install script picks the right archive.

## [0.1.0] - 2026-10-13

The first release of `dn`, the DecisionNode command line.

- Questions from a terminal, a script or a pipeline: `dn truth`, `dn choice`, `dn score` and `dn number` about text, JSON, images and videos, and `dn decide` for a full request with several questions about one state.
- Images by path, URL or upload; videos sent as frames taken on your machine with ffmpeg.
- Boosters with `--booster`: `age` and `ai_generated` read the request's images first, and their readings are added as evidence.
- Live sessions with `dn session`, and the Batch API with `dn batch run`, or as live calls with `--live`.
- Fine-tuned models by name, listed with `dn models`.
- Output as text on a terminal and as the API's JSON in a pipe, exit codes for every outcome, and errors that carry the API's `error_type`.
- The API key from the environment, the system keychain or a credentials file readable only by you.
- One native binary for macOS, Linux and Windows on x86-64 and arm64, installed as both `dn` and `bynn-dn`, with `.deb` and `.rpm` packages, a Homebrew cask, a Scoop manifest, and checksums with a keyless signature.
