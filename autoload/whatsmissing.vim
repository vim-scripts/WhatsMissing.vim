" WhatMissing.vim - Shows what is missing between 2 buffers
" ---------------------------------------------------------------
" Version:  4.0
" Authors:  David Fishburn <dfishburn dot vim at gmail dot com>
" Last Modified: 2012 Oct 10
" Homepage: http://vim.sourceforge.net/script.php?script_id=1108
" GetLatestVimScripts: 1108 1 :AutoInstall: WhatsMissing.vim

if exists('g:loaded_whatsmissing_auto')
    finish
endif
let g:loaded_whatsmissing_auto = 40

" Turn on support for line continuations when creating the script
let s:cpo_save = &cpo
set cpo&vim

let s:wm_buffer_lines      = 10
let s:wm_matching_cnt      = 0
let s:wm_checked_cnt       = 0
let s:wm_org_bufnr         = 0
let s:wm_missing_bufnr     = 0
let s:wm_debug             = 0
let s:wm_find_bufnr        = 0
let s:wm_find_mode         = 'word'
let s:wm_find_filetype     = ''
let s:wm_filename          = ''
let s:wm_ignore_case       = ''
let s:wm_ignore_whitespace = ''
let s:wm_unescaped_findstr = ''
let s:wm_missing_buf_name  = "WhatsMissing"
let s:wm_options           = "mode,ignore_case,ignore_whitespace,debug"
let s:wm_modes             = "word,line"

function! whatsmissing#WM_GetOption(option)
    if s:wm_options !~? '\<'.a:option.'\>'
        call s:WM_WarningMsg(
                    \ "Invalid option, choices are: " .
                    \ s:wm_options
                    \ )
        return -1
    endif

    if a:option == 'mode'
        let value = a:option.'='.s:wm_find_mode
    elseif a:option == 'ignore_case'
        let value = a:option.'='.
                    \ (s:wm_ignore_case ==# '' ? ' ' : 
                    \ (s:wm_ignore_case ==# '\c' ? '1' : '0' ) )
    elseif a:option == 'ignore_whitespace'
        let value = a:option.'='.(s:wm_ignore_whitespace ==# '' ? '0' : '1' )
    elseif a:option == 'debug'
        let value = a:option.'='.s:wm_debug
    else
        let value = 'Unknown option: a:option'
    endif

    return value
endfunction

function! whatsmissing#WM_SetOption(option)
    let opt_name  = matchstr(a:option, '^.\{-}\ze=' )
    let opt_value = matchstr(a:option, '=\zs.\{-}\s*$' )
    
    if s:wm_options !~? '\<'.opt_name.'\>'
        call s:WM_WarningMsg(
                    \ "Invalid option, choices are: " .
                    \ s:wm_options
                    \ )
        return -1
    endif

    if opt_name == 'mode'
        if s:wm_modes !~? '\<'.opt_value.'\>'
            call s:WM_WarningMsg(
                        \ "Invalid mode, choices are: " .
                        \ s:wm_modes
                        \ )
            return -1
        else
            let s:wm_find_mode = opt_value
        endif
    elseif opt_name == 'ignore_case'
        let s:wm_ignore_case = (opt_value ==# '1' ? '\c' : '\C' )
    elseif opt_name == 'ignore_whitespace'
        let s:wm_ignore_whitespace = (opt_value ==# '1' ? '\s*' : '' )
    elseif opt_name == 'debug'
        let s:wm_debug = opt_value
    endif
    
    return 1
endfunction

function! whatsmissing#WhatsNotMissing(...) range
    let compareTo = '""'
    if a:0 > 0
        let compareTo = a:1
    endif

    let askPrompt = '"1"'
    if a:0 > 2
        let askPrompt = a:3
    endif

    exec a:firstline.','.a:lastline.'WhatsMissing '.compareTo.' 0 '.askPrompt
endfunction

function! whatsmissing#WhatsMissing(...) range
    if &hidden == 0
        call s:WM_WarningMsg(
                    \ "Cannot search other buffers with :set nohidden"
                    \ )
        return -1
    endif

    let s:wm_org_bufnr = bufnr("%")
    let rc = -1

    let compareTo = ""
    if a:0 > 0
        let compareTo = a:1
    endif

    if strlen(substitute(compareTo, '"' ,'', 'g')) == 0
        let response = confirm("SOURCE: Current buffer contains a list of words" .
                    \ " or lines to check if they exist in the TARGET.\nThe " .
                    \ " target is typically a real file (i.e. Vim syntax file)"
                    \ )
        let response = 1
        if has("browse")
            let response = confirm("TARGET: Do you want to specify a file/buffer" .
                        \ " or browse for the file?", 
                        \ "&File/Buffer\n&Browse",
                        \ 1
                        \ )
        endif

        if response == 1
            let msg = "TARGET: Enter one of the following:" .
                        \ "\n- buffer #" .
                        \ "\n- buffer name" .
                        \ "\n- filename (absolute|relative)\n"
            let compareTo = inputdialog(msg)

            if strlen(substitute(compareTo, '"' ,'', 'g')) == 0
                call s:WM_WarningMsg(
                            \ "Invalid entry"
                            \ )
                return -1
            endif
        
        elseif response == 2
            if has("browse")
                let compareTo = browse(0,"WhatsMissing Compare To", "", "")
            endif
        endif
    endif

    let compareTo = substitute(compareTo, '^\s*\(.\{-}\)\s*$', '\1', '')
    if match(compareTo, '\D') == -1
        let rc = s:WM_SetBufNbr( compareTo )
    else
        let rc = s:WM_SetFileName( compareTo )
    endif
        
    if rc == -1
        return -1
    endif

    call s:WM_GetFindBufferOptions()

    if a:0 > 1
        let check_for_missing = a:2
    else 
        let check_for_missing = 1
    endif

    let ask_prompt = 1
    if a:0 > 2
        if a:3 == '0'
            let ask_prompt = 0
        endif
    endif

    if ask_prompt == 1
        call s:WM_PromptOptions()
    endif

    " Prevent the alternate buffer (<C-^>) from being set to this
    " temporary file
    let l:old_cpoptions = &cpoptions
    setlocal cpo-=a
    setlocal cpo-=A
    let saveReg = @"
    " save previous search string
    let saveSearch = @/
    let saveZ      = @z

    " Disable all autocommands and events since we will be
    " flipping between 3 buffers in rapid succession.
    " If these events are not disabled, this can take
    " a very long time
    let l:old_eventignore = &eventignore
    set eventignore+=BufNewFile,BufReadPre,BufRead,BufReadPost,BufReadCmd
    set eventignore+=BufFilePre,BufFilePost,FileReadPre,FileReadPost
    set eventignore+=FileReadCmd,FilterReadPre,FilterReadPost,FileType,Syntax
    set eventignore+=StdinReadPre,StdinReadPost,BufWrite,BufWritePre
    set eventignore+=BufWritePost,BufWriteCmd,FileWritePre,FileWritePost
    set eventignore+=FileWriteCmd,FileAppendPre,FileAppendPost,FileAppendCmd
    set eventignore+=FilterWritePre,FilterWritePost,FileChangedShell
    set eventignore+=FileChangedRO,FocusGained,FocusLost,FuncUndefined
    set eventignore+=CursorHold,BufEnter,BufLeave,BufWinEnter,BufWinLeave
    set eventignore+=BufUnload,BufHidden,BufNew,BufAdd,BufCreate,BufDelete
    set eventignore+=BufWipeout,WinEnter,WinLeave,CmdwinEnter,CmdwinLeave
    set eventignore+=GUIEnter,VimEnter,VimLeavePre,VimLeave,EncodingChanged
    set eventignore+=FileEncoding,RemoteReply,TermChanged,TermResponse,User
    " New to WhatsMissing 4.0
    set eventignore+=ColorScheme,CursorHoldI,CursorMoved,CursorMovedI
    set eventignore+=FileChangedShellPost,GUIFailed,InsertChange,InsertCharPre
    set eventignore+=InsertEnter,InsertLeave,MenuPopup,QuickFixCmdPre,QuickFixCmdPost
    set eventignore+=SessionLoadPost,ShellCmdPost,ShellFilterPost,SourcePre
    set eventignore+=SourceCmd,SpellFileMissing,SwapExists,TabEnter,TabLeave
    set eventignore+=VimResized

    let title = '(!matching! of !checked!) items '
    if check_for_missing == 1 
        let s:wm_missing_buf_name = "WhatsMissing"
        let title = title . 'missing from: '
    else
        let s:wm_missing_buf_name = "WhatsNotMissing"
        let title = title . 'found in both buffers: '
    endif
    let title = title . bufname(s:wm_find_bufnr) .
                \ "\n----------" 

    call s:WM_AddToResultBuffer( title, "clear" )

    " Put an extra newline at the start of the file
    " It will be removed (undo) at the end of this, but
    " this allows us to move through the file more consistently
    " without having to deal with boundary cases
    call cursor(a:firstline,1)
    put! ='' 

    let s:wm_matching_cnt     = 0
    let s:wm_checked_cnt      = 0
    let findstr               = ''
    while (1==1)
        let org_curline = line(".")
        let org_curcol  = col(".")
        let org_strlen  = strlen(s:wm_unescaped_findstr)
        
        let findstr = s:WM_GetNextFindStr(a:firstline)

        " normal! w

        if s:wm_find_mode == 'word'
            " Check to see if we are on a character
            " Since a user can specify a range, abort when we have passed it
            " When hitting w (at the end of the file) the cursor
            " will simply move to the end of the word, so we must
            " check to ensure we have moved off of the previous word.
            if (line(".") > (a:lastline+1)) ||
                        \ (line(".") == org_curline && 
                        \   col(".") < (org_curcol+org_strlen) )
                " We have reached the end of the file
                break
            endif
        elseif s:wm_find_mode == 'line'
            " In line mode, just check if we are on the last
            " line of the file
            if (line(".") > (a:lastline+1)) ||
                        \ (org_curline == (a:lastline+1))
                " We have reached the end of the file
                break
            endif
        endif
        
        if strlen(findstr) > 0
            let s:wm_checked_cnt = s:wm_checked_cnt + 1

            " Switch to the buffer we want to check this string for
            silent! exec "buffer " . s:wm_find_bufnr

            " ignore case
            let srch_str = s:wm_ignore_case
            if s:wm_find_mode == 'word'
                if findstr =~? '^\w'
                    let srch_str = srch_str . '\<'
                endif
                let srch_str = srch_str . findstr
                if findstr =~? '\w$'
                    let srch_str = srch_str . '\>'
                endif
            else
                let srch_str = srch_str . '^' . 
                            \ s:wm_ignore_whitespace .
                            \ findstr . 
                            \ s:wm_ignore_whitespace .
                            \ '$'
            endif

            " Decho strftime("%X").' '.srch_str

            " Mark the current line to return to
            let find_curline     = line(".")
            let find_curcol      = col(".")

            if s:wm_debug == 1
                call s:WM_AddToResultBuffer( 'Finding: [' .
                            \ srch_str . ']', "" )
            endif
            let found_line = search( srch_str, "w" )

            if check_for_missing == 1 && found_line == 0
                let s:wm_matching_cnt = s:wm_matching_cnt + 1
                call s:WM_AddToResultBuffer( s:wm_unescaped_findstr, "" )
            elseif check_for_missing == 0 && found_line > 0
                let s:wm_matching_cnt = s:wm_matching_cnt + 1
                call s:WM_AddToResultBuffer( s:wm_unescaped_findstr, "" )
            endif

            " Switch back to the original buffer
            silent! exec "buffer " . s:wm_org_bufnr

            " Return to previous location
            " call cursor(org_curline, org_curcol)

        endif

    endwhile

    silent! exec "buffer " . s:wm_org_bufnr
    " Undo the put = we did above
    undo

    silent! exe 'noh'

    " Restore previous cpoptions
    let &cpoptions   = l:old_cpoptions
    let &eventignore = l:old_eventignore
    let @" = saveReg
    " restore previous search
    let @/ = saveSearch
    let @z = saveZ

    call s:WM_SetSummary()
    if s:wm_debug == 1
        call s:WM_AddToResultBuffer( 'Start: ' .
                    \ a:firstline .
                    \ '  End: ' .
                    \ a:lastline, 
                    \ "" )
    endif

    " call s:WM_AddToResultBuffer( "EI:".&eventignore, "" )
endfunction

function! s:WM_SetBufNbr( bufnr )
    if match(a:bufnr, '\d') == -1
        call s:WM_WarningMsg(
                    \ "WM_SetBufNbr must use numeric parameter: " . a:bufnr
                    \ )
        return -1 
    endif

    if a:bufnr == s:wm_org_bufnr
        call s:WM_WarningMsg(
                    \ "Cannot choose the same buffer: " . a:bufnr
                    \ )
        return -1 
    endif

    if !bufexists(a:bufnr+0)
        call s:WM_WarningMsg(
                    \ "Cannot find buffer #: " . a:bufnr
                    \ )
        return -1 
    endif

    let s:wm_find_bufnr = a:bufnr

    return 1
endfunction

function! s:WM_SetFileName( filename )
    let filename = expand(a:filename)
    if !bufexists(bufnr(filename))
        if filereadable(filename)
            " load the file into a new buffer
            exec 'view ' .  filename
            if bufexists(bufnr(filename))
                let s:wm_find_bufnr = bufnr(filename)
            else
                call s:WM_WarningMsg(
                            \ "Failed to load: " . filename
                            \ )
                return -1
            endif
        else
            call s:WM_WarningMsg(
                        \ "Cannot find: " . filename
                        \ )
            return -1
        endif
    else
        let s:wm_find_bufnr = bufnr(filename)
    endif
    let s:wm_filename = filename

    return 1
endfunction

function! s:WM_AddToResultBuffer(output, do_clear)
    " store current window number so we can return to it
    let cur_winnr = winnr()

    " do not use bufexists(s:wm_missing_buf_name), since it uses a fully
    " qualified path name to search for the buffer, which in effect opens
    " multiple buffers called "result" if the files that you are executing the
    " commands from are in different directories.
    let s:wm_missing_bufnr = bufnr(s:wm_missing_buf_name)

    if s:wm_missing_bufnr == -1
        " create the new buffer
        silent exec 'belowright ' . s:wm_buffer_lines . 'new ' . s:wm_missing_buf_name
        let s:wm_missing_bufnr = bufnr("%")
    else
        if bufwinnr(s:wm_missing_bufnr) == -1
            " if the buffer is not visible, wipe it out and recreate it,
            " this will position us in the new buffer
            exec 'bwipeout! ' . s:wm_missing_bufnr
            silent exec 'bot ' . s:wm_buffer_lines . 'new ' . s:wm_missing_buf_name
        else
          " if the buffer is visible, switch to it
          exec bufwinnr(s:wm_missing_bufnr) . "wincmd w"
        endif
    endif
    setlocal modified
    " create a buffer mapping to clo this window
    nnoremap <buffer> q :clo<cr>
    " delete all the lines prior to this run
    if a:do_clear == "clear" 
        %d
    endif

    if strlen(a:output) > 0
        " add to end of buffer
        silent! exec "$put =a:output"
    endif

    " since this is a small window, remove any blanks lines
    silent %g/^\s*$/d
    " fix the ^m characters, if any
    silent execute "%s/\<c-m>\\+$//e"
    " dont allow modifications, and do not wrap the text, since
    " the data may be lined up for columns
    setlocal nomodified
    setlocal nowrap
    " go to top of output
    norm gg
    " return to original window
    exec cur_winnr."wincmd w"

    return
endfunction 

function! s:WM_GetNextFindStr(startline)
    if s:wm_find_mode == 'word'
        normal! wyiw
        let s:wm_unescaped_findstr = @"
    elseif s:wm_find_mode == 'line'
        normal! j
        let s:wm_unescaped_findstr = getline(".")
    endif

    " Escape various special characters
    let findstr = escape(s:wm_unescaped_findstr, '\\/.*$^~[]' )
    let findstr = substitute(
                \ substitute(findstr, "\n$", "", ""),
                \ "\n", '\\_[[:return:]]', "g")
    return findstr
endfunction

function! s:WM_GetFindBufferOptions()
    silent! exec "buffer " . s:wm_find_bufnr
    let s:wm_find_filetype = &filetype
    silent! exec "buffer " . s:wm_org_bufnr
endfunction

function! s:WM_PromptOptions()
    " Mode
    let response = (s:wm_find_mode == 'word' ? '1' : '2' ) 
    let response = confirm("Choose compare method:",
                \ "&Word\n&Line",
                \ response
                \ )
    let s:wm_find_mode = (response == '1' ? 'word' : 'line' )
    
    " Ignore Case
    let response = (s:wm_ignore_case ==# '' ? '1' : 
                \ (s:wm_ignore_case ==# '\c' ? '3' : '2' ) )
    let response = confirm("Do you want to ignore case?",
                \ "&Default\n&Yes\n&No",
                \ response
                \ )
    let s:wm_ignore_case = (response ==# '1' ? '' : 
                \ (response ==# '2' ? '\c' : '\C' ) )
    
    " Ignore whitespace
    let response = (s:wm_ignore_whitespace == '' ? '1' : '2' )
    let response = confirm("Do you want to ignore whitespace?",
                \ "&No\n&Yes",
                \ response
                \ )
    let s:wm_ignore_whitespace = (response ==# '1' ? '' : '\s*' )
endfunction

function! s:WM_SetSummary()
    let WMOptions = "----------\nWMOptions:\n" .
                \ whatsmissing#WM_GetOption('mode').' '.
                \ whatsmissing#WM_GetOption('ignore_case').' '.
                \ whatsmissing#WM_GetOption('ignore_whitespace')
    call s:WM_AddToResultBuffer(WMOptions, '')

    silent! exec "buffer " . s:wm_missing_bufnr
    call cursor(1,1)
    exec 's/!matching!/'.s:wm_matching_cnt.'/e'
    exec 's/!checked!/'.s:wm_checked_cnt.'/e'
    let &filetype = s:wm_find_filetype
    setlocal nomodified
    silent! exec "buffer " . s:wm_org_bufnr
endfunction

function! whatsmissing#WM_CompleteOption(ArgLead, CmdLine, CursorPos)

    if a:ArgLead =~? '^mode='
        let cmd_options = a:ArgLead .
                    \ substitute(s:wm_modes, ',', "\n".a:ArgLead, 'g')
    elseif a:ArgLead =~? '='
        let cmd_options = a:ArgLead . "0\n" .
                    \ a:ArgLead . "1"
    else
        let cmd_options = substitute(s:wm_options, ',', "\n", 'g')
    endif

    return cmd_options
endfunction

function! s:WM_WarningMsg(msg) 
    echohl WarningMsg
    echomsg "WM: " . a:msg
    echohl None
endfunction 

let &cpo = s:cpo_save
unlet s:cpo_save

" vim:fdm=marker:nowrap:ts=4:expandtab:
