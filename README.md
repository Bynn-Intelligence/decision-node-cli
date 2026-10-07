# dn

The DecisionNode command line. Ask a yes-or-no, choice or score question about any text, JSON or image, from a terminal, a shell script or a pipeline.

```sh
$ dn truth "Is this message a refund request?" -s "I want my money back for order 4411."
truth  0.94
```

One native binary, no runtime. Every install puts the same program on your path twice, as `dn` and as `bynn-dn`; use `bynn-dn` if `dn` is already taken in your shell.

## Install

**macOS and Linux**

```sh
curl --proto '=https' --tlsv1.2 -fsSL https://raw.githubusercontent.com/Bynn-Intelligence/decision-node-cli/main/install.sh | sh
```

The script picks the archive for your platform from the latest release, checks it against the release's `checksums.txt` and installs `dn` and `bynn-dn` to `~/.local/bin`. When [cosign](https://docs.sigstore.dev) is installed it first verifies the release's keyless signature of `checksums.txt`, and refuses to install if it does not verify; without cosign it says so and relies on the checksum alone. Every download is https only over TLS 1.2 or later, and a release tag must be a version such as `v0.1.0` before it is used. The whole script runs from one function called on its last line, so a download cut short runs nothing. Set `DN_INSTALL_DIR` to install elsewhere, or `DN_VERSION` (for example `v0.1.0`) to pin a version.

**Homebrew** (macOS and Linux)

```sh
brew install bynn-intelligence/bynn/dn
```

**Scoop** (Windows)

```powershell
scoop bucket add bynn https://github.com/Bynn-Intelligence/scoop-bynn
scoop install dn
```

**Direct download.** Every [release](https://github.com/Bynn-Intelligence/decision-node-cli/releases/latest) has an archive for macOS (arm64, x86-64), Linux (arm64, x86-64, static) and Windows (x86-64, arm64), `.deb` and `.rpm` packages, `checksums.txt`, and a signature of the checksums.

## Set your API key

```sh
dn auth login            # prompts for the key without echoing it
dn auth status           # where the key comes from, and whether it works
```

`dn auth login` keeps the key in your operating system's keychain (macOS Keychain, Windows Credential Manager, the Secret Service on Linux). Where there is no keychain it writes `~/.config/decisionnode/credentials.json`, readable only by you (mode 0600, in a directory with mode 0700), and says so. If that file's mode is ever wider than 0600, `dn` does not use the key in it and tells you the `chmod 600` command to run. In CI, set the environment variable instead:

```sh
export DECISIONNODE_API_KEY=...
```

There is no flag that takes the key itself: a key on a command line ends up in shell history and process lists.

## Examples

```sh
# A yes-or-no question. --min turns the probability into an exit code.
git diff --staged | dn truth "Does this diff add a secret, key or password?" --min 0.5 -q && echo "blocked"

# One option of a set, each option NAME or NAME=DESCRIPTION.
dn choice "Which team should handle this?" -f ticket.txt \
  -o billing="Payments and invoices" -o technical="Bugs and outages" -o sales

# A place on an ordered scale, lowest level first, about an image.
dn score "How readable is the receipt?" --image receipt.jpg \
  -l unreadable -l "partly readable" -l "fully readable"

# Several questions about one state: the full request as JSON.
cat request.json | dn decide - | jq '.answers.route.choice'

# A file of records, one result a line.
dn batch tickets.jsonl --questions questions.json --out results.jsonl
```

## Commands

| Command | What it does |
|---|---|
| `dn truth <instructions>` | A yes-or-no question, answered with the probability of yes. `--true` and `--false` say what a yes and a no mean. `--min P` exits 1 when the probability is below `P`. |
| `dn choice <instructions> -o NAME[=DESCRIPTION] ...` | One option of a set. `--options-file` takes a JSON object of name to description, or one name a line. |
| `dn score <instructions> -l LEVEL ...` | A place on an ordered scale, levels lowest first. |
| `dn decide <request.json \| ->` | The full request body (state, questions, images, model) from a file or stdin. |
| `dn batch <requests.jsonl \| ->` | Many requests, one a line. See [Batch](#batch). |
| `dn models` | The models your key may use, with their limits. |
| `dn auth login \| status \| logout` | Store, check and remove the API key. |
| `dn config get \| set \| list` | The stored base URL, model and profiles. |
| `dn version`, `dn help`, `dn completion <shell>` | Version, help, and shell completion for bash, zsh, fish and PowerShell. |

Flags for every command:

| Flag | |
|---|---|
| `-m, --model ID` | The model, such as `decisionnode-latest` (the default), `decisionnode-1.0` or `decisionnode-1.0-flash` |
| `--flash` | Short for `--model decisionnode-flash-latest` |
| `--base-url URL` | The API's address, for a self-hosted server. It must be `https://`; plain `http://` is accepted only for `localhost`, `127.0.0.1` and `::1` |
| `--profile NAME` | The settings and key of a named profile |
| `--timeout T` | Time allowed for each attempt, in seconds or as `30s` (default 10 s) |
| `--retries N` | Retries after the first attempt on temporary errors (default 2) |
| `--json`, `--value`, `--full`, `--meta` | Output modes, below |
| `-q, --quiet` | Print no result and no notices; errors are still printed |

## Input

The state for `truth`, `choice` and `score` is the first of these that is present:

1. `-s, --state TEXT`
2. `-f, --state-file PATH` (`-` reads stdin)
3. stdin, when something is piped in
4. nothing: the question is answered from its instructions alone

The text is sent exactly as given. For a structured state, or several questions about one state, use `dn decide`.

Images: `--image PATH`, `--image URL` or `--image ID=PATH`, up to four. Without an id, the file name without its extension is the id. Local files must be JPEG, PNG or WebP; URLs must be `https`.

## Output

Results go to stdout and everything else to stderr.

| Mode | When | Printed |
|---|---|---|
| Text | stdout is a terminal | The answer in a few aligned lines: the value, the confidence, the probabilities highest first. Colour only on a terminal, off with `NO_COLOR`. |
| JSON | stdout is not a terminal, or `--json` | One line of compact JSON. For `truth`, `choice` and `score`, the answer object as the API sent it, such as `{"type":"truth","truth":0.94}`. For `decide` and `models`, the response body as sent. |
| Value | `--value` | Only the value and a newline: the probability, the option name, or the score. `dn decide --value` prints `id<TAB>value` lines when there is more than one question. |

`--full` prints the whole response body for `truth`, `choice` and `score`. `--meta` adds a `meta` object with `request_id`, `model`, `latency_ms`, `input_tokens` and `safety` (the safety check's probabilities and flags, from the hosted API). Numbers are printed exactly as the API sent them, never rounded again.

```sh
$ dn choice "Which team?" -s "My card was charged twice." -o billing -o technical -o sales --meta
{"type":"choice","choice":"billing","confidence":0.73,"probabilities":{"billing":0.86,"sales":0.08,"technical":0.06},"meta":{"request_id":"req_...","model":"decisionnode-1.0","latency_ms":41,"input_tokens":38,"safety":{"checked":true,"harm":0.012,"self_harm":0.003,"flagged":[]}}}
```

## Errors and exit codes

An error is a sentence on stderr when stderr is a terminal, and one JSON object otherwise:

```json
{"error":{"status":422,"error_type":"validation_error","message":"...","reason":"...","request_id":"..."}}
```

`reason` is the server's explanation in words. A refusal also carries `category` and `safety`; a rate limit carries `retry_after` in seconds.

| Exit code | Meaning |
|---|---|
| 0 | Answered |
| 1 | Answered, and `--min` was not met |
| 2 | The command line or the input is wrong; nothing was sent |
| 3 | The key is missing or rejected, or the account is out of credit (401, 402, 403) |
| 4 | The request was refused by the safety check (403 refusal) |
| 5 | The API rejected the request (400, 404, 422, over the token limit, a redirect, any other status without a meaning of its own) |
| 6 | Temporary: rate limit, overload, timeout or network, after the retries (429, 529, other 5xx) |
| 7 | `dn batch` finished and some lines failed |

Temporary errors are retried twice by default, waiting as long as the server asks (`retry-after-ms`, then `Retry-After` in seconds or as a date, at most 60 seconds) or backing off exponentially. A request the server rejected or refused is never retried. Redirects are never followed, so the key is never sent to another address.

## Batch

```sh
dn batch tickets.jsonl --questions questions.json --out results.jsonl
```

- **Input:** JSON Lines. Each line is a full request, or, with `--questions FILE`, only a state: any JSON value, or an object with `id` and `state`. The questions file is a JSON object of questions, or a request without a state (its `model` and `images` are used too). A full request line may carry an `id`; it is copied to the result and not sent.
- **Output:** one line per input line, in input order, to stdout or `--out FILE`:
  `{"index":0,"id":"t-1","response":{...}}` or `{"index":1,"id":null,"error":{...}}`.
- **Speed:** `--concurrency N` requests in flight (default 8). When the server answers 429 with a wait, no new line starts until the wait is over.
- **Long jobs:** `--resume` reads `--out`, skips the lines already answered and appends the rest. Lines that failed are sent again; the last result for an index is the one that counts. Progress goes to stderr, on a terminal only.
- A failed line does not stop the batch. The exit code is 7 when any line failed, else 0.

## Configuration

| Setting | Flag | Environment variable | Default |
|---|---|---|---|
| API key | none | `DECISIONNODE_API_KEY` | the stored key |
| Base URL | `--base-url` | `DECISIONNODE_BASE_URL` | `https://api.decisionnode.com` |
| Model | `-m, --model`, `--flash` | `DECISIONNODE_MODEL` | `decisionnode-latest` |
| Profile | `--profile` | `DECISIONNODE_PROFILE` | `default` |

A flag beats the environment, which beats the stored configuration, which beats the default. The key goes with every request, so a base URL from any of them must use `https://`, or `http://` to `localhost`, `127.0.0.1` or `::1`; any other plain `http://` address stops `dn` with exit code 2 before anything is sent. Stored settings live in `~/.config/decisionnode/config.toml` (`$XDG_CONFIG_HOME` is honoured; `%AppData%\decisionnode` on Windows):

```sh
dn config set model decisionnode-flash-latest
dn config set base_url https://decisions.example.com --profile selfhosted
dn auth login --profile selfhosted
dn config list
```

```toml
model = "decisionnode-flash-latest"

[profiles.selfhosted]
  base_url = "https://decisions.example.com"
```

A profile's settings fall back to the top-level ones. Keys are stored per profile.

`dn` sends no telemetry, checks for no updates and calls nothing but the API.

## Updating

```sh
brew upgrade dn          # Homebrew
scoop update dn          # Scoop
# or run the install script again
```

## License

MIT. Copyright (c) 2026 Bynn Intelligence, Inc.
