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

highlight vindentColor ctermbg=green ctermfg=white

au BufEnter * syntax match vindentColor /^\s\{4}\zs\s/

""""""""""""""""""""""""""""""""""""""""
" end of plugin body
""""""""""""""""""""""""""""""""""""""""
call s:Restore_cpo()
