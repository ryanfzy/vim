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

let s:ParnEnum_LoR = 8
let s:ParnEnum_LoRo = 9

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

let s:gAnyOtherChar = ''
let s:gAnyLeft = ''
let s:gAnyRight = ''
let s:gAnyOtherRightPat = ''

""""""""""""""""""""""""""""""""""""""""""""""""""""
" debug code
""""""""""""""""""""""""""""""""""""""""""""""""""""
let s:gNumFnCalled = {}
let s:gTmFnCalled = {}
let s:gShowFnCall = g:TRUE

function! s:GetTime()
    "return system('date +%s%N') / 1000000
    return localtime()
endfunction

function! s:StartFnCall(fnName)
    if s:gShowFnCall == g:TRUE
        let fn = {}
        let fn['name'] = a:fnName
        let fn['tmStart'] = s:GetTime()
        return fn
    endif
    return 0
endfunction

function! s:EndFnCall(fn)
    if s:gShowFnCall == g:TRUE
        let time = s:GetTime() - a:fn['tmStart']
        let name = a:fn['name']
        if has_key(s:gNumFnCalled, name)
            let s:gNumFnCalled[name] += 1
            let s:gTmFnCalled[name] += time
        else
            let s:gNumFnCalled[name] = 1
            let s:gTmFnCalled[name] = time
        endif
    endif
endfunction

function! s:ShowFnCalled()
    if s:gShowFnCall == g:TRUE
        for key in keys(s:gNumFnCalled)
            echom key . ':' . s:gNumFnCalled[key] . '-' . s:gTmFnCalled[key]
        endfor
    endif
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""

function! s:SetGlobalVariables()
    let fn = s:StartFnCall('SetGlobalVariables')

    let s:gAllLefts = s:GetAllLeftOrRightParns(s:MatchKey_L, g:FALSE, g:TRUE)
    let s:gAllRights = s:GetAllLeftOrRightParns(s:MatchKey_R, g:FALSE, g:TRUE)

    let s:gAnyOtherChar = printf(s:gAnyCharsPatT, s:gAllLefts, s:gAllRights)

    " this fixes ( is hilighted in (\)
    let s:gAllLefts = s:GetAllLeftOrRightParns(s:MatchKey_L, g:FALSE, g:FALSE)

    let s:gAnyLeft = printf(s:gAnyCharsPatT2, s:gAllLefts)
    let s:gAnyRight = printf(s:gAnyCharsPatT2, s:gAllRights)

    call s:EndFnCall(fn)
endfunction

function! s:SetGlobalVariablesForCurParn()
    let fn = s:StartFnCall('SetGlobalVariablesForCurParn')
    
    let s:gAllOtherLefts = s:GetAllLeftOrRightParns(s:MatchKey_L, g:TRUE, g:TRUE)
    let s:gAllOtherRights = s:GetAllLeftOrRightParns(s:MatchKey_R, g:TRUE, g:TRUE)

    let s:gAnyOtherRightPat = printf(s:gAnyCharsPatT2, s:gAllOtherRights)

    call s:EndFnCall(fn)
endfunction

function! s:ReturnParnEnumNoneFn(parm)
    return s:ParnEnum_None 
endfunction

" this will not escape the left and right parn char
function! s:GetAllLeftOrRightParns(leftOrRight, excludeCurOne, shouldEscapeChar)
    let fn = s:StartFnCall('GetAllLeftOrRightParns')

    let keys = keys(s:gMatches)
    let keysAsStr = ''
    for key in keys
        let leftOrRightParn = s:CheckAndEscapeChar(s:gMatches[key][a:leftOrRight], a:shouldEscapeChar)
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
function! s:CheckAndEscapeChar(ch, shouldEscapeChar)
    let fn = s:StartFnCall('CheckAndEscapeChar')

    if len(a:ch) > 0 && a:shouldEscapeChar == g:TRUE && stridx(s:gCharsToEscape, a:ch) > -1
        return '\' . a:ch
    endif

    call s:EndFnCall(fn)
    return a:ch
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

let s:gParnToNum = {}
let s:gNullNode = 100

" convert a string to a list of parns
" e.g. '([])' => [0,2,3,1]
function! s:StrToListParns(line)
    let fn = s:StartFnCall('StrToListParns')
    let parns = []
    for i in range(len(a:line))
        let ch = a:line[i]
        if has_key(s:gParnToNum, ch)
            let parns = add(parns, s:gParnToNum[ch])
        endif
    endfor
    call s:EndFnCall(fn)
    return parns
endfunction

" convert a list of parns to another list of parns respect to current parn
" e.g. [0,2,3,1] if parn = (0,1) => [0,3,4,1]
function! s:ConvertParns(parns)
    let fn = s:StartFnCall('ConvertParns')
    let lp = len(s:gLeftParn) > 1 ? s:gLeftParn[1] : s:gLeftParn
    let rp = len(s:gRightParn) > 1 ? s:gRightParn[1] : s:gRightParn
    let lnum = s:gParnToNum[lp]
    let rnum = s:gParnToNum[rp]

    let ret = []
    for parn in a:parns
        if parn == lnum
            let ret = add(ret, s:ParnEnum_L)
        elseif parn == rnum
            let ret = add(ret, s:ParnEnum_R)
        else
            let ret = add(ret, parn % 2 == 0 ? s:ParnEnum_Lo : s:ParnEnum_Ro)
        endif
    endfor
    call s:EndFnCall(fn)
    return ret
endfunction

function! s:CreateNullNode()
    let node = {}
    let node['value'] = s:gNullNode
    return node
endfunction

function! s:CreateNode(value)
    let node = {}
    let node['value'] = a:value
    let node['parent'] = s:CreateNullNode()
    let node['children'] = []
    return node
endfunction

function! s:IsNullNode(node)
    return a:node['value'] == s:gNullNode
endfunction

function! s:AddChild(node, childValue)
    let child = s:CreateNode(a:childValue)
    let child['parent'] = a:node
    let a:node['children'] = add(a:node['children'], child)
endfunction

function! s:EchomTrees(trees)
    let ret = []
    for tree in trees
        let ret = extend(ret, s:EchomTree(tree, 0))
    endfor
    echom 'tree:'.string(ret)
endfunction

" print a tree
function! s:EchomTree(node, depth)
    let ret = [string(a:depth).':'.string(a:node['value'])]
    if len(a:node['children']) > 0
        for child in a:node['children']
            let ret = extend(ret, s:EchomTree(child, a:depth+1))
        endfor
    endif
    return ret
endfunction

" convert a tree to a list of parn
function! s:ConvertTree(tree, firstCall)
    let ret = []
    let parn = a:tree['value']

    if parn == s:ParnEnum_LR || parn == s:ParnEnum_LRo || parn == s:ParnEnum_LoRo || parn == s:ParnEnum_LoR
        if a:firstCall == g:TRUE && parn == s:ParnEnum_LRo
            let ret = add(ret, s:ParnEnum_L)
        else
            let ret = add(ret, s:ParnEnum_La)
        endif
    elseif parn == s:ParnEnum_L || parn == s:ParnEnum_Lo
        let ret = add(ret, s:ParnEnum_La)
    elseif parn == s:ParnEnum_R || parn == s:ParnEnum_Ro
        let ret = add(ret, s:ParnEnum_Ra)
    endif

    if len(a:tree['children']) > 0
        for child in a:tree['children']
            let ret = extend(ret, s:ConvertTree(child, g:FALSE))
        endfor
    endif

    if parn == s:ParnEnum_LR || parn == s:ParnEnum_LRo || parn == s:ParnEnum_LoRo || parn == s:ParnEnum_LoR
        if a:firstCall == g:TRUE && parn == s:ParnEnum_LRo
            let ret = add(ret, s:ParnEnum_Ro)
        else
            let ret = add(ret, s:ParnEnum_Ra)
        endif
    endif

    return ret
endfunction

" conver a list of tree to a list of parn
function! s:ConvertTrees(trees)
    let fn = s:StartFnCall('ConvertTrees')
    let retList = []
    let retList2 = []
    for index in range(len(a:trees))
        let tree = a:trees[index]
        " for case ())
        if tree['value'] == s:ParnEnum_R
            if index == 0
                let retList2 = add(retList2, [s:ParnEnum_R])
            else
                let ret = add(s:DoConvertTrees(a:trees, 0, index-1), s:ParnEnum_R)
                let retList2 = add(retList2, ret)
            endif
        " for case (()
        elseif tree['value'] == s:ParnEnum_L
            let ret = s:DoConvertTrees(a:trees, index, len(a:trees)-1)
            if len(ret) > 0
                let retList = add(retList, ret)
            endif
        " for case (()]
        elseif tree['value'] == s:ParnEnum_LRo
            let ret = s:ConvertTree(tree, g:TRUE)
            if len(ret) > 0
                let retList = add(retList, ret)
            endif
        endif
        if len(tree['children']) > 0
            let retList3 = s:ConvertTrees(tree['children'])
            if len(retList3) > 0
                let retList2 = extend(retList2, retList3)
            endif
        endif
    endfor
    call s:EndFnCall(fn)
    return extend(retList, retList2)
endfunction

function! s:DoConvertTrees(trees, startIndex, endIndex)
    let rets = []
    for index in range(a:startIndex, a:endIndex)
        let isFirst = index == a:startIndex ? g:TRUE : g:FALSE
        let tree = a:trees[index]
        if tree['value'] == s:ParnEnum_L
            if isFirst == g:TRUE
                let parns = [s:ParnEnum_L]
            else
                let parns = [s:ParnEnum_La]
            endif
            if len(tree['children']) > 0
                for child in tree['children']
                    let parns = extend(parns, s:ConvertTree(child, g:FALSE))
                endfor
            endif
            let rets = extend(rets, parns)
        elseif tree['value'] == s:ParnEnum_R || tree['value'] == s:ParnEnum_Ro
            let rets = add(rets, s:ParnEnum_Ra)
        elseif tree['value'] == s:ParnEnum_LR || tree['value'] == s:ParnEnum_LoR || tree['value'] == s:ParnEnum_LRo || tree['value'] == s:ParnEnum_LoRo
            let rets = extend(rets, s:ConvertTree(tree, g:FALSE))
        endif
    endfor
    return rets
endfunction

" conver a list of parn to a list of tree
function! s:ConvertParns2(parns)
    let fn = s:StartFnCall('ConvertParns2')
    let trees = []
    let root = s:CreateNode(s:gNullNode)
    for parn in a:parns
        "if parn == s:ParnEnum_L || parn == s:ParnEnum_R
        if s:IsNullNode(root)
            let node = s:CreateNode(parn)
            let trees = add(trees, node)
            if parn == s:ParnEnum_L || parn == s:ParnEnum_Lo
                let root = node
            endif
        elseif parn == s:ParnEnum_R
            if root['value'] == s:ParnEnum_L
                let root['value'] = s:ParnEnum_LR
                let root = root['parent']
            elseif root['value'] == s:ParnEnum_Lo
                let root['value'] = s:ParnEnum_LoR
                let root = root['parent']
            endif
        elseif parn == s:ParnEnum_Ro
            if root['value'] == s:ParnEnum_L
                let root['value'] = s:ParnEnum_LRo
                let root = root['parent']
            elseif root['value'] == s:ParnEnum_Lo
                let root['value'] = s:ParnEnum_LoRo
                let root = root['parent']
            endif
        elseif parn == s:ParnEnum_L || parn == s:ParnEnum_Lo
            call s:AddChild(root, parn)
            let root = root['children'][len(root['children'])-1]
        endif
        "endif
    endfor
    call s:EndFnCall(fn)
    return s:ConvertTrees(trees)
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

function! s:GetSynForListParn(listParns)
    let fn = s:StartFnCall('GetSynForListParn')

    let pat = ''
    for i in range(len(a:listParns))
        let parn = a:listParns[i]
        let pat = pat . s:gAnyOtherChar
        if parn == s:ParnEnum_L
            let pat = pat . s:gLeftParn
        elseif parn == s:ParnEnum_R
            let pat = pat . s:gRightParn
        elseif parn == s:ParnEnum_La
            let pat = pat . s:gAnyLeft
        elseif parn == s:ParnEnum_Ra
            let pat = pat . s:gAnyRight
        endif
    endfor

    call s:EndFnCall(fn)
    return pat
endfunction

" add syn match for a left parn closed by a wrong right parn
function! s:RunSynForLeftParnWithWrongRightParn(listParns)
    let fn = s:StartFnCall('RunSynForLeftParnWithWrongRightParn')

    if len(a:listParns) > 1
        let pat = '/%s%s%s%s\&./'
        let pat2 = ''
        if len(a:listParns) > 2
            let pat2 = s:GetSynForListParn(StdGetSubList(a:listParns, 1, len(a:listParns)-2))
        endif
        let syn = printf(pat, s:gLeftParn, pat2, s:gAnyOtherChar, s:gAnyOtherRightPat)
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
    let syn = printf(pat, s:gLeftParn, pat2, s:gAnyOtherChar)
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
    let syn = printf(pat, pat2, s:gAnyOtherChar, s:gRightParn)
    let syn = 'syntax match myMatch ' . syn
    "echom syn
    execute syn

    call s:EndFnCall(fn)
endfunction

" check if a given list parns is for left or right parn match
function! s:ShouldAddMatch(listParns)
    if len(a:listParns) > 1 && a:listParns[0] == s:ParnEnum_L && a:listParns[len(a:listParns)-1] == s:ParnEnum_Ro
        return s:ParnEnum_LRo
    elseif a:listParns[0] == s:ParnEnum_L
        return s:ParnEnum_L
    elseif a:listParns[len(a:listParns)-1] == s:ParnEnum_R
        return s:ParnEnum_R
    else
        return a:ParnEnum_None
    endif
endfunction

" add match for a left parn without a right parn or a right parn without a left parn
function! s:AddMatchForLeftAndRightParn(listOfListParns)
    let fn = s:StartFnCall('AddMatchForLeftAndRightParn')

    if len(a:listOfListParns) > 0
        for listParns in a:listOfListParns
            " pass if there is already a match added
            if has_key(s:gCurOldSyn, string(listParns))
                continue
            else
                " add a new match
                let s:gCurOldSyn[string(listParns)] = 1
                let eParn = s:ShouldAddMatch(listParns)
                if eParn == s:ParnEnum_L
                    call s:RunSynForLeftParn(listParns)
                elseif eParn == s:ParnEnum_R
                    call s:RunSynForRightParn(listParns)
                elseif eParn == s:ParnEnum_LRo
                    call s:RunSynForLeftParnWithWrongRightParn(listParns)
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
function! s:RunPmatchForLine(parns)
    let fn = s:StartFnCall('RunPmatchForLine')

    " when user type a right parn
    if s:gMode == s:ModeEnum_Input && s:IsAnyRightParns(s:gCurChar)
        let left = s:FindNearestLeftParn()
        if len(left) > 0
            call s:SetGlobalVariablesForChar(left)
        endif
    endif

    "echom 'start:'.string(a:parns)

    let listParns = s:ConvertParns(a:parns)
    "echom 'parns:'.string(listParns)

    let listParns3 = s:ConvertParns2(listParns)
    "echom 'new:'.string(listParns3)
    
    call s:AddMatchForLeftAndRightParn(listParns3)

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
    let s:gLeftParn = s:CheckAndEscapeChar(leftParn, g:TRUE)
    let s:gRightParn = s:CheckAndEscapeChar(s:gMatches[a:ch][s:MatchKey_R], g:TRUE)
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

    let parns = s:StrToListParns(line)

    " by default it is line based so pass the line here
    " TODO: pmatch should support block based, so matching will be
    "       work in a block of code instead of a line
    for leftParn in keys(s:gOldSyns)
        " set the global variables first
        call s:SetGlobalVariablesForChar(leftParn)
        call s:RunPmatchForLine(parns)
    endfor

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
    let lines = StdGetListOfLinesOfCurrentFile()

    let listParns = []
    for line in lines
        let parns = s:StrToListParns(line)
        if len(parns) > 0
            let listParns = add(listParns, parns)
        endif
    endfor

    for leftParn in keys(s:gOldSyns)
        call s:SetGlobalVariablesForChar(leftParn)
        for parns in listParns
            call s:RunPmatchForLine(parns)
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

            let s:gParnToNum[leftParn] = len(s:gParnToNum)
            let s:gParnToNum[rightParn] = s:gParnToNum[leftParn] + 1

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
" TODO
"Pmatch addMatch leftRight='
"Pmatch addMatch leftRight="
"Pmatch addMatch left=( right=) ignoreInLeftRight='
"Pmatch addMatch left=( right=) ignoreInLeftRight="

" run pmatch when opening a file
au BufRead * call <SID>RunPmatchWhenOpenFile()
