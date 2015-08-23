" key word auto completion

let b:AUTOCOMPLETE_eKey = {
    \ 'space' : "\<space>",
    \ 'bs' : "\<bs>"
    \ }

function AUTOCOMPLETE_init()
    let b:listKeywords = []
    let b:currentWord = ""
    let b:bFindKeyword = 0
    let l:tokens = GetListOfTokensOfCurrentFile()
    let l:bFindVariable = 0
    for i in range(len(l:tokens))
        if l:tokens[i] == "var" || l:tokens[i] == "function"
            let l:bFindVariable = 1
        elseif l:bFindVariable
            let b:listKeywords = add(b:listKeywords, l:tokens[i])
            let l:bFindVariable = 0
        endif
    endfor
    "echom GetListAsString(l:tokens)
    "echom "AUTOCOMPLETE_init():" . GetListAsString(b:listKeywords)
endfunction

function AUTOCOMPLETE_Reinit()
    let b:currentWord = ""
    let b:bFindKeyword = 0
endfunction

function AUTOCOMPLETE_IsWordEmpty()
    return IsEmptyString(b:currentWord)
endfunction

function AUTOCOMPLETE_IsCurrentWord(keyword)
    return b:currentWord == a:keyword
endfunction

function AUTOCOMPLETE_GetCurrentWord()
    return b:currentWord
endfunction

function AUTOCOMPLETE_ClearCurrentWord()
    let b:currentWord = ""
endfunction

function AUTOCOMPLETE_SetCurrentWord(word)
    let b:currentWord = a:word
    echom "AUTOCOMPLETE_SetCurrentWord():".b:currentWord
endfunction

function AUTOCOMPLETE_AddCharToWord(ch)
    let b:currentWord .= a:ch
endfunction

function AUTOCOMPLETE_RemoveCharFromWord(pos)
    echom "RemoveCharFromWord():before:".b:currentWord.";remove:".a:pos
    let l:firstPart = strpart(b:currentWord, 0, a:pos)
    let l:secondPart = strpart(b:currentWord, a:pos+1)
    let b:currentWord = l:firstPart . l:secondPart
    echom "RemoveCharFromWord():pos(".a:pos."):".b:currentWord
endfunction

function AUTOCOMPLETE_FoundNewWord()
    let b:listKeywords = add(b:listKeywords, b:currentWord)
    "echom "AUTOCOMPETE_FoundNewWord(): add new word:" . b:currentWord
    let b:currentWord = ""
endfunction

function AUTOCOMPLETE_AddWordToWordList()
    let b:listKeywords = add(b:listKeywords, b:currentWord)
    let b:currentWord = ""
    "echom "AUTCOMPLETE_AddWordToWordList:" . GetListAsString(b:listKeywords)
endfunction

function AUTOCOMPLETE_FindKeyword(bFound)
    let b:bFindKeyword = a:bFound
endfunction

function AUTOCOMPLETE_IsKeyword(key)
    for i in range(len(b:listKeywords))
        if b:listKeywords[i] =~ a:key
            return g:TRUE
    endfor
    return g:FALSE
endfunction

function AUTOCOMPLETE_DoesFindKeyword()
    if b:bFindKeyword && b:currentWord =~ '^\a'
        return g:TRUE
    else
        return g:FALSE
    endif
endfunction

function AUTCOMPLETE_GetWordList()
    let l:listMatchedWords = []
    for i in range(len(b:listKeywords))
        let l:mat = match(b:listKeywords[i], '^'.b:currentWord)
        "echom "AUTOCOMPLETE_GetWordList:".b:currentWord
        "echom "AUTOCOMPLETE_GetWordList:match:[".b:listKeywords[i].",^".b:currentWord."(".mat.")"
        if l:mat == 0
            let l:listMatchedWords = add(l:listMatchedWords, b:listKeywords[i])
        endif
    endfor
    "echom "AUTOCOMPLETE_GetWordList():" . GetListAsString(l:listMatchedWords)
    return l:listMatchedWords
endfunction

function AUTOCOMPLETE_CompleteFunction(findstart, base)
    if a:findstart
        let l:startPos = GetStartPosOfCurrentWord() + 1
        return l:startPos
    else
        echom "AUTOCOMPLETE_CompleteFunction():base:".a:base
        if AUTOCOMPLETE_IsWordEmpty()
            return []
        else
            return AUTCOMPLETE_GetWordList()
        endif
    endif
endfunction

function AUTOCOMPLETE_FeedKey(key)
    "echom "AUTOCOMPLETE_FeedKey: get key:" . a:key
    let l:retKey = get(b:AUTOCOMPLETE_eKey, a:key, a:key)
    if a:key =~ 'bs'
        let l:pos = col('.')-2 - GetStartPosOfCurrentWord()
        call AUTOCOMPLETE_RemoveCharFromWord(l:pos)
    elseif a:key =~ 'space'
        if AUTOCOMPLETE_IsCurrentWord("var") || AUTOCOMPLETE_IsCurrentWord("function")
            call AUTOCOMPLETE_FindKeyword(g:TRUE)
        elseif AUTOCOMPLETE_DoesFindKeyword()
            call AUTOCOMPLETE_AddWordToWordList()
            call AUTOCOMPLETE_FindKeyword(g:FALSE)
        endif
        call AUTOCOMPLETE_ClearCurrentWord()
    else
        call AUTOCOMPLETE_AddCharToWord(a:key)
    endif
    echom "AUTOCOMPLETE_FeedKey: current word:".b:currentWord 
    return l:retKey 
endfunction

function AUTOCOMPLETE_RegisterKeyMapForPmenu()
    "navigate on the popup menu
    execute "inoremap <C-h> <C-n>"

    "exit the popup menu
endfunction

function AUTOCOMPLETE_PostModifierHandler()
    call AUTOCOMPLETE_SetCurrentWord(GetWordAtCursor())
endfunction

function AUTOCOMPLETE_RegisterSpecialKeyMap()
    let l:specialKeys = ['x']
    let l:strMap = 'nnoremap <silent> %s '.
        \ ':call AUTOCOMPLETE_SetCurrentWord(GetWordAtCursor())<CR>'.
        \ '%s'.
        \ ':call AUTOCOMPLETE_PostModifierHandler()<CR>'
    for i in range(len(l:specialKeys))
        let l:key = l:specialKeys[i]
        execute printf(l:strMap, l:key, l:key)
    endfor
endfunction

function AUTOCOMPLETE_RegisterKeyMap()
    let l:listKeys = [
        \ 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k',
        \ 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v',
        \ 'w', 'x', 'y', 'z',
        \ 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K',
        \ 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V',
        \ 'W', 'X', 'Y', 'Z',
        \ '0', '1', '2', '3', '4', '5', '6', '7', '8', '9']
    let l:listSpecialKeys = ['space', 'bs']
    let l:ShowPopupAndOriginalWord = "<C-x><C-u><C-n><C-p>"
    let l:strMap = "inoremap <silent> %s <C-r>=AUTOCOMPLETE_FeedKey('%s')<CR>%s" 
    for k in l:listKeys
        "echom printf(l:strMap, k, k, l:ShowPopupAndOriginalWord)
        execute printf(l:strMap, k, k, l:ShowPopupAndOriginalWord)
    endfor
    for sk in l:listSpecialKeys
        let l:key = '<'.sk.'>'
        "echom printf(l:strMap, l:key, sk, l:ShowPopupAndOriginalWord)
        execute printf(l:strMap, l:key, sk, l:ShowPopupAndOriginalWord)
    endfor
    "AUTCOMPLETE_RegisterKeyMapForPmenu()
    call AUTOCOMPLETE_RegisterSpecialKeyMap()
endfunction

function AUTOCOMPLETE_InsertLeaveHandler()
    "echom "AUTOCOMPLETE_InsertLeaveHandler():before leave:".b:currentWord
    if !AUTOCOMPLETE_IsWordEmpty() && AUTOCOMPLETE_DoesFindKeyword()
        call AUTOCOMPLETE_AddWordToWordList()
    endif
    call AUTOCOMPLETE_Reinit()
    "echom "AUTOCOMPLETE_InsertLeaveHandler():after leave:".b:currentWord
endfunction

function AUTOCOMPLETE_InsertEnterHandler()
    let l:word = GetWordAtCursor()
    "echom "AUTOCOMPLETE_InsertEnterHandler():before enter:".b:currentWord
    call AUTOCOMPLETE_SetCurrentWord(l:word) 
    "echom "AUTOCOMPLETE_InsertEnterHandler():after enter:".b:currentWord
endfunction

call AUTOCOMPLETE_init()
call AUTOCOMPLETE_RegisterKeyMap()
set completefunc=AUTOCOMPLETE_CompleteFunction
set completeopt=longest,menuone
au BufRead * call AUTOCOMPLETE_init()
au InsertEnter * call AUTOCOMPLETE_InsertEnterHandler()
au InsertLeave * call AUTOCOMPLETE_InsertLeaveHandler()

highlight Pmenu ctermfg=white ctermbg=green
highlight PmenuSel ctermfg=white ctermbg=brown
