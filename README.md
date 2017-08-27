# cb

Yet another tool to wrap reads from, and writes to the OS clipboard.

# Backgroud 

At work I have a laptop with Windows 7 and Cygwin installed; I also have
a Vagrant box, running Ubuntu, that I use to do the most of my development
work.  At home I have a Macbook Air, with Mac OS Sierra.

You can easily imagine how quickly I got tired of having to remember which of
the various `pbaste`, `getclip` et al. command I should have run depending on
which terminal window I had opened.

Wouldn't it be nice if I could read from the OS clipboard, or write to it,
using a single command line tool? And wouldn't it awesome if the same tool
worked on various operating systems? (at least the ones I use on a daily basis)

_enters `cb`.._

# Usage

Writing to the OS clipboard is as simple as piping to `cb` whatever it is that you want
to save to the clipboard:

    > fortune | cb

Reading from the OS clipboard it's even easier:

    > cb
    A little suffering is good for the soul.
                    -- Kirk, "The Corbomite Maneuver", stardate 1514.0

# Advanced usage: remote sessions

Most of the development activities I do at work, I do from a Vagrant box;
finding proper Vim and Tmux configurations that play nice with the OS clipboard
(especially with remote sessions in the mix) has always been painful, so
painful that I decided to ship `cb` with some painkillers for that.

    > cb --listen

This will start a daemon, listening on port 5556 for commands to read from or
write to the OS clipboard.  You might wonder: what's so good about it?  Well,
you can run it on your host machine (ie. the one with a OS clipboard), change
the ssh commands you use to log into your remote dev boxes to do some port
forwarding magic:

    > ssh -R 5556:localhost:5556 ...

And that's it, running `cb` from the remote host (well, you will have to get
`cb` installed there too..) will get you the content of the OS clipboard:

    > cb
    A little suffering is good for the soul.
                    -- Kirk, "The Corbomite Maneuver", stardate 1514.0

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
