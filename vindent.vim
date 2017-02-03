"vindent start=if end=endif

" author: ryan feng

" check if it is already loaded
if exists("g:loaded_vindent")
    finish
endif
let g:loaded_vindent = 1

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
"highlight vindentColor ctermbg=lightgreen

highlight vindentColor ctermbg=lightred ctermfg=white
highlight vindentColor2 ctermbg=red ctermfg=white

function s:RunVindent()
    for i in range(1, 10)
        let syn = 'syntax match vindentColor /\(^\s\{'.i*4.'}\)\@<=\(\s\|{\|}\)/'
        "echom syn
        execute syn
    endfor
    "execute 'syntax match vindentColor /^\s\{4}\zs\s/'
    "execute 'syntax match vindentColor /^\s*\%5v\zs\s/'
    "execute 'syntax match vindentColor /\(^\s\+if.*\n\s\{4}\)\@<=\s/'
    "execute 'syntax match vindentColor /\(^\s\+if.*\n\s\{8}\)\@<=\s/'
    "execute 'syntax match vindentColor /\(\(^\s\+if.*\n\s\{4}\)\@<=.*\n\s\{4}\)\@<=./'
endfunction

au BufEnter * call s:RunVindent()

""""""""""""""""""""""""""""""""""""""""
" end of plugin body
""""""""""""""""""""""""""""""""""""""""
call s:Restore_cpo()
