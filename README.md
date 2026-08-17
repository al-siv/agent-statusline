# qoder-cli-statusline

A custom status line script for [Qoder CLI](https://docs.qoder.com).
One POSIX shell script, no dependencies beyond `jq` and `git`.

Renders a single compact line:

```
❯ Qwen3.8-Max 400k | ctx 11% | AG 2 | +12/-3 | main | ~/dev/project
```

## Segments

| Segment | Source | Notes |
| --- | --- | --- |
| `❯` | — | Light-gray left-edge marker (chevron), keeps the model name off the terminal edge. |
| Model | `model.display_name` | Followed by the context window limit in compact form (`4k`, `400k`, `1M`). |
| ctx | `context_window.used_percentage` | Percentage of the context window currently used. Green up to 50%, yellow up to 80%, red above. Falls back to `100 - remaining_percentage`. |
| AG N | session transcript + subagent registry | Live subagent count: the max of Agent tool calls without a result yet, and non-terminal `subagents/task-*.json` entries (background agents are only visible there). Shown only while > 0. |
| +N/-M | `git diff` | Working tree changes, including untracked files. Hidden when clean. |
| Branch | `git` | Cyan on `main`, bright magenta on any other branch, yellow `no commits` in a commit-less repo, bold red `NO GIT!` outside a repository. |
| Path | `workspace.current_dir` | `$HOME` shortened to `~`. |

Segments are skipped gracefully when the underlying data is absent.

## Requirements

- Qoder CLI
- `jq`
- `git` (optional, for branch and diff segments)

## Installation

Copy the script and point Qoder CLI at it:

```sh
mkdir -p ~/.qoder
cp statusline-command.sh ~/.qoder/statusline-command.sh
chmod +x ~/.qoder/statusline-command.sh
```

Add to `~/.qoder/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.qoder/statusline-command.sh"
  }
}
```

The status line updates automatically on the next CLI refresh.

## How it works

Qoder CLI pipes a session JSON object to the command's stdin. The script
extracts the fields with a single `jq` invocation, gathers git stats for the
current workspace, scans the session transcript (with an incremental cache)
and the subagent registry for live agents, and prints one ANSI-colored line
to stdout.

## Harness

The repo is the source of truth for the script; the runtime copy
(`~/.qoder-cn/statusline-command.sh`) is kept in sync by `./sync.sh`
(`status` / `push` / `pull --confirmed statusline`). Changes follow a
contract-first cycle: the permanent component contract and its journal live
in [`contracts/statusline.md`](contracts/statusline.md) and
[`contracts/statusline-journal.md`](contracts/statusline-journal.md) (rules
and index: [`contracts/AGENTS.md`](contracts/AGENTS.md)); research lives in
`analysis/`. A pre-push hook (`.hooks/`, activate with
`git config core.hooksPath .hooks`) blocks pushes on repo↔runtime drift or
contract/index violations. The
harness itself is an adaptation of the `~/dev/qoder-skills` harness, kept
aligned by a hash pin and a periodic check (`./harness-check.sh`). Policy:
[`AGENTS.md`](AGENTS.md).

## License

[MIT](LICENSE)
