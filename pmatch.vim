" author: ryan feng

" check if it is already loaded
if exists("g:loaded_pmatch")
    finish
endif
let g:loaded_pmatch = 1

" this plugin depends on std.vim
if !exists("g:loaded_stdlib")
    echom "ERROR: Pmatch requires std.vim"
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
highlight myMatch2 ctermbg=green

let s:gCurChar = ''

let s:gOldSyns = {}
let s:gMatches = {}
let s:gCurOldSyn = {}

let s:gLeftParn = ''
let s:gRightParn = ''

let s:ParnEnum_L = 0
let s:ParnEnum_R = 1
let s:ParnEnum_LR = 2
let s:ParnEnum_Ro = 3

let s:MatchKey_L = 'left'
let s:MatchKey_R = 'right'

function! s:ReturnFalseFn(parm)
    return g:FALSE
endfunction

function! s:IsRightParnsOtherThanCurOne(ch)
    let rights = s:GetAllRightParns(g:TRUE)
    return stridx(rights, a:ch) != -1
endfunction

function! s:IsOtherRightParns(eParn)
    return type(a:eParn) != type([]) && a:eParn == s:ParnEnum_Ro
endfunction

" this will not escape the left and right parn char
function! s:GetAllLeftOrRightParns(leftOrRight)
    let keys = keys(s:gMatches)
    let keysAsStr = ''
    for key in keys
        let leftOrRightParn = s:gMatches[key][a:leftOrRight]
        if stridx(keysAsStr, leftOrRightParn) == -1
            let keysAsStr = keysAsStr . leftOrRightParn
        endif
    endfor
    return keysAsStr
endfunction

" get all left parns as string
function! s:GetAllLeftParns(exceptCurLeftParn)
    let lefts = s:GetAllLeftOrRightParns(s:MatchKey_L)
    if a:exceptCurLeftParn
        let lefts = StdRemoveChar(lefts, s:gLeftParn)
    endif
    return lefts
endfunction

" get all right parns as string
function! s:GetAllRightParns(exceptCurRightParn)
    let rights = s:GetAllLeftOrRightParns(s:MatchKey_R)
    if a:exceptCurRightParn
        let rights = StdRemoveChar(rights, s:gRightParn)
    endif
    return rights
endfunction

" escape certain characters for regex pattern
function! s:CheckAndEscapeChar(ch)
    let charsToEscaped = '[]'
    if stridx(charsToEscaped, a:ch) > -1
        return '\' . a:ch
    endif
    return a:ch
endfunction

" get the sub list starting with last left parn
function! s:GetLastLeftParnSubList(listParns)
u   for i in range(len(a:listParns)-1, 0, -1)
        let parn = a:listParns[i]
        if type(parn) != type([]) && parn == s:ParnEnum_L
            return StdGetSubList(a:listParns, i)
        endif
    endfor
    return []
endfunction

function! s:GetFirstRightParnSubList(listParns)
    for i in range(len(a:listParns))
        let parn = a:listParns[i]
        if type(parn) != type([]) && parn == s:ParnEnum_R
            return s:GetSubListR(a:listParns, i)
        endif
    endfor
    return []
endfunction

function! s:GetNumOfParns(listParns, leftOrRight)
    let ret = 0
    "echom string(a:listParns)
    for i in range(len(a:listParns))
        if type(a:listParns[i]) != type([]) && a:listParns[i] == a:leftOrRight
            let ret = ret + 1
        endif
    endfor
    return ret
endfunction

function! s:GetNumOfLeftParns(listParns)
    return s:GetNumOfParns(a:listParns, s:ParnEnum_L)
endfunction

function! s:GetNumOfRightParns(listParns)
    return s:GetNumOfParns(a:listParns, s:ParnEnum_R)
endfunction

function! s:IsAnyLeftParns(ch)
    let lefts = s:GetAllLeftParns(g:FALSE)
    return len(a:ch) > 0 && stridx(lefts, a:ch) != -1
endfunction

function! s:IsAnyRightParns(ch)
    let rights = s:GetAllRightParns(g:FALSE)
    return len(a:ch) > 0 && stridx(rights, a:ch) != -1
endfunction

" this translate string to a list of numbers, ( to 0 and ) to 1
" ( => [0]
" ) => [1]
" () => [0,1]
" )( => [1,0]
function! s:StrToListParnsEx(line, customFn, customParn)
    let listParns = []
    let bEscaped = g:FALSE
    let bFoundString = g:FALSE
    let CustomFn = function(a:customFn)
    for i in range(len(a:line))
       let ch = a:line[i] 
       if !bFoundString
           if ch =~ '"' || ch =~ "'"
               let bFoundString = g:TRUE
           "elseif ch =~ '('
           elseif ch =~ s:gLeftParn
               let listParns = add(listParns, s:ParnEnum_L)
           "elseif ch =~ ')'
           elseif ch =~ s:gRightParn
               let listParns = add(listParns, s:ParnEnum_R)
           elseif CustomFn(ch)
               let listParns = add(listParns, a:customParn)
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

function! s:StrToListParns(line)
    return s:StrToListParnsEx(a:line, 's:ReturnFalseFn', -1)
endfunction

" this translates list of parns to list of list parns
" [0,1] => [2]
" [0,0,1] => [0,2]
" [0,1,1] => [2,1]
" [0,0,1,1] => [[2]]
function! s:ListParnsToListOfListParnsEx(listParns, shouldStopLookingForLeftParnFn)
    let listPatParns = []
    let ShouldStopLookingForLeftParnFn = function(a:shouldStopLookingForLeftParnFn)
    for i in range(len(a:listParns))
        let iParn = a:listParns[i]
        if iParn == s:ParnEnum_L
            let listPatParns = add(listPatParns, s:ParnEnum_L)
        elseif iParn == s:ParnEnum_R
            let lenPatParns = len(listPatParns)

            " in case there is no left-parn but we found a right-parn
            if lenPatParns < 1
                let listPatParns = add(listPatParns, s:ParnEnum_R)

            " trying to find the corresponding left-parn
            else
                let idx = -1
                for j in range(lenPatParns-1, 0, -1)
                    " custom fn that stop looking for left parn
                    " if it stops, it add right parn to list parns
                    if ShouldStopLookingForLeftParnFn(listPatParns[j])
                        let l:idx = -1
                        break
                    elseif type(listPatParns[j]) != type([]) && listPatParns[j] == s:ParnEnum_L
                        let l:idx = j
                        break
                    endif
                endfor
                " in case the left-parn is left-next to it
                if idx == lenPatParns-1
                    let listPatParns[lenPatParns-1] = s:ParnEnum_LR
                " in case there is no corresponding left-parn
                elseif idx == -1
                    let listPatParns = add(listPatParns, s:ParnEnum_R)
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
        else
            let listPatParns = add(listPatParns, iParn)
        endif
    endfor
    return listPatParns
endfunction

function! s:ListParnsToListOfListParns(listParns)
    return s:ListParnsToListOfListParnsEx(a:listParns, 's:ReturnFalseFn')
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
                if a:listPatParns[i] == s:ParnEnum_L
                    let l:listOfListPatParns = add(l:listOfListPatParns, StdGetSubList(a:listPatParns, i))
                elseif a:listPatParns[i] == s:ParnEnum_R
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
        elseif a:listPatParns[i] == s:ParnEnum_LR
            let listPats = add(listPats, patTwo)
        elseif a:listPatParns[i] == s:ParnEnum_L
            let listPats = add(listPats, patZero)
        elseif a:listPatParns[i] == s:ParnEnum_R
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

" this convert list parns to regex
function! s:ListParnsToPattern(listPatParns)
    let fpat = '[^%s%s]*%s[^%s%s]*'
    let pat = s:GetPatParnsForSyn(a:listPatParns)
    let fpat2 = printf(fpat, s:gLeftParn, s:gRightParn, pat, s:gLeftParn, s:gRightParn)
    return fpat2
endfunction

function! s:RunSynForPatParnsZero(listPatParns)
    " example
    "let l:fpat = '/([^()]*%s[^()]*$\&./'
    let pat = '/%s%s$\&./'
    " remove the first element, 0, from list parns
    let pat = printf(pat, s:gLeftParn, s:ListParnsToPattern(StdGetSubList(a:listPatParns, 1)))
    let syn = 'syntax match myMatch ' . pat
    "echom syn
    execute syn
endfunction

function! s:RunSynForPatParnsOne(listPatParns)
    " example
    "let fpat = '/\(^[^()]*%s[^()]*\)\@<=)/'
    let pat = '/\(^%s\)\@<=%s/'
    " remove the last element, 1, from list parns
    call remove(a:listPatParns, len(a:listPatParns)-1)
    let pat = printf(pat, s:ListParnsToPattern(a:listPatParns), s:gRightParn)
    let syn = 'syntax match myMatch ' . pat
    "echom syn
    execute syn
endfunction

" start from the next line of current line, parse each line and find
" all list parns that will be run multi-pmatch for
function! s:GetListOfListParnsForMultiLine(lineNo)
    let listOfListPat = []
    let iLineNo = a:lineNo
    let iLastLineNo = line('$')

    let numLeftParns = 1
    while iLineNo < iLastLineNo && numLeftParns > 0
        let listPat = s:GetPatParns(getline(iLineNo))
        "echom string(listPat)

        if len(listPat) > 0
            let numLeftParns = numLeftParns + s:GetNumOfLeftParns(listPat)
            let numLeftParns = numLeftParns - s:GetNumOfRightParns(listPat)
        endif
        
        let listOfListPat = add(listOfListPat, listPat)
        let iLineNo = iLineNo + 1
    endwhile

    return listOfListPat
endfunction

function! s:GetListOfListParnsForMultiLine2(listOfListParns)
    "echom string(a:listOfListParns)
    let listParns = StdJoinLists(a:listOfListParns, 4)
    "echom string(listParns)
endfunction

" this try to run multi-pmatch from current line, so it could exist immediately
function! s:TryRunPmatchForMultiLine(line)
    " exits if no left parns found on current line
    let listPat = s:GetPatParns(a:line)
    if s:GetNumOfLeftParns(listPat) < 1
        return
    endif

    let listOfListParns = []
    let listOfListParns = add(listOfListParns, listPat)

    let listOfListParns = extend(listOfListParns, s:GetListOfListParnsForMultiLine(line('.')+1))
    let listParns = s:GetListOfListParnsForMultiLine2(listOfListParns)
endfunction

" converts list parns to list of list unmatched parns
" [0, 0, 3, 1, 0, 2, [2], 3, 2] => [[0, 3], [0, 2, [2], 3]]
function! s:GetListOfListParnsForUnmatchedParns(listParns)
    let listOfListParns = []
    let listParns = []
    for i in range(len(a:listParns))
        if type(a:listParns[i]) != type([]) && a:listParns[i] == s:ParnEnum_L
            let listParns = []
        endif
        let listParns = add(listParns, a:listParns[i])
        if type(a:listParns[i]) != type([]) && a:listParns[i] == s:ParnEnum_Ro
            let listOfListParns = add(listOfListParns, listParns)
            let listParns = []
        endif
    endfor
    return listOfListParns
endfunction

"a left parn of one kind should be closed by a right pran of another kind
function! s:AddMatchForUnmatchedLeftAndRightParns(line)
    "echom a:line

    " converts line to list of list parns
    let listParns = s:StrToListParnsEx(a:line, 's:IsRightParnsOtherThanCurOne', s:ParnEnum_Ro)
    "echom string(listParns)
    let listParns = s:ListParnsToListOfListParnsEx(listParns, 's:IsOtherRightParns')
    "echom string(listParns)
    let listOfListParns = s:GetListOfListParnsForUnmatchedParns(listParns)
    "echom string(listOfListParns)

    for listParns in listOfListParns
        " check if there is a same match already added
        if has_key(s:gCurOldSyn, string(listParns))
            continue
        elseif len(listParns) > 1
            let s:gCurOldSyn[string(listParns)] = 1

            let pat = '/%s%s[%s]\&./'
            let pat2 = ''

            let otherRights = s:GetAllRightParns(g:TRUE)
            if len(listParns) == 2
                let pat2 = '[^%s%s]*'
                let pat2 = printf(pat2, s:gLeftParn, s:gRightParn)
            elseif len(listParns) > 2
                let pat2 = s:ListParnsToPattern(StdGetSubList(listParns, 1, len(listParns)-2))
            endif
            let pat = printf(pat, s:gLeftParn, pat2, otherRights)
            let syn = 'syntax match myMatch ' . pat
            "echom syn
            execute syn
        endif
    endfor
endfunction

function! s:AddMatchForLeftAndRightParn(line)
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
                if type(lst[0]) != type([]) && lst[0] == s:ParnEnum_L
                    call s:RunSynForPatParnsZero(lst)
                " otherwise we find new pattern for right-parn to match
                else
                    call s:RunSynForPatParnsOne(lst)
                endif
            endif
        endfor
    endif
endfunction

" find the nearest left parn that is left-next to the current char
" which should be a right parn
function! s:FindNearestLeftParnLeftNext()
    let line = getline('.')
    let line = strpart(line, 0, col('.')-1)

    let bFoundQuote = g:FALSE
    let nestedParns = 0
    for i in range(len(line)-1, 0, -1)
        let ch = line[i]

        if ch =~ '"' || ch =~ "'"
            let bFoundQuote = bFoundQuote == g:FALSE && g:TRUE
        endif

        if bFoundQuote == g:TRUE
            continue
        elseif s:IsAnyLeftParns(ch)
            if nestedParns == 0
                return ch
            endif
            let nestedParns = nestedParns - 1
        elseif s:IsAnyRightParns(ch)
            " if we find any right parn before we find a left parn
            " end this function immediately
            if i < len(line)-1 && nestedParns == 0
                return ''
            endif
            let nestedParns = nestedParns + 1
        endif
    endfor
    return ''
endfunction

" find matchings in given line
" this function will be called when opening a file and when user enters a parn
" TODO: we should find matching for given block of code, not actually a line of code
function! s:RunPmatchForLine(line)
    call s:AddMatchForLeftAndRightParn(a:line)

    " this block of code will run if the user just enter a right parn
    " because we only highlight the left parn of a unmatched pairs,
    " this will find the any left parn that is nearest left-next to it
    if s:IsAnyRightParns(s:gCurChar)
        "echom "when open a file, you shouldn't see this"
        let leftParn = s:FindNearestLeftParnLeftNext()
        if s:IsAnyLeftParns(leftParn)
            call s:SetGlobalVariablesForChar(leftParn)
        endif
    endif

    call s:AddMatchForUnmatchedLeftAndRightParns(a:line)
endfunction

" set the global variables, this must be called first before pmatch
" tries to parse the input
" note functions depend on these values to work properly
function! s:SetGlobalVariablesForChar(ch)
    " set the char the user just enter
    let s:gCurChar = a:ch

    " get the char for pmatch to work on
    let leftParn = s:gMatches[a:ch][s:MatchKey_L]
    let s:gLeftParn = s:CheckAndEscapeChar(leftParn)
    let s:gRightParn = s:CheckAndEscapeChar(s:gMatches[a:ch][s:MatchKey_R])
    "echom 'left(' . s:gLeftParn . ') right(' . s:gRightParn . ')'

    " set the current old syn to check
    let s:gCurOldSyn = s:gOldSyns[leftParn]
endfunction

" run pmatch when the user enters the left-parn or the right-parn
function! s:FeedParn(ch)
    " make sure ch will be inserted into the correct position
    let line = getline('.')
    let line = strpart(line, 0, col('.')-1) . a:ch . strpart(line, col('.')-1)

    " set the global variables first
    call s:SetGlobalVariablesForChar(a:ch)

    " by default it is line based so pass the line here
    " TODO: pmatch should support block based, so matching will be
    "       work in a block of code instead of a line
    call s:RunPmatchForLine(l:line)

    " check if we should run pmatch for multi line
    "call s:TryRunPmatchForMultiLine(l:line)
    return a:ch
endfunction

" run pmatch when opening a file
"TODO: make this function to work on multiple matches
function! s:RunPmatchWhenOpenFile()
    let listLines = StdGetListOfLinesOfCurrentFile()
    for i in range(len(listLines))
        for leftParn in keys(s:gOldSyns)
            call s:SetGlobalVariablesForChar(leftParn)
            call s:RunPmatchForLine(listLines[i])
        endfor
    endfor
endfunction

""""""""""""""""""""""""""""""""""""""""""
" end of plugin body
""""""""""""""""""""""""""""""""""""""""""

" Pmatch command processor
function! s:CmdProcessor(args)
    " examples
    "inoremap <silent> ( <C-r>=<SID>FeedParn('(')<CR>
    "inoremap <silent> ) <C-r>=<SID>FeedParn(')')<CR>
    let syn = "inoremap <silent> %s <C-r>=<SID>FeedParn('%s')<CR>"

    " StdParseCmd() returns a list [cmdName, {parmObj}]
    let listCmd = StdParseCmd(a:args)
    if len(listCmd) > 1
        " pmatch now only support addMatch command
        if listCmd[0] =~ 'addMatch'
            let dictParams = listCmd[1]
            let leftParn = dictParams[s:MatchKey_L]
            let rightParn = dictParams[s:MatchKey_R]

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
endfunction

" restore vim settings
call s:Restore_cpo()

" this command is for extending the functionalities of pmatch
" TODO: in future, the user can set their own matchings
command -narg=+ Pmatch :call s:CmdProcessor(<q-args>)

Pmatch addMatch left=( right=)
Pmatch addMatch left=[ right=]

" run pmatch when opening a file
au BufRead * call <SID>RunPmatchWhenOpenFile()
