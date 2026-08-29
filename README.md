# cb

Yet another tool to wrap reads from, and writes to the OS clipboard -- it works
from within SSH sessions too!

# Backgroud

My life as a developer is a mess: at work I have a laptop with Windows 7 and
Cygwin installed; I also have a Vagrant box, running Ubuntu, that I use to do
the most of my development work.  At home I have a Macbook Air, with Mac OS
Sierra.

You can easily imagine how quickly I got tired of having to remember which of
the various `pbaste`, `getclip` et al. command I should have run depending on
which terminal window I had opened.

Wouldn't it be nice if I could read from the OS clipboard, or write to it,
using a single command line tool? And wouldn't it awesome if the same tool
worked on various operating systems? (at least the ones I use on a daily basis)

_enters `cb`.._

# Installation

Clone the repo, and run `make install`:

    mkdir -p ~/opt/
    cd ~/opt
    git clone https://github.com/iamFIREcracker/cb.git
    cd cb
    PREFIX=~/local/bin make install

# Usage

Writing to the OS clipboard is as simple as piping to `cb` whatever it is that you want
to save to the clipboard:

    > fortune | cb

Reading from the OS clipboard it's even easier:

    > cb
    A little suffering is good for the soul.
                    -- Kirk, "The Corbomite Maneuver", stardate 1514.0

With no flags `cb` guesses what you meant: it pastes when its input is a
terminal, and copies otherwise.  You can be explicit about it with `cb --paste`
(also spelled `cb --force-paste`) and `cb --copy`.

Copying nothing is almost never what you want, so `cb` refuses to overwrite the
clipboard when it reads an empty input, and tells you so on stderr (exiting with
1).  To deliberately empty the clipboard -- say, right after copying a password
-- clear it with `cb </dev/null`, or force the copy with `cb --copy`.

# Advanced usage: remote sessions

Most of the development activities I do at work, I do from a Vagrant box;
finding proper Vim and Tmux configurations that play nice with the OS clipboard
(especially with remote sessions in the mix) has always been painful, so
painful that I decided to ship `cb` with some painkillers for that.

    > cb --listen

This will start a daemon, listening on port 5556 (it's the default, but you can
change it by overriding the `CB_REMOTE_PORT` env variable) for commands to read
from or write to the OS clipboard.  You might wonder: what's so good about it?
Well, you can run it on your host machine (ie. the one with a OS clipboard),
change the ssh commands you use to log into your remote dev boxes to do some
port forwarding magic:

    > ssh -R 5556:localhost:5556 devbox ...

And that's it, running `cb` from the remote host (well, you will have to get
`cb` installed there too..) will get you the content of the host machine OS
clipboard

    > cb
    A little suffering is good for the soul.
                    -- Kirk, "The Corbomite Maneuver", stardate 1514.0

## Using `~/.ssh/config` for per-host clipboard forwarding

Instead of manually specifying port forwarding every time, you can configure it
in your `~/.ssh/config` file. `cb` supports initialization via the
`LC_CB_REMOTE_PORT` environment variable, which SSH typically transfers to the
remote host (most SSH daemons are configured to accept `LC_*` variables by
default; if yours doesn't, check the `AcceptEnv` setting in
`/etc/ssh/sshd_config`).

Here's an example `~/.ssh/config` entry:

    Host devbox
        HostName devbox.example.com
        RemoteForward 5567 localhost:5556
        SetEnv LC_CB_REMOTE_PORT=5567

With this configuration:
- The local machine runs `cb --listen` on port 5556
- SSH forwards the remote's port 5557 to the local port 5556
- The remote `cb` uses port 5557 (via `LC_CB_REMOTE_PORT`)
- Running `cb` on the remote automatically connects to the right port

## OSC52 support (no daemon required)

If your terminal supports OSC52 escape sequences, you can copy to the clipboard
without running a daemon or setting up port forwarding. Just set the `CB_OSC52`
or `LC_CB_OSC52` environment variable:

    Host devbox
        HostName devbox.example.com
        SetEnv LC_CB_OSC52=1

Then on the remote:

    > echo "hello" | cb   # Copies to your local clipboard via OSC52

This works by sending an escape sequence directly to your terminal, which then
updates the clipboard. It works through tmux as well (using DCS passthrough).

**Tmux 3.3+**: You must enable passthrough in your `~/.tmux.conf`:

    set -g allow-passthrough on

**Note**: OSC52 only supports copy operations. Paste still requires the daemon
approach or a local clipboard tool.

**Terminal compatibility**: OSC52 is supported by iTerm2, kitty, alacritty,
foot, WezTerm, Windows Terminal, xterm (with `allowWindowOps`), and others.
Some terminals disable it by default -- check your terminal's documentation.

# Pasting images

Normally `cb` only deals with text. If you set the `CB_IMAGE` (or `LC_CB_IMAGE`)
environment variable, `cb` will also notice when the clipboard holds an *image*,
save it to a temporary file, and print that file's path instead of dumping binary
junk to your terminal:

    > CB_IMAGE=1 cb
    /tmp/cb.image.48213.png

If the clipboard happens to hold both text and an image, you get both -- the text
first, then the image path on its own line:

    > CB_IMAGE=1 cb
    Here is the diagram I mentioned
    /tmp/cb.image.48213.png

This is handy for feeding screenshots straight into tools that take a file path.

How it works, and what you need:

- **macOS** -- no extra tools required (`osascript` is built in); if you have
  [`pngpaste`](https://github.com/jcsalterego/pngpaste) installed it is used
  instead.
- **Linux/X11** -- needs `xclip` (the older `xsel` cannot read images).
- **Linux/Wayland** -- needs `wl-paste` (from `wl-clipboard`).
- **Windows/WSL** -- uses `powershell.exe` (`Get-Clipboard -Format Image`), which
  reads the Windows clipboard directly and saves a PNG. This conveniently
  sidesteps WSLg's habit of exposing clipboard images only as an awkward BMP
  variant that many image readers silently reject.

Image detection is done by inspecting the actual bytes (magic numbers), not by
trusting the clipboard's advertised type. If the extracted image is in an awkward
format (BMP/TIFF) and a converter is available (`sips` on macOS, otherwise
ImageMagick's `magick`/`convert`), `cb` converts it to PNG so the saved file is
something other tools can actually open. If the clipboard turns out *not* to hold
an image, `cb` simply behaves as it always has and prints the text.

## Over SSH

Image pasting works through the daemon too. When you run `cb` on a remote box,
the **host** (the machine with the real clipboard) streams the raw image *bytes*
back, and the **remote** saves them to its own `/tmp` -- so the path `cb` prints
is always local to wherever you ran it. Enable it the same way you enable the
remote port: have the variable travel over SSH via `~/.ssh/config`:

    Host devbox
        HostName devbox.example.com
        RemoteForward 5567 localhost:5556
        SetEnv LC_CB_REMOTE_PORT=5567 LC_CB_IMAGE=1

(Cygwin's `/dev/clipboard` is text-only, so a Cygwin machine cannot *provide* an
image -- but it can still relay text as before.)

**Note -- why SSH image pastes pause for a couple of seconds:** the daemon is
currently one-shot: it handles a single connection, exits, and gets restarted by
a shell loop, so there is a brief window after each request where nothing is
listening on the port. An image paste over SSH makes two back-to-back requests
(text first, then the image), and the second one races that restart. The failure
is silent, too: SSH accepts the forwarded connection immediately, so when the
daemon isn't back up yet the client just sees the channel close with zero bytes
-- indistinguishable from "no image on the clipboard". As a workaround, `cb`
waits 2 seconds between the two requests. The real fix is to make the daemon
bind once and `accept()` in a loop, which removes the gap entirely (and lets
back-to-back requests queue in the listen backlog); until then, expect the
pause.

# Tmux integration

Add the following to your `.tmux.conf`:

    bind -T copy-mode-vi y      send -X copy-pipe-and-cancel "myreattach-to-user-namespace cb"
    bind y run "tmux save-buffer - | myreattach-to-user-namespace cb"

[`myreattach-to-user-namespace`](https://github.com/iamFIREcracker/dotfiles/blob/master/bin/myreattach-to-user-namespace)
is another wrapper I created to try and make sense of all the different OSes
I am dealing with, every day.

# Vim integration

Adding the following to your `.vimrc` will probably do it:

```vimscript
function! g:FuckingCopyTheTextPlease()
    let view = winsaveview()
    let old_z = @z
    normal! gv"zy
    call system('cb', @z)
    let @z = old_z
    call winrestview(view)
endfunction

function! g:FuckingCopyAllTheTextPlease()
    let view = winsaveview()
    let old_z = @z
    normal! ggVG"zy
    call system('cb', @z)
    let @z = old_z
    call winrestview(view)
endfunction

vnoremap <leader>y :<c-u>call g:FuckingCopyTheTextPlease()<cr>
nnoremap <leader>y VV:<c-u>call g:FuckingCopyTheTextPlease()<cr>
nnoremap <leader>Y :<c-u>call g:FuckingCopyAllTheTextPlease()<cr>

nnoremap <leader>p :set paste<CR>:read !cb<CR>:set nopaste<CR><leader>V=
nnoremap <leader>P O<esc>:set paste<CR>:read !cb<CR>:set nopaste<CR>kdd
```

Borrowed from Steve Losh's awesome
[vimrc](https://bitbucket.org/sjl/dotfiles/src/af2b6e2d27f39640970fbf20b8176855c7a489c4/vim/vimrc?at=default&fileviewer=file-view-default#vimrc-323)
-- thanks for all that!

```
Host beast.tailscale.internal
    HostName 192.168.1.2
    # HostName 10.202.191.107
    User matteolandi
    IdentityFile ~/.ssh/id_beast
    RemoteForward 6556 localhost:5556
    RemoteForward 6557 localhost:5557
    RemoteForward 6558 localhost:5558
    SendEnv -LANG -LC_ALL
    # Here we abuse the fact that LC_* envs are sent by default
    SetEnv LC_CB_REMOTE_PORT=6556 LC_BR_REMOTE_PORT=6557 LC_MG_REMOTE_PORT=6558
```
