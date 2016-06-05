" author: ryan feng


" check if it is already loaded
if exists("g:loaded_pmatch")
    finish
endif
let g:loaded_pmatch = 1

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

" plugin body
let s:gNumOfParns = 0
highlight link myMatch Error
let s:gOldSyn = {}

"TODO: implement
"   ( => [0]
"   () => [1]
"   (() => [0,1]
"   (()() => [0,1,1]
"   ((()()) => [0,[1,1]]
"   ((( => [0,0,0]
"   (()((()) => [0,1,0,[1]]
function! s:GetPatParns(line)
    let l:listPatParns = []
    let l:listParns = []
    let l:bEscaped = g:FALSE
    let l:bFoundString = g:FALSE
    for i in range(len(a:line))
       let l:ch = a:line[i] 
       if !l:bFoundString
           if l:ch =~ '"' || l:ch =~ "'"
               let l:bFoundString = g:TRUE
           elseif l:ch =~ '('
               let l:listParns = add(l:listParns, 0)
           elseif l:ch =~ ')'
               let l:listParns = add(l:listParns, 1)
           endif
       else
           if l:ch =~ '\'
               let l:bEscaped = g:TRUE
           elseif l:ch =~ '"' || l:ch =~ "'"
               if l:bEscaped
                   let l:bEscaped = g:FALSE
               else
                   let l:bFoundString = g:FALSE
               endif
           endif
       endif
    endfor

    for i in range(len(l:listParns))
        let l:iParn = l:listParns[i]
        if l:iParn == 0
            let l:listPatParns = add(l:listPatParns, 0)
        elseif l:iParn == 1
            let l:lenPatParns = len(l:listPatParns)
            if type(l:listPatParns[l:lenPatParns-1]) != type([]) && l:listPatParns[l:lenPatParns-1] == 0
                let l:listPatParns[l:lenPatParns-1] = 1
            else
                let l:idx = 0
                for j in range(l:lenPatParns-1, 0, -1)
                    if type(l:listPatParns[j]) != type([]) && l:listPatParns[j] == 0
                        let l:idx = j
                        break
                    endif
                endfor
                let l:lst = []
                for k in range(l:idx)
                    let l:lst = add(l:lst, l:listPatParns[k])
                endfor
                let l:lst2 = []
                for m in range(l:idx+1, l:lenPatParns-1)
                    let l:lst2 = add(l:lst2, l:listPatParns[m])
                endfor
                let l:listPatParns = add(l:lst, l:lst2)
            endif
        endif
    endfor
    return l:listPatParns
endfunction

function! s:GetNumOfParns(line)
    let l:iNumOfParns = 0
    for i in range(len(a:line))
        if a:line[i] =~ '('
            let l:iNumOfParns = l:iNumOfParns + 1
        endif
    endfor
    return l:iNumOfParns
endfunction

" given [0, 1, 0, [1]]
" return [[0,1,0,[1]], [0,[1]]]
function! s:GetListOfListPatParns(listPatParns)
    let l:listOfListPatParns = []
    if len(a:listPatParns) > 0
        for i in range(len(a:listPatParns)-1)
            if type(a:listPatParns[i]) != type([]) && a:listPatParns[i] == 0
                let l:listOfListPatParns = add(l:listOfListPatParns, GetSubList(a:listPatParns, i))
            endif
        endfor
    endif
    return l:listOfListPatParns
endfunction

function! s:GetPatParnsForSyn(listPatParns)
    if len(a:listPatParns) == 0
        return ''
    endif

    let l:listPats = []
    let l:patZero = '([^)]*'
    let l:patOne = '([^)]*)'
    let l:patList = '([^)]*%s[^)]*)'
    for i in range(len(a:listPatParns))
        if type(a:listPatParns[i]) == type([])
            let l:pat = printf(l:patList, s:GetPatParnsForSyn(a:listPatParns[i]))
            let l:listPats = add(l:listPats, l:pat)
        elseif a:listPatParns[i] == 1
            let l:listPats = add(l:listPats, l:patOne)
        elseif a:listPatParns[i] == 0
            let l:listPats = add(l:listPats, l:patZero)
        endif
    endfor
    if (len(l:listPats) > 0)
        return join(l:listPats, '[^(]*')
    else
        return l:listPats[0]
    endif
endfunction

function! s:FeedRoundParn2(ch)
    let l:line = getline('.') . a:ch
    let l:listPatParns = s:GetPatParns(l:line)
    let l:listOfListPatParns = s:GetListOfListPatParns(l:listPatParns)
    echom 'feed2:'.string(l:listOfListPatParns)
    let l:fpat = '/([^)]*%s[^)]*$\&./'
    if len(l:listOfListPatParns) > 0
        for i in range(len(l:listOfListPatParns))
            let l:lst = l:listOfListPatParns[i]
            if has_key(s:gOldSyn, string(l:lst))
                continue
            else
                let s:gOldSyn[string(l:lst)] = 1
            endif
            let l:pat = s:GetPatParnsForSyn(GetSubList(l:lst, 1))
            let l:fpat2 = printf(l:fpat, l:pat)
            let l:syn = 'syntax match myMatch '. l:fpat2
            echom l:syn
            execute l:syn
        endfor
    else
        let l:fpat2 = printf(l:fpat, '')
        let l:syn = 'syntax match myMatch '. l:fpat2
        echom l:syn
        execute l:syn
    endif
    return a:ch
endfunction

function! s:FeedRoundParn(ch)
    let l:line = getline('.') . a:ch
    let l:iNumOfParns = s:GetNumOfParns(l:line)
    if l:iNumOfParns > s:gNumOfParns
        let s:gNumOfParns = l:iNumOfParns
        let l:pat = ''
        if s:gNumOfParns < 2
            let l:pat = '/([^)]*$\&./'
        else
            let l:patParn = '([^)]*)'
            let l:patNestedParn = '([^)]*%s[^)]*%s'
            let l:pat = l:patParn
            for i in range(s:gNumOfParns-1)
                if i < s:gNumOfParns - 2
                    let l:pat = printf(l:patNestedParn, l:pat, ')')
                else
                    let l:pat = printf(l:patNestedParn, l:pat, '')
                endif
            endfor
            let l:pat = '/' . l:pat . '\($\|\([^(]*(\)\)\&./'
        endif
        let l:syn = 'syntax match myMatch ' . l:pat
        "echom l:syn
        execute l:syn
    endif
    return a:ch
endfunction

" Pmatch command processor
function! s:CmdProcessor(args)
    inoremap <silent> ( <C-r>=<SID>FeedRoundParn2('(')<CR>
    inoremap <silent> ) <C-r>=<SID>FeedRoundParn2(')')<CR>
endfunction

" restore vim settings
call s:Restore_cpo()

" this command is for extending the functionalities of pmatch
" TODO: in future, the user can set their own matchings
"command -narg=+ Pmatch :call s:CmdProcessor(<q-args>)

" run Pmatch
call s:CmdProcessor('')
