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

highlight link myMatch Error
let s:gOldSyns = {}
let s:gMatches = {}
let s:gCurOldSyn = {}

let s:gLeftParn = ''
let s:gRightParn = ''

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
           "elseif ch =~ '('
           elseif ch =~ s:gLeftParn
               let listParns = add(listParns, 0)
           "elseif ch =~ ')'
           elseif ch =~ s:gRightParn
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
                " TODO: this else statement could be refactored`
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

" given [0,2,1,2] return [0,2,1]
function! s:GetSubListForOne(list, idx)
    if a:idx > len(a:list)-1
        return []
    endif
    let listRet = [a:list[a:idx]]
    if a:idx < 1
        return listRet
    endif
    for i in range(a:idx-1, 0, -1)
        let listRet = add(listRet, a:list[i])
    endfor
    return reverse(listRet)
endfunction

" get a list that we need to translate to regex
" [0,2,0,[2]] => [[0,2,0,[2]], [0,[2]]]
" [1,2,1,[2]] => [[1], [1,2,1]]
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

" this converts the list of parns to the regex string for syn cmd
" e.g.
" [0,2] => ([^()*]([^()]*)
" [2,1] => ([^()]*)[^()]*)
function! s:GetPatParnsForSyn(listPatParns)
    if len(a:listPatParns) == 0
        return ''
    endif

    " examples
    "let patZero = '('
    "let patOne = ')'
    "let patTwo = '([^()]*)'
    "let patList = '([^()]*%s[^()]*)'
    let listPats = []
    let patZero = s:gLeftParn
    let patOne = s:gRightParn
    let patTwo = s:gLeftParn . '[^' . s:gLeftParn . s:gRightParn . ']*' . s:gRightParn
    let patList = s:gLeftParn . '[^' . s:gLeftParn . s:gRightParn . ']*%s[^' . s:gLeftParn . s:gRightParn . ']*' . s:gRightParn
    for i in range(len(a:listPatParns))
        if type(a:listPatParns[i]) == type([])
            let pat = printf(patList, s:GetPatParnsForSyn(a:listPatParns[i]))
            let listPats = add(listPats, pat)
        elseif a:listPatParns[i] == 2
            let listPats = add(listPats, patTwo)
        elseif a:listPatParns[i] == 0
            let listPats = add(listPats, patZero)
        elseif a:listPatParns[i] == 1
            let listPats = add(listPats, patOne)
        endif
    endfor
    if (len(listPats) > 0)
        " example
        "return join(listPats, '[^()]*')
        return join(listPats, '[^' .  s:gLeftParn . s:gRightParn . ']*')
    else
        return listPats[0]
    endif
endfunction

" this generates regex that matches the left-parn
function! s:GetPatParnsZeroForSyn(listPatParns)
    " example
    "let l:fpat = '/([^()]*%s[^()]*$\&./'
    let l:fpat = '/%s[^%s%s]*%s[^%s%s]*$\&./'
    " remove the first element, 0, from listOfParns
    let l:pat = s:GetPatParnsForSyn(GetSubList(a:listPatParns, 1))
    let l:fpat2 = printf(l:fpat, s:gLeftParn, s:gLeftParn, s:gRightParn, l:pat, s:gLeftParn, s:gRightParn)
    let l:syn = 'syntax match myMatch '. l:fpat2
    "echom l:syn
    execute l:syn
endfunction

" this generates regex that matches the right-parn
function! s:GetPatParnsOneForSyn(listPatParns)
    " example
    "let fpat = '/\(^[^()]*%s[^()]*\)\@<=)/'
    let fpat = '/\(^[^%s%s]*%s[^%s%s]*\)\@<=%s/'
    " remove the last element, 1, from listPatParns
    call remove(a:listPatParns, len(a:listPatParns)-1)
    let l:pat = s:GetPatParnsForSyn(a:listPatParns)
    let l:fpat2 = printf(l:fpat, s:gLeftParn, s:gRightParn, l:pat, s:gLeftParn, s:gRightParn, s:gRightParn)
    let l:syn = 'syntax match myMatch '. l:fpat2
    "echom l:syn
    execute l:syn
endfunction

" find matchings in given line
" TODO: we should find matching for given block of code, not actually a line of code
function! s:RunPmatchForLine(line)
    "echom 'line:'.a:line
    let listPatParns = s:GetPatParns(a:line)
    "echom 'listPatParns:'.string(listPatParns)
    let listOfListPatParns = s:GetListOfListPatParns(listPatParns)
    "echom 'listOfListPatParns:'.string(listOfListPatParns)
    if len(listOfListPatParns) > 0
        for i in range(len(listOfListPatParns))
            let lst = listOfListPatParns[i]
            " check if we have found the same pattern before
            " ignore it if we have
            if has_key(s:gCurOldSyn, string(lst))
                continue
            else
                let s:gCurOldSyn[string(lst)] = 1
                " we find new pattern for left-parn to match
                if type(lst[0]) != type([]) && lst[0] == 0
                    call s:GetPatParnsZeroForSyn(lst)
                " otherwise we find new pattern for right-parn to match
                else
                    call s:GetPatParnsOneForSyn(lst)
                endif
            endif
        endfor
    endif
endfunction

" escape certain characters for regex pattern
function! s:CheckAndEscapeChar(ch)
    let charsToEscaped = '[]'
    if stridx(charsToEscaped, a:ch) > -1
        return '\' . a:ch
    endif
    return a:ch
endfunction

function! s:SetGlobalVariablesForChar(ch)
    " get the char for pmatch to work on
    let leftParn = s:gMatches[a:ch]['left']
    let s:gLeftParn = s:CheckAndEscapeChar(leftParn)
    let s:gRightParn = s:CheckAndEscapeChar(s:gMatches[a:ch]['right'])
    "echom 'left(' . s:gLeftParn . ') right(' . s:gRightParn . ')'

    " set the current old syn to check
    let s:gCurOldSyn = s:gOldSyns[leftParn]
endfunction

" run pmatch when the user enters the left-parn or the right-parn
function! s:FeedParn(ch)
    " make sure ch will be inserted into the correct position
    let line = getline('.')
    let line = strpart(line, 0, col('.')-1) . a:ch . strpart(line, col('.')-1)

    call s:SetGlobalVariablesForChar(a:ch)
    " get the char for pmatch to work on
    "let leftParn = s:gMatches[a:ch]['left']
    "let s:gLeftParn = s:CheckAndEscapeChar(leftParn)
    "let s:gRightParn = s:CheckAndEscapeChar(s:gMatches[a:ch]['right'])
    "echom 'left(' . s:gLeftParn . ') right(' . s:gRightParn . ')'

    " set the current old syn to check
    "let s:gCurOldSyn = s:gOldSyns[leftParn]

    " by default it is line based so pass the line here
    " TODO: pmatch should support block based, so matching will be
    "       work in a block of code instead of a line
    call s:RunPmatchForLine(l:line)
    return a:ch
endfunction

" run pmatch when opening a file
"TODO: make this function to work on multiple matches
function! s:RunPmatchWhenOpenFile()
    let listLines = StdGetListOfLinesOfCurrentFile()
    for i in range(len(listLines))
        for k in keys(s:gOldSyns)
            call s:SetGlobalVariablesForChar(k)
            call s:RunPmatchForLine(listLines[i])
        endfor
    endfor
endfunction

""""""""""""""""""""""""""""""""""""""""""
" end of plugin body
""""""""""""""""""""""""""""""""""""""""""

" Pmatch command processor
function! s:CmdProcessor(args)
    let syn = "inoremap <silent> %s <C-r>=<SID>FeedParn('%s')<CR>"

    " StdParseCmd() returns a list [cmdName, {parmObj}]
    let listCmd = StdParseCmd(a:args)
    if len(listCmd) > 1
        " pmatch now only support addMatch command
        if listCmd[0] =~ 'addMatch'
            let dictParams = listCmd[1]
            let leftParn = dictParams['left']
            let rightParn = dictParams['right']

            let s:gMatches[leftParn] = dictParams
            let s:gMatches[rightParn] = dictParams

            " when checking the old syn, we only use the left parn as the key
            let dictOldSyn = {}
            let s:gOldSyns[leftParn] = dictOldSyn

            let syn1 = printf(syn, leftParn, leftParn)
            let syn2 = printf(syn, rightParn, rightParn)
            "echom syn1
            "echom syn2
            execute syn1
            execute syn2
        endif
    endif
    " examples
    "inoremap <silent> ( <C-r>=<SID>FeedParn('(')<CR>
    "inoremap <silent> ) <C-r>=<SID>FeedParn(')')<CR>
endfunction

" restore vim settings
call s:Restore_cpo()

" this command is for extending the functionalities of pmatch
" TODO: in future, the user can set their own matchings
command -narg=+ Pmatch :call s:CmdProcessor(<q-args>)

" run Pmatch
"call s:CmdProcessor('')

" run pmatch when opening a file
au BufRead * call <SID>RunPmatchWhenOpenFile()
