" key word auto completion

function AUTOCOMPLETE_init()
    let b:listKeywords = []
    let b:currentWord = ""
    let b:bFindKeyword = 0
    let l:tokens = GetListOfTokensOfCurrentFile()
    let l:bFindVariable = 0
    for i in range(len(l:tokens))
        if l:tokens[i] == "var"
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

function AUTOCOMPLETE_ClearCurrentWord()
    let b:currentWord = ""
endfunction

function AUTOCOMPLETE_AddCharToWord(ch)
    let b:currentWord .= a:ch
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
        if AUTOCOMPLETE_IsWordEmpty()
            return []
        else
            return AUTCOMPLETE_GetWordList()
        endif
    endif
endfunction

function AUTOCOMPLETE_FeedKey(key)
    "echom "AUTOCOMPLETE_FeedKey: get key:" . a:key
    if a:key !~ '\s'
        call AUTOCOMPLETE_AddCharToWord(a:key)
    else
        if AUTOCOMPLETE_IsCurrentWord("var") || AUTOCOMPLETE_IsCurrentWord("function")
            call AUTOCOMPLETE_FindKeyword(g:TRUE)
        elseif AUTOCOMPLETE_DoesFindKeyword()
            call AUTOCOMPLETE_AddWordToWordList()
            call AUTOCOMPLETE_FindKeyword(g:FALSE)
        endif
        call AUTOCOMPLETE_ClearCurrentWord()
    endif
    return a:key
endfunction

function AUTOCOMPLETE_RegisterKeyMapForPmenu()
    "navigate on the popup menu
    execute "inoremap <C-h> <C-n>"

    "exit the popup menu
endfunction

function AUTOCOMPLETE_RegisterKeyMap()
    let l:listKeys = [
        \ 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k',
        \ 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v',
        \ 'w', 'x', 'y', 'z',
        \ 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K',
        \ 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V',
        \ 'W', 'X', 'Y', 'Z',
        \ '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '0',
        \ '<space>']
    for key in l:listKeys
        let l:ShowPopupAndOriginalWord = "<C-x><C-u><C-n><C-p>"
        execute printf("inoremap <silent> %s <C-r>=AUTOCOMPLETE_FeedKey(\"%s\")<CR>%s", 
            \ key, key, l:ShowPopupAndOriginalWord)
    endfor
    "AUTCOMPLETE_RegisterKeyMapForPmenu()
endfunction

function AUTOCOMPLETE_InsertToNormal()
    if !AUTOCOMPLETE_IsWordEmpty() && AUTOCOMPLETE_DoesFindKeyword()
        call AUTOCOMPLETE_AddWordToWordList()
        call AUTOCOMPLETE_Reinit()
    endif
endfunction

call AUTOCOMPLETE_init()
call AUTOCOMPLETE_RegisterKeyMap()
set completefunc=AUTOCOMPLETE_CompleteFunction
set completeopt=longest,menuone
"au CursorMovedI * call printf("%s", "ihello")
au BufRead * call AUTOCOMPLETE_init()

highlight Pmenu ctermfg=white ctermbg=green
highlight PmenuSel ctermfg=white ctermbg=brown
