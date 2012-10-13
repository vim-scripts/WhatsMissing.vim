" WhatMissing.vim - Shows what is missing between 2 buffers
" ---------------------------------------------------------------
" Version:  4.0
" Authors:  David Fishburn <dfishburn dot vim at gmail dot com>
" Last Modified: 2012 Oct 10
" Homepage: http://vim.sourceforge.net/script.php?script_id=1108
" GetLatestVimScripts: 1108 1 :AutoInstall: WhatsMissing.vim

if exists('g:loaded_whatsmissing')
    finish
endif
let g:loaded_whatsmissing = 40

" Turn on support for line continuations when creating the script
let s:cpo_save = &cpo
set cpo&vim

command! -range=% -nargs=* WhatsMissing    <line1>,<line2>call whatsmissing#WhatsMissing(<f-args>)
command! -range=% -nargs=* WhatsNotMissing <line1>,<line2>call whatsmissing#WhatsNotMissing(<f-args>)
command! -nargs=1 -complete=custom,whatsmissing#WM_CompleteOption WMGetOption :echo whatsmissing#WM_GetOption(<q-args>)
command! -nargs=1 -complete=custom,whatsmissing#WM_CompleteOption WMSetOption :call whatsmissing#WM_SetOption(<q-args>)

if has("gui_running") && has("menu")
    vnoremenu <script> Plugin.WhatsMissing.WhatsMissing :WhatsMissing<cr>
    nnoremenu <script> Plugin.WhatsMissing.WhatsMissing :WhatsMissing<cr>
    vnoremenu <script> Plugin.WhatsMissing.WhatsNotMissing :WhatsNotMissing<cr>
    nnoremenu <script> Plugin.WhatsMissing.WhatsNotMissing :WhatsNotMissing<cr>
endif

let &cpo = s:cpo_save
unlet s:cpo_save

" vim:fdm=marker:nowrap:ts=4:expandtab:
