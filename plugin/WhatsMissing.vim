" WhatMissing.vim - Shows what is missing between 2 buffers
" ---------------------------------------------------------------
" Version:  5.0
" Authors:  David Fishburn <dfishburn dot vim at gmail dot com>
" Last Modified: 2012 Oct 17
" Homepage: http://vim.sourceforge.net/script.php?script_id=1108
" GetLatestVimScripts: 1108 1 :AutoInstall: WhatsMissing.vim

if exists('g:loaded_whatsmissing')
    finish
endif
let g:loaded_whatsmissing = 50

if !exists('g:wm_default_menu_mode')
    let g:wm_default_menu_mode = 3
endif

" Turn on support for line continuations when creating the script
let s:cpo_save = &cpo
set cpo&vim

command! -range=% -nargs=* -complete=file WhatsMissing    <line1>,<line2>call whatsmissing#WhatsMissing(<f-args>)
command! -range=% -nargs=* -complete=file WhatsNotMissing <line1>,<line2>call whatsmissing#WhatsNotMissing(<f-args>)
command! -nargs=*  WhatsNotMissingRemoveMatches call whatsmissing#WhatsNotMissingRemoveMatches()
command! -nargs=1 -complete=custom,whatsmissing#WM_CompleteOption WMGetOption :echo whatsmissing#WM_GetOption(<q-args>)
command! -nargs=1 -complete=custom,whatsmissing#WM_CompleteOption WMSetOption :call whatsmissing#WM_SetOption(<q-args>)

if has("gui_running") && has("menu") && g:wm_default_menu_mode != 0
    if g:wm_default_menu_mode == 1
        let menuRoot = 'WhatsMissing'
    elseif g:wm_default_menu_mode == 2
        let menuRoot = '&WhatsMissing'
    else
        let menuRoot = '&Plugin.&WhatsMissing'
    endif

    exec 'noremenu  <script> '.menuRoot.'.Whats\ Missing :WhatsMissing<CR>'
    exec 'noremenu  <script> '.menuRoot.'.Whats\ Not\ Missing :WhatsNotMissing<CR>'
    exec 'vnoremenu <script> '.menuRoot.'.Whats\ Missing\ (Visual\ selection) :WhatsMissing<CR>'
    exec 'vnoremenu <script> '.menuRoot.'.Whats\ Not\ Missing\ (Visual\ selection) :WhatsNotMissing<CR>'
    exec 'noremenu  <script> '.menuRoot.'.Remove\ Matches :WhatsNotMissingRemoveMatches<CR>'
endif

let &cpo = s:cpo_save
unlet s:cpo_save

" vim:fdm=marker:nowrap:ts=4:expandtab:
