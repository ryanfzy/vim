" author: ryan feng

if exists("g:loaded_stdlib")
    finish
endif
let g:loaded_stdlib = 1

let g:TRUE = 1
let g:FALSE = 0

"get the last char user just entered
"FIX: this function return the last charater on the current line
"   not the character the user just entered
"   we want the second case
"NOTE: we don't need this for out auto complete because we have
"   AUTOCOMPLETE_ReigsterKeyMap
function GetUserEnteredCharacter()
    let l:line = getline('.')
    let l:lastCh = line[strlen(line)-1]
    "echom "GetUserEnteredCharacter():" . l:lastCh
    return l:lastCh
endfunction

function GetStartPosOfCurrentWord(separators)
    let l:line = getline('.')
    let l:sPos = col('.')-1

    " cursor is just after a word
    " while loop ends when the word before the cursor is a space or a separator
    while l:sPos > 0 && line[l:sPos-1] !~ '\s' 
        if !IsEmptyString(a:separators) && match(a:separators, line[l:sPos-1]) == -1
            let l:sPos -= 1
        else
            break
        endif
    endwhile

    " cursor is after a space
    if l:sPos == col('.')-1
        let l:sPos = -1
    endif
    return l:sPos
endfunction

function IsEmptyString(str)
    let l:res = 1
    if strlen(a:str) > 0
        let l:res = 0
    elseif match(a:str, '^\s*$') == -1
        let l:res = 0
    endif
    "echom "IsEmptyString(" . a:str . "):" . l:res
    return l:res
endfunction

function GetListOfTokens(str)
    let l:listTokens = []
    let l:token = ""
    let l:idx = 0
    while l:idx < strlen(a:str)
        if a:str[l:idx] =~ '\s'
            if !IsEmptyString(l:token)
                let l:listTokens = add(l:listTokens, l:token)
                let l:token = ""
            endif
        elseif a:str[l:idx] =~ '\a' || a:str[l:idx] =~ '\d'
            let l:token = l:token . a:str[l:idx]
        else
            if !IsEmptyString(l:token)
                let l:listTokens = add(l:listTokens, l:token)
                let l:token = ""
            endif
            let l:listTokens = add(l:listTokens, a:str[l:idx])
        endif
        let l:idx += 1
    endwhile
    if !IsEmptyString(l:token)
        let l:listTokens = add(l:listTokens, l:token)
    endif
    return l:listTokens
endfunction

function GetListOfTokensOfCurrentFile()
    let l:lines = getbufline('.', 1, '$')
    let l:listTokens = []
    for i in range(len(l:lines))
        "echom "[".i."]".l:lines[i]
        if !IsEmptyString(l:lines[i])
            let l:listTokens = extend(l:listTokens, GetListOfTokens(l:lines[i]))
        endif
    endfor
    return l:listTokens
endfunction

function GetListAsString(list)
    return string(list)
"    let l:str = "["
"    let l:bFirstItem = g:TRUE
"    for item in a:list
"        if l:bFirstItem
"            let l:str = l:str . item
"            let l:bFirstItem = g:FALSE
"        else
"            let l:str = l:str . "," . item
"        endif
"    endfor
"    let l:str .= "]"
"    return l:str
endfunction

function GetWordAtCursor()
    return expand("<cword>")
endfunction

"GetSubList(<list>, startIndex {, count})
function GetSubList(list, start, ...)
    let l:end = len(a:list) - 1
    if a:start > l:end+1
        return []
    elseif a:0 == 1
        if a:1 < 1
            return []
        endif
        let l:end = a:start + a:1 -1
    endif
    let l:returnList = []
    for i in range(len(a:list))
        if i >= a:start && i <= l:end
            let l:returnList = add(l:returnList, a:list[i])
        endif
    endfor
    return l:returnList
endfunction

function GetWordsOnCurLine()
    let l:line = getline('.')
    return split(l:line, '\s+')
endfunction

" get pos of current word on current line
" FIX: for string "apple banana apple" if cursor under second apple
"   the pos of first apple will be returned
function GetPosOfWordOnCurLine()
    let l:word = GetWordAtCursor()
    let l:words = GetWordsOnCurLine()
    for n in range(l:words)
        if l:words[n] =~ l:word
            return n
        endif
    endfor
endfunction

" get word at offset relative to current word on current line
function GetWord(offset)
    if offset == 0
        return GetWordAtCursor()
    endif

    "let l:line = getline(.)
    "let l:listWord = split(l:line, '\s+')
    let l:listWords = GetWordsOnCurLine()
    let l:curPos = GetPosOfWordOnCurLine()
    let l:offsetPos = l:curPos + a:offset
    return l:listWord[l:offsetPos]
endfunction

function Debug(msg)
    if b:bDebug
        echom a:msg
    endif
endfunction

function IsAnyChar(ch, listChars)
    for chr in a:listChars
        if a:ch =~ chr
            return g:TRUE
        endif
    endfor
    return g:FALSE
endfunction

