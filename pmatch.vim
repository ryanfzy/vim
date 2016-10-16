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
"highlight myMatch ctermbg=red ctermfg=yellow

let s:gMode = 0
let s:gCurChar = ''

let s:gOldSyns = {}
let s:gMatches = {}
let s:gCurOldSyn = {}

let s:gOldListParns = {}

let s:gLeftParn = ''
let s:gRightParn = ''

let s:ParnEnum_None = -1
let s:ParnEnum_L = 0
let s:ParnEnum_R = 1
let s:ParnEnum_LR = 2
let s:ParnEnum_Lo = 3
let s:ParnEnum_Ro = 4
let s:ParnEnum_LRo = 5
let s:ParnEnum_La = 6
let s:ParnEnum_Ra = 7

let s:ModeEnum_Input = 0
let s:ModeEnum_Auto = 1

let s:MatchKey_L = 'left'
let s:MatchKey_R = 'right'

let s:gCharsToEscape = '[]'
let s:gAnyCharsPatT = '[^%s%s]*'
let s:gAnyCharsPatT2 = '[%s]' 

" these variables will be set at run time
" they are introduced for improving performance
let s:gAllLefts = ''
let s:gAllRights = ''

let s:gAllOtherLefts = ''
let s:gAllOtherRights = ''

let s:gDictAllOtherLefts = {}
let s:gDictAllOtherRights = {}

let s:gAnyCharsPat = ''
let s:gAnyCharsPat2 = ''
let s:gAnyLeftPat = ''
let s:gAnyRightPat = ''
let s:gAnyOtherRightPat = ''

let s:gNumFnCalled = {}
let s:gTmFnCalled = {}

function! s:GetTime()
    "return system('date +%s%N') / 1000000
    return localtime()
endfunction

function! s:StartFnCall(fnName)
    let fn = {}
    let fn['name'] = a:fnName
    let fn['tmStart'] = s:GetTime()
    return fn
endfunction

function! s:EndFnCall(fn)
    let time = s:GetTime() - a:fn['tmStart']
    let name = a:fn['name']
    if has_key(s:gNumFnCalled, name)
        let s:gNumFnCalled[name] += 1
        let s:gTmFnCalled[name] += time
    else
        let s:gNumFnCalled[name] = 1
        let s:gTmFnCalled[name] = time
    endif
endfunction

function! s:ShowFnCalled()
    for key in keys(s:gNumFnCalled)
        echom key . ':' . s:gNumFnCalled[key] . '-' . s:gTmFnCalled[key]
    endfor
endfunction

function! s:SetGlobalVariables()
    let fn = s:StartFnCall('SetGlobalVariables')

    let s:gAllLefts = s:GetAllLeftOrRightParns(s:MatchKey_L, g:FALSE)
    let s:gAllRights = s:GetAllLeftOrRightParns(s:MatchKey_R, g:FALSE)

    let s:gAnyCharsPat2 = printf(s:gAnyCharsPatT, s:gAllLefts, s:gAllRights)
    let s:gAnyLeftPat = printf(s:gAnyCharsPatT2, s:gAllLefts)
    let s:gAnyRightPat = printf(s:gAnyCharsPatT2, s:gAllRights)

    call s:EndFnCall(fn)
endfunction

function! s:SetGlobalVariablesForCurParn()
    let fn = s:StartFnCall('SetGlobalVariablesForCurParn')

    let s:gAllOtherLefts = s:GetAllLeftOrRightParns(s:MatchKey_L, g:TRUE)
    let s:gAllOtherRights = s:GetAllLeftOrRightParns(s:MatchKey_R, g:TRUE)

    "for i in range(len(s:gAllOtherLefts))
        "let s:gDictAllOtherLefts[s:gAllOtherLefts[i]] = s:ParnEnum_Lo
    "endfor

    "for i in range(len(s:gAllOtherRights))
        "let s:gDictAllOtherRights[s:gAllOtherRights[i]] = s:ParnEnum_Ro
    "endfor

    let s:gAnyCharsPat = printf(s:gAnyCharsPatT, s:gLeftParn, s:gRightParn)
    let s:gAnyOtherRightPat = printf(s:gAnyCharsPatT2, s:gAllOtherRights)

    call s:EndFnCall(fn)
endfunction

function! s:ReturnParnEnumNoneFn(parm)
    return s:ParnEnum_None 
endfunction

" this will not escape the left and right parn char
function! s:GetAllLeftOrRightParns(leftOrRight, excludeCurOne)
    let fn = s:StartFnCall('GetAllLeftOrRightParns')

    let keys = keys(s:gMatches)
    let keysAsStr = ''
    for key in keys
        let leftOrRightParn = s:CheckAndEscapeChar(s:gMatches[key][a:leftOrRight])
        if a:excludeCurOne && (leftOrRightParn == s:gLeftParn || leftOrRightParn == s:gRightParn)
            continue
        elseif stridx(keysAsStr, leftOrRightParn) == -1
            let keysAsStr = keysAsStr . leftOrRightParn
        endif
    endfor

    call s:EndFnCall(fn)
    return keysAsStr
endfunction

" get all left parns as string
function! s:GetAllLeftParns(exceptCurOne)
    "call s:PlusOneFnCalled('GetAllLeftParns')
    if a:exceptCurOne
        return s:gAllOtherLefts
    endif
    return s:gAllLefts
endfunction

" get all right parns as string
function! s:GetAllRightParns(exceptCurOne)
    "call s:PlusOneFnCalled('GetAllRightParns')
    if a:exceptCurOne
        return s:gAllOtherRights
    endif
    return s:gAllRights
endfunction

" escape certain characters for regex pattern
function! s:CheckAndEscapeChar(ch)
    let fn = s:StartFnCall('CheckAndEscapeChar')

    if len(a:ch) > 0 && stridx(s:gCharsToEscape, a:ch) > -1
        return '\' . a:ch
    endif

    call s:EndFnCall(fn)
    return a:ch
endfunction

" get the sub list starting with last left parn
function! s:GetLastLeftParnSubList(listParns)
    let fn = s:StartFnCall('GetLastLeftParnSubList')

    for i in range(len(a:listParns)-1, 0, -1)
        let parn = a:listParns[i]
        if type(parn) != type([]) && parn == s:ParnEnum_L
            
            call s:EndFnCall(fn)
            return StdGetSubList(a:listParns, i)
        endif
    endfor

    call s:EndFnCall(fn)
    return []
endfunction

function! s:GetFirstRightParnSubList(listParns)
    let fn = s:StartFnCall('GetFirstRightParnSubList')
    for i in range(len(a:listParns))
        let parn = a:listParns[i]
        if type(parn) != type([]) && parn == s:ParnEnum_R

            call s:EndFnCall(fn) 
            return s:GetSubListR(a:listParns, i)
        endif
    endfor

    call s:EndFnCall(fn) 
    return []
endfunction

function! s:IsAnyLeftParns(ch)
    let fn = s:StartFnCall('IsAnyLeftParns')

    let lefts = s:GetAllLeftParns(g:FALSE)
    let ret = len(a:ch) > 0 && stridx(lefts, a:ch) != -1
    
    call s:EndFnCall(fn)
    return ret
endfunction

function! s:IsAnyOtherLeftParns(ch)
    let fn = s:StartFnCall('IsAnyOtherLeftParns')

    let lefts = s:GetAllLeftParns(g:TRUE)
    let ret = len(a:ch) > 0 && stridx(lefts, a:ch) != -1

    call s:EndFnCall(fn)
    return ret
endfunction

function! s:IsAnyRightParns(ch)
    let fn = s:StartFnCall('IsAnyRightParns')

    let rights = s:GetAllRightParns(g:FALSE)
    let ret = len(a:ch) > 0 && stridx(rights, a:ch) != -1

    call s:EndFnCall(fn)
    return ret
endfunction

" this translate string to a list of numbers, ( to 0 and ) to 1
" ( => [0]
" ) => [1]
" () => [0,1]
" )( => [1,0]
" [ => [3]
" ] => [4]
" [] => [3,4]
" it also accept a custom function which accept the ch and translate it
" into a number or enumeration
function! s:StrToListParns(line)
    let fn = s:StartFnCall('StrToListParnsEx')

    let listParns = []
    let bEscaped = g:FALSE
    let bFoundString = g:FALSE

    for i in range(len(a:line))
       let ch = a:line[i] 
       if !bFoundString
           if ch =~ '"' || ch =~ "'"
               let bFoundString = g:TRUE
           elseif ch =~ s:gLeftParn
               let listParns = add(listParns, s:ParnEnum_L)
           elseif ch =~ s:gRightParn
               let listParns = add(listParns, s:ParnEnum_R)
           elseif stridx(s:gAllOtherLefts, ch) != -1
               let listParns = add(listParns, s:ParnEnum_Lo)
           elseif stridx(s:gAllOtherRights, ch) != -1
               let listParns = add(listParns, s:ParnEnum_Ro)
           endif
       " ignore parns between " or '
       else
           " ignore escaped characters
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

    call s:EndFnCall(fn)
    return listParns
endfunction

function! s:ListParnsToListOfListParns2(listParns)
    let fn = s:StartFnCall('ListParnsToListOfListParns2')

    let retListOfListParns = []

    let listOfListParns = []
    let listCounts = []

    for parn in a:listParns
        "echom 'parn:'.parn
        if parn == s:ParnEnum_L
            for i in range(len(listOfListParns))
                let listOfListParns[i] = add(listOfListParns[i], parn)
                "let listCounts[i] = listCounts[i] + 1
                let listCounts[i] += 1
            endfor

            let listOfListParns = add(listOfListParns, [parn])
            let listCounts = add(listCounts, 1)
        elseif parn == s:ParnEnum_R
            " remove the paired parns
            let listIndexToRemove = []
            for i in range(len(listCounts))
                if listCounts[i] == 1
                    let listIndexToRemove = add(listIndexToRemove, i)
                endif
                let listOfListParns[i] = add(listOfListParns[i], parn)
                let listCounts[i] = listCounts[i] - 1
            endfor

            if len(listOfListParns) < 1
                let listOfListParns = add(listOfListParns, [parn])
                let listCounts = add(listCounts, -1)
            endif

            "echom 'index:'.string(listIndexToRemove)
            for i in range(len(listIndexToRemove))
                " don't remove the first one
                if listIndexToRemove[i] != 0
                    let index = listIndexToRemove[i] - i
                    if listIndexToRemove[0] == 0 && i == 1
                        let index = index + 1
                    endif
                    call remove(listOfListParns, index)
                    call remove(listCounts, index)
                endif
            endfor

            if len(listCounts) > 0
                " if [L, R, L ,L], add it
                if listCounts[0] < -1
                    let retListOfListParns = add(retListOfListParns, copy(listOfListParns[0]))
                elseif listCounts[0] < 0
                    " if [R], add it
                    if len(listOfListParns[0]) < 2
                        let retListOfListParns = add(retListOfListParns, copy(listOfListParns[0]))
                    " if [L, R, L], add it
                    elseif listOfListParns[0][0] == s:ParnEnum_L
                        let retListOfListParns = add(retListOfListParns, copy(listOfListParns[0]))
                    endif
                endif
            endif
        endif
        "echom 'list parns:'.string(listOfListParns)
        "echom 'counts:'.string(listCounts)
    endfor

    "echom 'counts:'.string(listCounts)
    "echom 'before remove:'.string(listOfListParns)
    if len(listOfListParns) > 0 && len(listOfListParns[0]) > 0
        if listCounts[0] < 1 || listOfListParns[0][0] != s:ParnEnum_L || (len(listOfListParns[0]) > 1 && listCounts[0] == 1 && listOfListParns[0][len(listOfListParns[0])-1] == s:ParnEnum_L)
            call remove(listOfListParns, 0)
        endif
    endif

    let retListOfListParns = extend(retListOfListParns, listOfListParns)

    call s:EndFnCall(fn)
    return retListOfListParns
endfunction

function! s:ListParnsToListOfListParns3(listParns)
    let fn = s:StartFnCall('ListParnsToListOfListParns3')

    let retListOfListParns = []
    let listOfListParns = []
    let listCounts = []
    if len(a:listParns) > 1
        for parn in a:listParns
            if parn == s:ParnEnum_L || parn == s:ParnEnum_Lo
                for i in range(len(listOfListParns))
                    "let listOfListParns[i] = add(listOfListParns[i], parn)
                    let listOfListParns[i] = add(listOfListParns[i], s:ParnEnum_La)
                    let listCounts[i] = listCounts[i] + 1
                endfor
                if parn == s:ParnEnum_L
                    "let listOfListParns = add(listOfListParns, [parn])
                    let listOfListParns = add(listOfListParns, [s:ParnEnum_L])
                    let listCounts = add(listCounts, 1)
                endif
            elseif parn == s:ParnEnum_R || parn == s:ParnEnum_Ro
                let indexToRemove = []
                for i in range(len(listOfListParns))
                    if listCounts[i] == 1 && len(listOfListParns[i]) == 1 && ((listOfListParns[i][0] == s:ParnEnum_L && parn == s:ParnEnum_R) || (listOfListParns[i][0] == s:ParnEnum_Lo && listOfListParns[i][0] == s:ParnEnum_Ro))
                        let indexToRemove = add(indexToRemove, i)
                    elseif listCounts[i] == 1 && parn == s:ParnEnum_Ro
                        let listOfListParns[i] = add(listOfListParns[i], s:ParnEnum_Ro)
                        let retListOfListParns = add(retListOfListParns, listOfListParns[i])
                        let indexToRemove = add(indexToRemove, i)
                        "let listCounts[i] = listCounts[i] - 1
                    else
                        let listOfListParns[i] = add(listOfListParns[i], s:ParnEnum_Ra)
                    endif
                    "let listOfListParns[i] = add(listOfListParns[i], parn)
                    let listCounts[i] = listCounts[i] - 1
                endfor

                for i in range(len(indexToRemove))
                    let index = indexToRemove[i] - i
                    call remove(listOfListParns, index)
                    call remove(listCounts, index)
                endfor
            endif
        endfor
    endif

    call s:EndFnCall(fn)
    return retListOfListParns
endfunction

" start from the next line of current line, parse each line and find
" all list parns that will be run multi-pmatch for
function! s:GetListOfListParnsForMultiLine(lineNo)
    call s:PlusOneFnCalled('GetListOfListParnsForMultiLIne')
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
    call s:PlusOneFnCalled('GetListOfListParnsForMultiLIne2')
    "echom string(a:listOfListParns)
    let listParns = StdJoinLists(a:listOfListParns, 4)
    "echom string(listParns)
endfunction

" this try to run multi-pmatch from current line, so it could exist immediately
function! s:TryRunPmatchForMultiLine(line)
    call s:PlusOneFnCalled('TryRunPmatchForMultiLine')
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

function! s:GetSynForListParn2(listParns)
    let fn = s:StartFnCall('GetSynForListParn2')

    let pat = ''
    for i in range(len(a:listParns))
        let parn = a:listParns[i]
        let pat = pat . s:gAnyCharsPat2
        if parn == s:ParnEnum_La
            let pat = pat . s:gAnyLeftPat
        elseif parn == s:ParnEnum_Ra
            let pat = pat . s:gAnyRightPat
        elseif parn == s:ParnEnum_Ro
            let pat = pat . s:gAnyOtherRightPat
        endif
    endfor

    call s:EndFnCall(fn)
    return pat
endfunction

function! s:GetSynForListParn(listParns)
    let fn = s:StartFnCall('GetSynForListParn')

    let pat = ''
    for i in range(len(a:listParns))
        let parn = a:listParns[i]
        "let pat = pat . anyChars
        let pat = pat . s:gAnyCharsPat
        if parn == s:ParnEnum_L
            let pat = pat . s:gLeftParn
        elseif parn == s:ParnEnum_R
            let pat = pat . s:gRightParn
        endif
    endfor

    call s:EndFnCall(fn)
    return pat
endfunction

" add match for a left parn closed by a wrong right parn
function! s:AddMatchForLeftParnWithWrongRightParn(listOfListParns)
    let fn = s:StartFnCall('AddMatchForLeftParnWithWrongRightParn')

    if len(a:listOfListParns) > 0
        for listParns in a:listOfListParns
            if has_key(s:gCurOldSyn, string(listParns))
                continue
            else
                let s:gCurOldSyn[string(listParns)] = 1
                call s:RunSynForLeftParnWithWrongRightParn(listParns)
            endif
        endfor
    endif

    call s:EndFnCall(fn)
endfunction

" add syn match for a left parn closed by a wrong right parn
function! s:RunSynForLeftParnWithWrongRightParn(listParns)
    let fn = s:StartFnCall('RunSynForLeftParnWithWrongRightParn')

    if len(a:listParns) > 1
        let pat = '/%s%s%s%s\&./'
        let pat2 = ''
        if len(a:listParns) > 2
            let pat2 = s:GetSynForListParn2(StdGetSubList(a:listParns, 1, len(a:listParns)-2))
        endif
        let syn = printf(pat, s:gLeftParn, pat2, s:gAnyCharsPat2, s:gAnyOtherRightPat)
        let syn = 'syntax match myMatch ' . syn
        "echom syn
        execute syn
    endif

    call s:EndFnCall(fn)
endfunction

" add syn match for a left parn without a right parn
function! s:RunSynForLeftParn(listParns)
    let fn = s:StartFnCall('RunSynForLeftParn')

    let pat = '/%s%s%s$\&./'
    let pat2 = ''
    if len(a:listParns) > 1
        let pat2 = s:GetSynForListParn(StdGetSubList(a:listParns, 1))
    endif
    let syn = printf(pat, s:gLeftParn, pat2, s:gAnyCharsPat)
    let syn = 'syntax match myMatch ' . syn
    "echom syn
    execute syn

    call s:EndFnCall(fn)
endfunction

" add syn match for a right parn without a left parn
function! s:RunSynForRightParn(listParns)
    let fn = s:StartFnCall('RunSynForRightParn')

    let pat = '/\(^%s%s\)\@<=%s/'
    let pat2 = ''
    if len(a:listParns) > 1
        let pat2 = s:GetSynForListParn(StdGetSubList(a:listParns, 0, len(a:listParns)-1))
    endif
    let syn = printf(pat, pat2, s:gAnyCharsPat, s:gRightParn)
    let syn = 'syntax match myMatch ' . syn
    "echom syn
    execute syn

    call s:EndFnCall(fn)
endfunction

" check if a given list parns is for left or right parn match
function! s:ShouldAddMatchForLeftOrRightParn(listParns)
    let fn = s:StartFnCall('ShouldAddMatchForLeftOrRightParn')
    if len(a:listParns) < 2

        call s:EndFnCall(fn)
        return a:listParns[0]
    endif
    let indexLast = len(a:listParns) - 1
    for i in range(len(a:listParns))
        if a:listParns[i] == a:listParns[indexLast-i]

            call s:EndFnCall(fn)
            return a:listParns[i]
        endif
    endfor

    call s:EndFnCall(fn)
    return s:ParnEnum_None
endfunction

" add match for a left parn without a right parn or a right parn without a left parn
function! s:AddMatchForLeftAndRightParn2(listOfListParns)
    let fn = s:StartFnCall('AddMatchForLeftAndRightParn2')

    if len(a:listOfListParns) > 0
        for listParns in a:listOfListParns
            " pass if there is already a match added
            if has_key(s:gCurOldSyn, string(listParns))
                continue
            else
                " add a new match
                let s:gCurOldSyn[string(listParns)] = 1
                let eParn = s:ShouldAddMatchForLeftOrRightParn(listParns)
                if eParn == s:ParnEnum_L
                    call s:RunSynForLeftParn(listParns)
                elseif eParn == s:ParnEnum_R
                    call s:RunSynForRightParn(listParns)
                endif
            endif
        endfor
    endif

    call s:EndFnCall(fn)
endfunction

" find the nearest left parn that is left-next to the current char
" which should be a right parn
function! s:FindNearestLeftParn()
    "call s:PlusOneFnCalled('FindNearestLeftParn')
    let line = getline('.')
    let line = strpart(line, 0, col('.')-1)

    let bFoundQuote = g:FALSE
    let nestedParns = 1
    for i in range(len(line)-1, 0, -1)
        let ch = line[i]

        if ch =~ '"' || ch =~ "'"
            let bFoundQuote = bFoundQuote == g:FALSE && g:TRUE
        endif

        if bFoundQuote == g:TRUE
            continue
        elseif s:IsAnyLeftParns(ch)
            let nestedParns = nestedParns - 1
        elseif s:IsAnyRightParns(ch)
            " if we find any right parn before we find a left parn
            " end this function immediately
            "if i < len(line)-1 && nestedParns == 0
                "return ''
            "endif
            let nestedParns = nestedParns + 1
        endif

        if nestedParns == 0
            if s:IsAnyOtherLeftParns(ch)
                return ch
            endif
            break
        endif
    endfor
    return ''
endfunction

" find matchings in given line
" this function will be called when opening a file and when user enters a parn
" TODO: we should find matching for given block of code, not actually a line of code
function! s:RunPmatchForLine(line)
    let fn = s:StartFnCall('RunPmatchForLine')

    "echom a:line
    let listParns = s:StrToListParns(a:line)
    "echom string(listParns)

    let listParns2 = s:ListParnsToListOfListParns2(listParns)
    
    " this only improve performance a little bit
    " to improve more, need to check the above function
    if !has_key(s:gOldListParns, string(listParns2))
        let s:gOldListParns[string(listParns2)] = 1
        "echom 'parns2:'.string(listParns2)
        call s:AddMatchForLeftAndRightParn2(listParns2)
        "call s:AddMatchForLeftAndRightParn(listParns1)
    endif

    let shouldMoveOn = g:TRUE
    
    " check if current parn is a wrong parn for a corresponding left parn
    if s:gMode == s:ModeEnum_Input && s:IsAnyRightParns(s:gCurChar)
        let left = s:FindNearestLeftParn()
        if len(left) > 0
            call s:SetGlobalVariablesForChar(left)
            let listParns = s:StrToListParns(a:line)
        else
            let shouldMoveOn = g:FALSE
        endif
    endif

    if shouldMoveOn
        let listParns2 = s:ListParnsToListOfListParns3(listParns)
        if !has_key(s:gOldListParns, string(listParns2))
            let s:gOldListParns[string(listParns2)] = 1
            "echom 'parns3:'.string(listParns2)
            call s:AddMatchForLeftParnWithWrongRightParn(listParns2)
            "call s:AddMatchForUnmatchedLeftAndRightParns(listParns)
        endif
    endif

    call s:EndFnCall(fn)
endfunction

" set the global variables, this must be called first before pmatch
" tries to parse the input
" note functions depend on these values to work properly
function! s:SetGlobalVariablesForChar(ch)
    let fn = s:StartFnCall('SetGlobalVariableForChar')

    " set the char the user just enter
    let s:gCurChar = a:ch

    " get the char for pmatch to work on
    let leftParn = s:gMatches[a:ch][s:MatchKey_L]
    let s:gLeftParn = s:CheckAndEscapeChar(leftParn)
    let s:gRightParn = s:CheckAndEscapeChar(s:gMatches[a:ch][s:MatchKey_R])
    "echom 'left(' . s:gLeftParn . ') right(' . s:gRightParn . ')'

    " set the current old syn to check
    let s:gCurOldSyn = s:gOldSyns[leftParn]

    call s:SetGlobalVariablesForCurParn()

    call s:EndFnCall(fn)
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
    let fn = s:StartFnCall('RunPmatchWhenOpenFile')

    let s:gMode = s:ModeEnum_Auto

    call s:SetGlobalVariables()
    let listLines = StdGetListOfLinesOfCurrentFile()

    for leftParn in keys(s:gOldSyns)
        call s:SetGlobalVariablesForChar(leftParn)
        for i in range(len(listLines))
            call s:RunPmatchForLine(listLines[i])
        endfor
    endfor
    let s:gMode = s:ModeEnum_Input

    call s:EndFnCall(fn)
    call s:ShowFnCalled()
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

"echom s:GetTime() - s:GetTime()
