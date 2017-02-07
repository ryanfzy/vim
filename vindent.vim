" author: ryan feng

" check if it is already loaded
if exists("g:loaded_vindent")
    finish
endif
let g:loaded_vindent = 1

if !exists("g:loaded_stdlib")
    echom "ERROR: Vindent requires std.vim"
    finish
endif

" save current vim settings
let s:save_cpo = &cpo
" reset vim settings
set cpo&vim

" restore vim settings
function! s:Restore_cpo()
    let &cpo = s:save_cpo
    unlet s:save_cpo
endfunction

""""""""""""""""""""""""""""""""""""""""
" start of plugin body
""""""""""""""""""""""""""""""""""""""""

let s:dictOptions = {}
let s:dictOptions['indentLevel'] = '10'
"let s:gBlockLine = 10 
"let s:gMaxColumns = 80

highlight vindentColor ctermbg=lightred ctermfg=white

function s:RunVindent()
    let indentLevel = str2nr(s:dictOptions['indentLevel'])
    for i in range(1, indentLevel)
        let syn = 'syntax match vindentColor /\(^\s\{'.i*4.'}\)\@<=\s/'
        "echom syn
        execute syn
    endfor
    "execute 'syntax match vindentColor /^\s\{4}\zs\s/'
    "execute 'syntax match vindentColor /^\s*\%5v\zs\s/'

    "for i in range(1, s:gIndentLevel)
        "let syn = 'syntax match vindentColor /\(^\s\+if.*\n\s\{' . i*4 . '}\)\@<=\s/'
        "echom syn
        "execute syn
    "endfor

    " this create two many matches, slows vim
    "for col in range(1, s:gMaxColumns)
        "let syn = 'syntax match vindentColor /\(^\s\{'.col.'}if.*\n\s\{'.col.'}\)\@<=./'
        "echom syn
    "endfor
    "execute 'syntax match vindentColor /\(^\s\+if.*\n\s\{4}\)\@<=\s/'
    "execute 'syntax match vindentColor /\(^\s\+if.*\n\s\{8}\)\@<=\s/'
    "execute 'syntax match vindentColor /\(\(^\s\+if.*\n\s\{4}\)\@<=.*\n\s\{4}\)\@<=./'
endfunction

function! s:CmdProcessor(args)
    let listCmd = StdParseCmd(a:args)
    if len(listCmd) > 1
        if listCmd[0] =~ 'setOption'
            let dictParams = listCmd[1]
            for key in keys(dictParams)
                if has_key(s:dictOptions, key)
                    let s:dictOptions[key] = dictParams[key]
                endif
            endfor
        endif
    endif
    "echom 'options:'.string(s:dictOptions)
endfunction

""""""""""""""""""""""""""""""""""""""""
" end of plugin body
""""""""""""""""""""""""""""""""""""""""
call s:Restore_cpo()

au BufEnter * call s:RunVindent()

command -narg=+ Vindent :call s:CmdProcessor(<q-args>)

" this is the default option
"Vindent setOption indentLevel=10
