" author: ryan feng


" check if it is already loaded
if exists("g:loaded_pmatch")
    finish
endif
let g:loaded_pmatch = 1

" this plugin depends on std.vim
if !exists("g:loaded_stdlib")
    echom "ERROR: Pmatch depends on std.vim"
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

""""""""""""""""""""""""""""""""""""""""""
" plugin body
""""""""""""""""""""""""""""""""""""""""""

let s:gNumOfParns = 0
highlight link myMatch Error
let s:gOldSyn = {}

" this translate string to a list of numbers, ( to 0 and ) to 1
" ( => [0]
" ) => [1]
" () => [0,1]
" )( => [1,0]
function! s:StrToListParns(line)
    let listParns = []
    let bEscaped = g:FALSE
    let bFoundString = g:FALSE
    for i in range(len(a:line))
       let ch = a:line[i] 
       if !bFoundString
           if ch =~ '"' || ch =~ "'"
               let bFoundString = g:TRUE
           elseif ch =~ '('
               let listParns = add(listParns, 0)
           elseif ch =~ ')'
               let listParns = add(listParns, 1)
           endif
       " ignore parns in strings (text between " and ")
       else
           " ignore any character after \ including "
           if ch =~ '\'
               let bEscaped = g:TRUE
           elseif ch =~ '"' || ch =~ "'"
               if bEscaped
                   let bEscaped = g:FALSE
               else
                   let bFoundString = g:FALSE
               endif
           endif
       endif
    endfor
    return listParns
endfunction

" this translates list of parns to list of list parns
" [0,1] => [2]
" [0,0,1] => [0,2]
" [0,1,1] => [2,1]
" [0,0,1,1] => [[2]]
function! s:ListParnsToListOfListParns(listParns)
    let listPatParns = []
    for i in range(len(a:listParns))
        let iParn = a:listParns[i]
        if iParn == 0
            let listPatParns = add(listPatParns, 0)
        elseif iParn == 1
            let lenPatParns = len(listPatParns)

            " in case there is no left-parn but we found a right-parn
            if lenPatParns < 1
                let listPatParns = add(listPatParns, 1)

            " trying to find the corresponding left-parn
            else
                let idx = -1
                for j in range(lenPatParns-1, 0, -1)
                    if type(listPatParns[j]) != type([]) && listPatParns[j] == 0
                        let l:idx = j
                        break
                    endif
                endfor
                " in case the left-parn is left-next to it
                if idx == lenPatParns-1
                    let listPatParns[lenPatParns-1] = 2
                " in case there is no corresponding left-parn
                elseif idx == -1
                    let listPatParns = add(listPatParns, 1)
                " found the left-parn so add it to the list
                " TODO: this code could be refactored`
                else
                    let lst = []
                    for k in range(idx)
                        let lst = add(lst, listPatParns[k])
                    endfor
                    let lst2 = []
                    for m in range(idx+1, lenPatParns-1)
                        let lst2 = add(lst2, listPatParns[m])
                    endfor
                    let listPatParns = add(lst, lst2)
                endif
            endif
        endif
    endfor
    return listPatParns
endfunction

" this translate a string to a list of list of parns
"   ( => [0]
"   ) => [1]
"   () => [2]
"   (() => [0,2]
"   ()) => [2,1]
"   (()() => [0,2,2]
"   ()()) => [2,2,1]
"   ((()()) => [0,[2,2]]
"   (()())) => [[2,2],1]
"   ((( => [0,0,0]
"   ))) => [1,1,1]
"   (()((()) => [0,2,0,[2]]
function! s:GetPatParns(line)
    let listParns = s:StrToListParns(a:line)
    let listPatParns = s:ListParnsToListOfListParns(listParns)
    return listPatParns
endfunction

function! s:GetSubListForOne(list, idx)
    if a:idx > len(a:list)-1
        return []
    endif
    let listRet = [a:list[a:idx]]
    if a:idx < 1
        return listRet
    endif
    for i in range(a:idx-1, 0, -1)
        "if type(a:list[i]) != type([]) && a:list[i] == 1
            "break
        "else
            let listRet = add(listRet, a:list[i])
        "endif
    endfor
    return reverse(listRet)
endfunction

" get a list that we need to translate to regex
" [0,2,0,[2]] => [[0,2,0,[2]], [0,[2]]]
" [1,2,1,[2]] => [[1], [2,1]]
" [1,2,0,[2]] => [[1], [0,[2]]
function! s:GetListOfListPatParns(listPatParns)
    let l:listOfListPatParns = []
    if len(a:listPatParns) > 0
        for i in range(len(a:listPatParns))
            if type(a:listPatParns[i]) != type([])
                if a:listPatParns[i] == 0
                    let l:listOfListPatParns = add(l:listOfListPatParns, GetSubList(a:listPatParns, i))
                elseif a:listPatParns[i] == 1
                    let l:listOfListPatParns = add(l:listOfListPatParns, s:GetSubListForOne(a:listPatParns, i))
                endif
            endif
        endfor
    endif
    return l:listOfListPatParns
endfunction

function! s:GetPatParnsForSyn(listPatParns)
    "echom 'getpatparnsforsyn:'.string(a:listPatParns)
    if len(a:listPatParns) == 0
        return ''
    endif

    let l:listPats = []
    let l:patZero = '([^()]*'
    let l:patOne = ')'
    let l:patTwo = '([^()]*)'
    let l:patList = '([^()]*%s[^()]*)'
    for i in range(len(a:listPatParns))
        if type(a:listPatParns[i]) == type([])
            let l:pat = printf(l:patList, s:GetPatParnsForSyn(a:listPatParns[i]))
            let l:listPats = add(l:listPats, l:pat)
        elseif a:listPatParns[i] == 2
            let l:listPats = add(l:listPats, l:patTwo)
        elseif a:listPatParns[i] == 0
            let l:listPats = add(l:listPats, l:patZero)
        elseif a:listPatParns[i] == 1
            let l:listPats = add(l:listPats, l:patOne)
        endif
    endfor
    if (len(l:listPats) > 0)
        return join(l:listPats, '[^()]*')
    else
        return l:listPats[0]
    endif
endfunction

function! s:GetPatParnsZeroForSyn(listPatParns)
    let l:fpat = '/([^()]*%s[^()]*$\&./'
    let l:pat = s:GetPatParnsForSyn(GetSubList(a:listPatParns, 1))
    let l:fpat2 = printf(l:fpat, l:pat)
    let l:syn = 'syntax match myMatch '. l:fpat2
    "echom l:syn
    execute l:syn
endfunction

function! s:GetPatParnsOneForSyn(listPatParns)
    let fpat = '/\(^[^()]*%s[^()]*\)\@<=)/'
    call remove(a:listPatParns, len(a:listPatParns)-1)
    let l:pat = s:GetPatParnsForSyn(a:listPatParns)
    let l:fpat2 = printf(l:fpat, l:pat)
    let l:syn = 'syntax match myMatch '. l:fpat2
    "echom l:syn
    execute l:syn
endfunction

" find matchings in given line
" TODO: we should find matching for given block of code, not actually a line of code
function! s:RunPmatchForLine(line)
    "echom 'line:'.a:line
    let l:listPatParns = s:GetPatParns(a:line)
    "echom 'listPatParns:'.string(listPatParns)
    let l:listOfListPatParns = s:GetListOfListPatParns(l:listPatParns)
    "echom 'listOfListPatParns:'.string(l:listOfListPatParns)
    let l:fpat = '/([^()]*%s[^()]*$\&./'
    if len(l:listOfListPatParns) > 0
        for i in range(len(l:listOfListPatParns))
            let l:lst = l:listOfListPatParns[i]
            if has_key(s:gOldSyn, string(l:lst))
                continue
            else
                let s:gOldSyn[string(l:lst)] = 1
                if type(l:lst[0]) != type([]) && l:lst[0] == 0
                    call s:GetPatParnsZeroForSyn(l:lst)
                else
                    call s:GetPatParnsOneForSyn(l:lst)
                endif
            endif
            "let l:pat = s:GetPatParnsForSyn(GetSubList(l:lst, 1))
            "let l:fpat2 = printf(l:fpat, l:pat)
            "let l:syn = 'syntax match myMatch '. l:fpat2
            "echom l:syn
            "execute l:syn
        endfor
    else
        let l:fpat2 = printf(l:fpat, '')
        let l:syn = 'syntax match myMatch '. l:fpat2
        "echom l:syn
        execute l:syn
    endif
endfunction

function! s:FeedParn(ch)
    " make sure ch will be inserted into the correct position
    let line = getline('.')
    let line = strpart(line, 0, col('.')-1) . a:ch . strpart(line, col('.')-1)

    " by default it is line based so pass the line here
    " TODO: pmatch should support block based, so matching will be
    "       work in a block of code instead of a line
    call s:RunPmatchForLine(l:line)
    return a:ch
endfunction

" run pmatch when opening a file
function! s:RunPmatchWhenOpenFile()
    let listOfLines = StdGetListOfLinesOfCurrentFile()
    for i in range(len(listOfLines))
        call s:RunPmatchForLine(listOfLines[i])
    endfor
endfunction

""""""""""""""""""""""""""""""""""""""""""
" end of plugin body
""""""""""""""""""""""""""""""""""""""""""

" Pmatch command processor
function! s:CmdProcessor(args)
    inoremap <silent> ( <C-r>=<SID>FeedParn('(')<CR>
    inoremap <silent> ) <C-r>=<SID>FeedParn(')')<CR>
endfunction

" restore vim settings
call s:Restore_cpo()

" this command is for extending the functionalities of pmatch
" TODO: in future, the user can set their own matchings
"command -narg=+ Pmatch :call s:CmdProcessor(<q-args>)

" run Pmatch
call s:CmdProcessor('')

" run pmatch when opening a file
au BufRead * call <SID>RunPmatchWhenOpenFile()
