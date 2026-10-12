# dn

The DecisionNode command line. Ask a yes-or-no, choice, score or number question about any text, JSON, image or video, from a terminal, a shell script or a pipeline; run a live session over a stream of readings; or send thousands of requests through the Batch API at half the price.

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

# A value on a grid you define: 0 to 50 cars, about an image by URL.
dn number "How many cars are visible?" --image https://files.example.com/lot-b4.jpg --max 50 --value

# A video file, sent as frames taken on this machine: two a second over the first minute.
dn truth "Does a person fall?" --video dock.mp4 --end 60

# A booster reads the picture first and its reading is added as evidence.
dn truth 'Is the person in `selfie` an adult?' --image selfie.jpg --booster age

# Several questions about one state: the full request as JSON.
cat request.json | dn decide - | jq '.answers.route.choice'

# A file of records through the Batch API: half the price, results within 24 hours.
dn batch run tickets.jsonl --questions questions.json --out results.jsonl

# The same file as live calls, for answers now.
dn batch run --live tickets.jsonl --questions questions.json --out results.jsonl

# A live session: one reading a line on stdin, one reply a line on stdout.
tail -f readings.jsonl | dn session open.json
```

## Commands

| Command | What it does |
|---|---|
| `dn truth <instructions>` | A yes-or-no question, answered with the probability of yes. `--true` and `--false` say what a yes and a no mean. `--min P` exits 1 when the probability is below `P`. |
| `dn choice <instructions> -o NAME[=DESCRIPTION] ...` | One option of a set. `--options-file` takes a JSON object of name to description, or one name a line. |
| `dn score <instructions> -l LEVEL ...` | A place on an ordered scale, levels lowest first. |
| `dn number <instructions> [--min N] [--max N] [--step S]` | A value on the grid `min`, `min+step`, ... up to `max`. A bound left out is not sent, so the API's default applies (0, 255 and 1). `min` and `step` take up to 6 decimals; a grid holds at most 4,096 values. |
| `dn decide <request.json \| ->` | The full request body (state, questions, images, videos, boosters, model) from a file or stdin, sent as written. `--booster` replaces the file's boosters. |
| `dn upload <image> ...` | Uploads images (`PATH` or `ID=PATH`) and prints one line per image, `{"id":...,"upload_id":...,"expires_at":...}`, for requests written by hand. |
| `dn session <open.json>` | A live session: frames as JSON Lines on stdin, replies on stdout. See [Sessions](#sessions). `dn session end ID` ends one from another terminal. |
| `dn batch run <requests.jsonl \| ->` | Many requests, one a line, through the Batch API, or as live calls with `--live`. See [Batch](#batch). |
| `dn batch create \| add \| finalize \| get \| list \| results \| cancel` | The Batch API's calls one by one, each printing the API's batch object, page or result lines exactly as sent; result lines are printed as they arrive. |
| `dn models` | The models your key may use, with their limits, your fine-tuned models included (with `fine_tuned`, `base`, `adapter_version` and `status`). |
| `dn auth login \| status \| logout` | Store, check and remove the API key. |
| `dn config get \| set \| list` | The stored base URL, model and profiles. |
| `dn version`, `dn help`, `dn completion <shell>` | Version, help, and shell completion for bash, zsh, fish and PowerShell. |

Flags for every command:

| Flag | |
|---|---|
| `-m, --model ID` | The model (when `decisionnode-moe` has no free capacity the API may answer with `decisionnode-flash`, which `--meta` shows; `--no-fallback`, or a request file with `"fallback": false`, waits for its own model instead), `decisionnode-moe` (the default) or `decisionnode-flash`, each its current release, a pinned id `decisionnode-<family>-<version>` from `dn models` (an answer names the pinned id that answered), or one of your fine-tuned models, `decisionnode-flash@acme/fraud` (the version deployed last) or `decisionnode-flash@acme/fraud:3` (one version) |
| `--flash` | Short for `--model decisionnode-flash` |
| `--base-url URL` | The API's address, for a self-hosted server. It must be `https://`; plain `http://` is accepted only for `localhost`, `127.0.0.1` and `::1` |
| `--profile NAME` | The settings and key of a named profile |
| `--timeout T` | Time allowed for each attempt, in seconds or as `30s` (default 10 s; 30 s for a request naming `ocr`, with `--booster ocr` or in a `dn decide` file, which is never retried after a timeout, its other retries kept, since the API finishes that attempt and may bill it) |
| `--retries N` | Retries after the first attempt on temporary errors (default 2) |
| `--inline-threshold BYTES` | Local images of one request under this size in all go inline, at or above it they are uploaded first (default 524288) |
| `--json`, `--value`, `--full`, `--meta` | Output modes, below |
| `-q, --quiet` | Print no result and no notices; errors are still printed |

## Input

The state for `truth`, `choice` and `score` is the first of these that is present:

1. `-s, --state TEXT`
2. `-f, --state-file PATH` (`-` reads stdin)
3. stdin, when something is piped in
4. nothing: the question is answered from its instructions alone

The text is sent exactly as given. For a structured state, or several questions about one state, use `dn decide`.

Images: `--image PATH`, `--image URL` or `--image ID=PATH`, up to 16. Without an id, the file name without its extension is the id.

There are two ways to say which image a question is about:

1. **By id (recommended).** Give each image a short, meaningful id (the file name, or `ID=PATH`) and use it in the instructions, in backticks.
2. **By number.** Images are numbered from 1 in the order of the `--image` flags: "image 2", "the second image", "Picture 2" and "the last image" all work.

The model sees each image as `Picture 1 (receipt):`, `Picture 2 (claim_photo):`, so both ways point to the same image. Prefer ids: they stay right when images are added or reordered. Use names, not digits, as ids (`front`, not `2`). Videos work the same way, by id or by number ("video 1"), numbered separately in the order of the `--video` flags. In a request file, the `image` of a point or box question takes the id.

```sh
dn truth 'Does the total on `receipt` match the amount in the claim?' -s "Expense claim 4411: 740.00 EUR." \
  --image receipt.jpg --image claim_photo=photo.jpg
```

- **A URL** is the fastest input: it is sent as given and nothing is uploaded. It must be `https` and at most 2,048 characters.
- **A file** is checked before anything is sent: JPEG, PNG or WebP by its first bytes, at most 10 MB, at most 40 megapixels (read from its header). A file that breaks a rule exits 2 with the API's own error type and message. No image is resized.
- When the local images of a request total under 512 KiB they are sent inline; at or above it they are uploaded first, in parallel, and the request names them. `--inline-threshold BYTES` moves the line. Each upload to storage has 60 seconds per attempt, apart from `--timeout`, which bounds the API calls.
- Many large images can pass the model's token limit, which the API refuses (exit 5).
- A request body may be at most 25 MiB. Local images at or above the inline threshold are uploaded and do not count, so only a very long state, many video frames or inline `data` in a request file can pass it; `dn` refuses such a request before sending anything (exit 5), and `dn decide` sends its file as written, which the API refuses the same way.
- `dn` remembers what it uploaded, in `uploads.json` under `$XDG_CACHE_HOME/decisionnode` (else `~/.cache/decisionnode`; `%LocalAppData%\decisionnode` on Windows; mode 0600): a script that asks about the same large image ten times uploads it once. An entry is keyed by the image's SHA-256, its type and a fingerprint of the base URL and key (never the key itself), and is used until 5 minutes before its upload expires.

Videos: `--video PATH` or `--video ID=PATH`, up to 4, for `truth`, `choice`, `score` and `number`. Without an id, the file name without its extension is the id.

- `dn` turns each file into frames on your machine with `ffprobe` and `ffmpeg`, which must be on your `PATH` ([FFmpeg](https://ffmpeg.org/download.html)). Only the frames are sent: never the file, its address or its sound. Without them, `--video` exits 2 and says which is missing; a request file for `dn decide` can carry frames you took yourself.
- Within the window, a frame is taken when it is the first, or at least 1/fps seconds (less a millisecond) after the frame taken before it. Each frame keeps its time in the video, in seconds from its first frame, and the display rotation is applied. Each is sent as a JPEG with its longer side at most 640 pixels, never enlarged.
- `--fps` caps the rate (default 2, at most 4). `--start` and `--end` choose the window, in seconds from the video's first frame (default the whole video). `--max-frames` caps the frames taken from each file (default 32, at most 128); when the window holds more, the first ones are sent and a note on stderr says so. The same settings apply to every `--video` of the command.
- When the API reads a video at a lower rate or resolution than sent, it says so, and `dn` prints its words on stderr.

Boosters: `--booster NAME`, up to 4, for `truth`, `choice`, `score`, `number` and `decide`. A booster is a specialist model that reads the request's images before the decision; its reading is added to what the model sees as evidence. `age` reads how old the person in a picture is (the largest face), and `ai_generated` how likely a picture was made by an image generator, and who signed its Content Credentials. `NAME:required` makes the request fail (exit 6) when that booster fails or does not answer in time; otherwise the decision runs without the reading, and the evidence says why. A request file may carry `boosters` as the API takes them (a name, or `{"name": ..., "require": true}`), and so may the lines and the questions file of `dn batch`; sessions take none.

```sh
$ dn truth 'Is the person in `selfie` an adult?' --image selfie.jpg --booster age --booster ai_generated
truth           0.97
evidence
  age           ok, 212 ms, age-v3, 1 call billed
    selfie      age 27 (22 to 33), confidence 0.81, faces 1
  ai_generated  ok, 340 ms, ai_generated-v2, 1 call billed
    selfie      generated 0.02, confidence 0.97, c2pa, top generator none, signed by Example Camera Co.
```

A booster that must read for the decision to stand is given as `NAME:required`:

```sh
dn truth 'Is the person in `selfie` an adult?' --image selfie.jpg --booster age:required
```

An `ai_generated` reading names a top generator only when the picture reads as likely generated, and shows `c2pa untrusted` when the file carries Content Credentials that are not trusted. A picture a booster did not read (it timed out or failed) shows as `unread`, and one it could not decode as `unreadable`; neither is billed. On a terminal the readings are printed after the answers; in JSON they are in the response body, which `--full` prints (and `dn decide` always prints). Booster calls are billed one per booster and image read with status `ok`, at the price per call on [Pricing](https://decisionnode.com/docs/pricing#boosters), a reading the API had already made for your workspace included; a booster that timed out or failed is free. Each booster's line shows the calls billed for it; `--meta` shows the readings' tokens, the calls billed in all and each booster's status and time.

Points and boxes: a request file for `dn decide` or `dn batch` may ask `point` questions (one spot in an image) and `box` questions (a rectangle), each with the `image` to look in (the image's id) when the request has two or more and `units` `pixels` (the default) or `normalized`. A request with a point or box question needs an image. A reference by number ("Picture 2") goes in the instructions.

```sh
$ dn decide belt.json
pick        point  812 455          present 0.97  confidence 0.91  image belt 1920x1080
damage      box    300 120 520 410  present 0.95  confidence 0.88  image belt 1920x1080
any_damage  truth  0.93
```

A point is `x y` from the top-left corner of the image, a box its top-left and bottom-right corners `x1 y1 x2 y2`. `present` is the probability that what the instructions describe is in the image at all, and `confidence` that the place is right if it is there. `image`, `width` and `height` name the image and its size in pixels. In JSON the answers are printed as the API sent them.

## Output

Results go to stdout and everything else to stderr.

| Mode | When | Printed |
|---|---|---|
| Text | stdout is a terminal | The answer in a few aligned lines: the value, the confidence, the probabilities highest first. Colour only on a terminal, off with `NO_COLOR`. |
| JSON | stdout is not a terminal, or `--json` | One line of compact JSON. For `truth`, `choice` and `score`, the answer object as the API sent it, such as `{"type":"truth","truth":0.94}`. For `decide` and `models`, the response body as sent. |
| Value | `--value` | Only the value and a newline: the probability, the option name, the score or the number, and for a point or a box its coordinates separated by spaces. `dn decide --value` prints `id<TAB>value` lines when there is more than one question. |

`--full` prints the whole response body for `truth`, `choice`, `score` and `number`. `--meta` adds a `meta` object with `request_id`, `model` (for a fine-tuned model, its name pinned to the version that answered), `latency_ms`, `input_tokens` and `safety` (the safety check's probabilities and flags, from the hosted API); for a request with boosters also `booster_tokens` (the readings' share of the input tokens), `booster_calls` (the calls billed) and `boosters` (each booster's status and time, `{"age":{"status":"ok","latency_ms":212}}`); and when another model answered than the one asked for, `fallback` (`{"served_model":"decisionnode-flash-...","requested_model":"decisionnode-moe"}`). A response body's `usage.cost` is what the answer cost in USD (`usd`, its parts `model_usd` and `boosters_usd`, and `free_tier`), printed as the API sent it. Numbers are printed exactly as the API sent them, never rounded again.

```sh
$ dn choice "Which team?" -s "My card was charged twice." -o billing -o technical -o sales --meta
{"type":"choice","choice":"billing","confidence":0.73,"probabilities":{"billing":0.86,"sales":0.08,"technical":0.06},"meta":{"request_id":"req_...","model":"decisionnode-moe-...","latency_ms":41,"input_tokens":38,"safety":{"checked":true,"harm":0.012,"self_harm":0.003,"flagged":[]}}}
```

## Errors and exit codes

An error is a sentence on stderr when stderr is a terminal, and one JSON object otherwise:

```json
{"error":{"status":422,"error_type":null,"message":"...","reason":"...","request_id":"..."}}
```

`error_type` is the API's own, exactly as it sends it, and `null` when its answer has none, so a fault reads the same whether `dn` caught it before sending or the API refused it (where nothing was received, it is `timeout_error`, `connection_error` or `invalid_response`). `reason` is the server's explanation in words. An error whose body is not the API's JSON (a page from a proxy or the service's edge) has `error_type` `null` and the message `HTTP <status> <text>`, such as `HTTP 413 Content Too Large`, with the request id after it when there is one. A refusal also carries `category` and `safety`; a rate limit carries `retry_after` in seconds; an error of a request with boosters carries `boosters`, each booster's status and time, so you can see which required booster failed.

| Exit code | Meaning |
|---|---|
| 0 | Answered |
| 1 | Answered, and `--min` was not met |
| 2 | The command line or the input is wrong; nothing was sent. This includes a video file that cannot be read or `ffmpeg` and `ffprobe` missing, and anything the API would refuse by a fixed rule (an image, a video's frames, a URL, a question, a number grid, a session's window, a frame, batch ids, paging), checked before sending and reported with the API's own `error_type`, which is `null` where the API's answer has none |
| 3 | The key is missing or rejected, or the account is out of credit (401, 402, 403, a booster turned off for your workspace included) |
| 4 | The request was refused by the safety check (403 refusal) |
| 5 | The API rejected the request (400, 404, 413, 422, over the token limit, a request body over 25 MiB, a booster the API does not offer or with no image to read, a redirect, any other status without a meaning of its own) |
| 6 | Temporary: rate limit, overload, timeout or network, after the retries (429, 529, a required booster that failed, other 5xx) |
| 7 | `dn batch` finished and some lines failed, or `dn batch run` timed out before the batch ended (the batch id is printed on stderr) |
| 8 | `dn session` ended with a close code other than 1000 (the code and reason are printed on stderr) |

Temporary errors are retried twice by default, waiting as long as the server asks (`retry-after-ms`, then `Retry-After` in seconds or as a date, at most 60 seconds) or backing off exponentially. A request the server rejected or refused is never retried. Redirects are never followed, so the key is never sent to another address.

## Batch

```sh
dn batch run tickets.jsonl --questions questions.json --out results.jsonl
```

- **Input:** JSON Lines. Each line is a full request, or, with `--questions FILE`, only a state: any JSON value, or an object with `id` and `state`. The questions file is a JSON object of questions, or a request without a state (its `model`, `images` and `boosters` are used too). A line's `id` is copied to its result and not sent. An image in a line may be a file path, as with `--image`.
- **Output:** one line per input line, in input order, to stdout or `--out FILE`:
  `{"index":0,"id":"t-1","response":{...}}` or `{"index":1,"id":null,"error":{...}}`.
- **The Batch API** (the default): `dn` checks every line, creates the batch with every line in one call, queues it, reads it every `--poll` seconds (default 60, at least 10, or the wait the server names when longer) until it has ended, and writes each result as it arrives. Half the price of live calls; results within 24 hours. A line that expired or was cancelled is an `error` whose `status` is `"expired"` or `"cancelled"`. `--no-wait` prints the batch once it is queued and exits; fetch the results later with `dn batch results ID`. A line the API would refuse for its form, or a line id that is repeated or longer than 512 characters, stops the run before anything is sent (exit 2, naming the line).
- **Live calls** (`--live`): one call per line, `--concurrency N` in flight (default 8). When the server answers 429 with a wait, no new line starts until the wait is over. `--resume` reads `--out`, skips the lines already answered and appends the rest.
- **One call at a time:** `dn batch create [FILE]`, `add ID FILE`, `finalize ID`, `get ID`, `list [--offset N] [--limit N]`, `results ID [--out FILE]` and `cancel ID` print the API's batch object, page or result lines exactly as sent, the result lines one by one as they arrive, for scripts that manage batches themselves.
- Progress goes to stderr, on a terminal only. A failed line does not stop the run. The exit code is 7 when any line failed, else 0.

## Sessions

A session sends the fixed part of a decision once, then answers a stream of frames over one connection, each frame costing roughly its own tokens.

```sh
tail -f readings.jsonl | dn session open.json --out replies.jsonl
```

- `open.json` is the session's open body: `state`, `questions`, `instructions`, `window`, `ttl_seconds` and `model` (`--model` or `--flash` wins over the file's).
- Each line of stdin is one frame: `{"seq": 7, "frame": {...}, "image": "camera.jpg", "questions": ["abort"], "reset": false}`. Only `frame` (or `image`) is needed. An `image` given as a file path is sent inline or uploaded, as for `--image`. A frame the API would refuse (an unknown question id, an empty frame, an image by URL) stops the session with exit 2 before it is sent.
- Every reply and frame error is written to stdout (or `--out`) as one JSON line, exactly as the server sent it. When frames come faster than they are answered the newest wins, and the reply that superseded others lists them in `dropped`. The open response goes to stderr on a terminal, or is the first stdout line with `--meta`.
- The end of stdin ends the session after the last reply; so does Ctrl-C. A session that closes with a code other than 1000 exits 8 with the code and reason; `dn` does not reopen it.
- `dn session end ID` ends a session from another terminal.

## Configuration

| Setting | Flag | Environment variable | Default |
|---|---|---|---|
| API key | none | `DECISIONNODE_API_KEY` | the stored key |
| Base URL | `--base-url` | `DECISIONNODE_BASE_URL` | `https://api.decisionnode.com` |
| Model | `-m, --model`, `--flash` | `DECISIONNODE_MODEL` | `decisionnode-moe` |
| Profile | `--profile` | `DECISIONNODE_PROFILE` | `default` |

A flag beats the environment, which beats the stored configuration, which beats the default. The key goes with every request, so a base URL from any of them must use `https://`, or `http://` to `localhost`, `127.0.0.1` or `::1`; any other plain `http://` address stops `dn` with exit code 2 before anything is sent. Stored settings live in `~/.config/decisionnode/config.toml` (`$XDG_CONFIG_HOME` is honoured; `%AppData%\decisionnode` on Windows):

```sh
dn config set model decisionnode-flash
dn config set base_url https://decisions.example.com --profile selfhosted
dn auth login --profile selfhosted
dn config list
```

```toml
model = "decisionnode-flash"

[profiles.selfhosted]
  base_url = "https://decisions.example.com"
```

A profile's settings fall back to the top-level ones. Keys are stored per profile.

`dn` sends no telemetry, checks for no updates and calls nothing but the API, and, for an image upload, the storage address the API returns for it (with only the headers the API signed: never the key).

## Updating

```sh
brew upgrade dn          # Homebrew
scoop update dn          # Scoop
# or run the install script again
```

## License

MIT. Copyright (c) 2026 Bynn Intelligence, Inc.
