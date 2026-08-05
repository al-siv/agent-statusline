# qoder-cli-statusline

A custom status line script for [Qoder CLI](https://docs.qoder.com).
One POSIX shell script, no dependencies beyond `jq` and `git`.

Renders a single compact line:

```
Qwen3.8-Max 400k | ctx 11% | +12/-3 | main | ~/dev/project
```

## Segments

| Segment | Source | Notes |
| --- | --- | --- |
| Model | `model.display_name` | Followed by the context window limit in compact form (`4k`, `400k`, `1M`). |
| ctx | `context_window.used_percentage` | Percentage of the context window currently used. Green up to 50%, yellow up to 80%, red above. Falls back to `100 - remaining_percentage`. |
| +N/-M | `git diff` | Working tree changes, including untracked files. Hidden when clean. |
| Branch | `git` | Cyan on `main`, bright magenta on any other branch, bold red `NO GIT!` outside a repository. |
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
current workspace, and prints one ANSI-colored line to stdout.

## License

[MIT](LICENSE)
