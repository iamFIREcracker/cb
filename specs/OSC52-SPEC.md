# OSC52 Support Specification

## Overview

Add OSC52 escape sequence support to `cb` for clipboard copy operations over SSH without requiring the daemon or port forwarding setup.

## Environment Variables

```bash
CB_OSC52=${CB_OSC52:-${LC_CB_OSC52:-}}
```

- `CB_OSC52` — Primary variable
- `LC_CB_OSC52` — SSH-passthrough variant (for `SetEnv` in SSH config)
- **Activation**: Any truthy value (e.g., `CB_OSC52=1`, `CB_OSC52=yes`)
- **Disabled**: Unset or empty

## Scope

| Operation | OSC52 Used? |
|-----------|-------------|
| Copy      | Yes, when `CB_OSC52` is truthy |
| Paste     | No, uses existing backends (daemon, pbpaste, xsel, etc.) |

OSC52 paste (clipboard query) is unreliable across terminals and is not implemented.

## Implementation

### New Function: `osc52_copy()`

```bash
osc52_copy() {
    data=$(base64 | tr -d '\n')
    if [ -n "$TMUX" ]; then
        # DCS passthrough for tmux
        printf '\033Ptmux;\033\033]52;c;%s\a\033\\' "$data" > /dev/tty
    else
        printf '\033]52;c;%s\a' "$data" > /dev/tty
    fi
}
```

### Modified `copy()` Function

```bash
copy() {
    if [ -n "${CB_OSC52:-${LC_CB_OSC52:-}}" ]; then
        osc52_copy
    elif env | grep --quiet -F SSH_TTY; then
        remote
    elif [ -e /dev/clipboard ]; then
        cat > /dev/clipboard
    elif hash clip.exe 2>/dev/null; then
        clip.exe
    elif hash xsel 2>/dev/null; then
        xsel --clipboard --input
    else
        pbcopy
    fi
}
```

## Behavior

- **Silent**: No output on success (matches `pbcopy` behavior)
- **No size limits**: Data is sent as-is; terminal handles any limits
- **No success verification**: OSC52 cannot confirm the terminal accepted the data

## Tmux Support

When `$TMUX` is set, wrap OSC52 in DCS passthrough sequence to reach the outer terminal:

```
\033Ptmux;\033<OSC52 sequence>\033\\
```

This allows clipboard to work through tmux to the host terminal.

## Not Supported

- **GNU Screen**: No DCS passthrough handling (keep simple, tmux only)
- **Paste via OSC52**: Query sequence `\033]52;c;?\a` is not implemented

## Usage Examples

### SSH Config (Recommended)

```
Host devbox
    HostName devbox.example.com
    SetEnv LC_CB_OSC52=1
```

Then on the remote host:
```bash
echo "hello" | cb   # Uses OSC52, copies to local clipboard
```

### Manual Enable

```bash
export CB_OSC52=1
fortune | cb
```

### One-off

```bash
CB_OSC52=1 fortune | cb
```

## Terminal Compatibility

OSC52 is supported by: iTerm2, kitty, alacritty, foot, WezTerm, Windows Terminal, xterm (with `allowWindowOps`), st, and others.

**Note**: Some terminals disable OSC52 by default or limit it to local sessions. Consult your terminal's documentation.
