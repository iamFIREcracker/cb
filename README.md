# cb
Yet another cross-platform clipboard wrapper

# Remote sessions

Start the clipboard daemon:

    cb --listen

And ssh into the remote host setting up a port forwarding first (5556 is the
default port the `cb` listener is going to listen to):

    ssh -R 5556:localhost:5556 ...

Once in, you should be able to read the host clipboard, and write to it as
usual:

    cb           # read the host clipboard
    fortune | cb # write the host clipboard

# Tmux integration

Add the following to your `.tmux.conf`:

    bind -T copy-mode-vi y      send -X copy-pipe-and-cancel "reattach-to-user-namespace cb"
    bind y run "tmux save-buffer - | myreattach-to-user-namespace cb"

# Vim integration

Adding the following to your `.vimrc` will probably do it:

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
