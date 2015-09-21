let b:bDebug = g:FALSE

" key word auto completion

let b:keys = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
let b:separators = "~`!@#$%^&*()_+-={}|[]\;':\"<>?,./ "

let b:AUTOCOMPLETE_eKey = {
    \ 'space' : "\<space>",
    \ 'bs' : "\<bs>"
    \ }

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
    "echom "RemoveCharFromWord():before:".b:currentWord.";remove:".a:pos
    let l:firstPart = strpart(b:currentWord, 0, a:pos)
    let l:secondPart = strpart(b:currentWord, a:pos+1)
    let b:currentWord = l:firstPart . l:secondPart
    "echom "RemoveCharFromWord():pos(".a:pos."):".b:currentWord
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

function AUTOCOMPLETE_ReplaceKeyword(oldKey, newKey)
    echom "AUTOCOMPLETE_ReplaceKeyword():oldkey:".a:oldKey.";newkey:".a:newKey
    echom "before:".GetListAsString(b:listKeywords)
    for i in range(len(b:listKeywords))
        if b:listKeywords[i] =~ a:oldKey
            call remove(b:listKeywords, i)
            let b:listKeyworts = add(b:listKeywords, a:newKey)
        endif
    endfor
    echom "after:".GetListAsString(b:listKeywords)
endfunction

function AUTOCOMPLETE_DoesFindKeyword()
    if b:bFindKeyword && b:currentWord =~ '^\a'
        return g:TRUE
    else
        return g:FALSE
    endif
endfunction

" get list of words starting with b:currentWord
function AUTCOMPLETE_GetWordList()
    echom "here"
    call Debug("AUTOCOMPLETE_GetWordList()")
    let l:listMatchedWords = []
    for i in range(len(b:listKeywords))
        if match(b:listKeywords[i], '^'.b:currentWord) == 0
            let l:listMatchedWords = add(l:listMatchedWords, b:listKeywords[i])
        endif
    endfor
    return l:listMatchedWords
endfunction


function AUTOCOMPLETE_FeedKey(key)
"    "echom "AUTOCOMPLETE_FeedKey: get key:" . a:key
"    let l:retKey = get(b:AUTOCOMPLETE_eKey, a:key, a:key)
"    if a:key =~ 'bs'
"        let l:pos = col('.')-2 - GetStartPosOfCurrentWord()
"        call AUTOCOMPLETE_RemoveCharFromWord(l:pos)
"    elseif a:key =~ 'space' || a:key =~ ';'
"        if AUTOCOMPLETE_IsCurrentWord("var") || AUTOCOMPLETE_IsCurrentWord("function")
"            echom "AUTOCOMPLETE_FindKeyword():find var or function"
"            call AUTOCOMPLETE_FindKeyword(g:TRUE)
"        elseif AUTOCOMPLETE_DoesFindKeyword()
"            echom "AUTOCOMPLETE_FindKeyword():find new word"
"            call AUTOCOMPLETE_AddWordToWordList()
"            call AUTOCOMPLETE_FindKeyword(g:FALSE)
"        endif
"        call AUTOCOMPLETE_ClearCurrentWord()
"    else
    "let l:wordsOfCurLine = GetListOfTokens(getline('.'))
    "let l:indexOfCurWord = len(l:wordsOfCurLine)-1
    "if AUTCOMPLETE_ShouldCallKeyWordHandlerFn(l:wordsOfCurLine, l:indexOfCurWord)
       call AUTOCOMPLETE_AddCharToWord(a:key)
    "endif
    return a:key
endfunction

function AUTOCOMPLETE_ClearKey(sep)
    call AUTOCOMPLETE_ClearCurrentWord()
    return a:sep
endfunction

function AUTOCOMPLETE_RegisterKeyMapForPmenu()
    "navigate on the popup menu
    execute "inoremap <C-h> <C-n>"

    "exit the popup menu
endfunction

"function AUTOCOMPLETE_PostModifierHandler()
"    let l:keyword = AUTOCOMPLETE_GetCurrentWord()
"    if AUTOCOMPLETE_IsKeyword(l:keyword)
"        call AUTOCOMPLETE_ReplaceKeyword(l:keyword, GetWordAtCursor())
"    endif
"    call AUTOCOMPLETE_Reinit()
"endfunction
"
"function AUTOCOMPLETE_RegisterSpecialKeyMap()
"    let l:specialKeys = ['x']
"    let l:strMap = 'nnoremap <silent> %s '.
"        \ ':call AUTOCOMPLETE_SetCurrentWord(GetWordAtCursor())<CR>'.
"        \ '%s'.
"        \ ':call AUTOCOMPLETE_PostModifierHandler()<CR>'
"    for i in range(len(l:specialKeys))
"        let l:key = l:specialKeys[i]
"        execute printf(l:strMap, l:key, l:key)
"    endfor
"endfunction

function AUTOCOMPLETE_RegisterKeyMap()
    call Debug("AUTOCOMPLETE_RegisterKeyMap()")

    let l:strMap = "inoremap <silent> %s <C-r>=%s('%s')<CR>%s" 
    let l:feedFn = "AUTOCOMPLETE_FeedKey"
    let l:ShowPopupAndOriginalWord = "<C-x><C-u><C-n><C-p>"
    for i in range(len(b:keys))
        let k = b:keys[i]
        execute printf(l:strMap, k, l:feedFn, k, l:ShowPopupAndOriginalWord)
    endfor

" we now only care about the alphanumeric keys
"    let l:clearFn = "AUTOCOMPLETE_ClearKey"
"    let l:listSeparators = [
"        \ '+', '-', '*', '/', '(', ')', '[', ']', '{', '}', ';', ' '
"        \ ]
"    for k in l:listSeparators
"        execute printf(l:strMap, k, ,l:clearFn, k, '');
"    endfor
"
"    let l:listSpecialKeys = ['space', 'bs']
"    for sk in l:listSpecialKeys
"        let l:key = '<'.sk.'>'
"        "echom printf(l:strMap, l:key, sk, l:ShowPopupAndOriginalWord)
"        execute printf(l:strMap, l:key, sk, l:ShowPopupAndOriginalWord)
"    endfor
"    "AUTCOMPLETE_RegisterKeyMapForPmenu()
"    "call AUTOCOMPLETE_RegisterSpecialKeyMap()
endfunction

function AUTOCOMPLETE_InsertLeaveHandler()
    echom "AUTOCOMPLETE_InsertLeaveHandler():before leave:".b:currentWord
    if !AUTOCOMPLETE_IsWordEmpty() && AUTOCOMPLETE_DoesFindKeyword()
        call AUTOCOMPLETE_AddWordToWordList()
    endif
    call AUTOCOMPLETE_Reinit()
    echom "AUTOCOMPLETE_InsertLeaveHandler():after leave:".b:currentWord
endfunction

function AUTOCOMPLETE_InsertEnterHandler()
    let l:word = GetWordAtCursor()
    "echom "AUTOCOMPLETE_InsertEnterHandler():before enter:".b:currentWord
    call AUTOCOMPLETE_SetCurrentWord(l:word) 
    "echom "AUTOCOMPLETE_InsertEnterHandler():after enter:".b:currentWord
endfunction

function AUTOCOMPLETE_Init()
    call Debug("AUTOCOMPLETE_Init()")
    " set global variables
    let b:listKeywords = []
    let b:currentWord = ""
    let b:bFindKeyword = 0

    " find the key words in existing file
    call AUTOCOMPLETE_RunFinder()

    " set key mapping
    call AUTOCOMPLETE_RegisterKeyMap()

endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function KeyWordHandler(keyWord)
    call Debug("KeyWordHandler()")
    if index(b:listKeywords, a:keyWord) == -1
        let b:listKeywords = add(b:listKeywords, a:keyWord)
    endif
    echom string(b:listKeywords)
endfunction

source ~/vim/autofinder.vim

Autocmpl AddKey identifier \a[\a\d]*
Autocmpl AddKey variable %(identifier) before=var|function
Autocmpl SetKeyWordHandler KeyWordHandler params=%(variable)

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

au BufRead *.js call AUTOCOMPLETE_Init()
"au InsertEnter *.js call AUTOCOMPLETE_InsertEnterHandler()
au InsertLeave *.js call AUTOCOMPLETE_InsertLeaveHandler()

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function AUTOCOMPLETE_CompleteFunction(findstart, base)
    if a:findstart
        "return the start pos of the word that needs to be replaced by autocomplete
        let l:startPos = GetStartPosOfCurrentWord(b:separators)
        return l:startPos
    else
        "return the list of words that matches the word
        if AUTOCOMPLETE_IsWordEmpty()
            return []
        else
            return AUTCOMPLETE_GetWordList()
        endif
    endif
endfunction

set completefunc=AUTOCOMPLETE_CompleteFunction
set completeopt=longest,menuone
highlight Pmenu ctermfg=white ctermbg=green
highlight PmenuSel ctermfg=white ctermbg=brown

nnoremap <C-i> :call AUTOCOMPLETE_SetCurrentWord(expand("<cword>"))<CR>:call AUTOCOMPLETE_AddWordToWordList()<CR>

