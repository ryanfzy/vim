let b:bDebug = g:FALSE

" key word auto completion

let b:keys = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
let b:separators = "\~\!\@\#\$\%\^\&\*\(\)\_\+\-\=\{\}\[\]\\;\'\:\"\<\>\?\,\.\/\<space>"

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

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" key stroke mappings
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" TODO: map autocomplete menu
function AUTOCOMPLETE_RegisterKeyMapForPmenu()
    "navigate on the popup menu
    execute "inoremap <C-h> <C-n>"

    "exit the popup menu
endfunction

" feed the word to autocomplete and 
" return the key user just typed to the buffer
function AUTOCOMPLETE_FeedAutoComplete(key)
    call Debug("AUTOCOMPLETE_FeedAutoComplete()")

    let l:part = strpart(getline('.'), 0, col('.')-1) . a:key
    let l:listWords = GetListOfTokens(l:part)
    let l:curWord = l:listWords[len(l:listWords)-1]
    
    call AUTOCOMPLETE_SetCurrentWord(l:curWord)
    return a:key
endfunction

function AUTOCOMPLETE_FeedKeyHandlerIfMatch(sep)
    call AUTOCOMPLETE_ClearCurrentWord()

    let l:part = strpart(getline('.'), 0, col('.')-1)
    let l:listWords = GetListOfTokens(l:part)
    let l:curIndex = len(l:listWords)-1

    let l:fullListWords = GetListOfTokens(getline('.'))
    call AUTOCOMPLETE_CallKeyWordHandlerFnIfMatch(l:fullListWords, l:curIndex)
    
    return a:sep
endfunction

function AUTOCOMPLETE_RegisterKeyMap()
    call Debug("AUTOCOMPLETE_RegisterKeyMap()")

    " map normal keys
    let l:strMap = "inoremap <silent> %s <C-r>=%s('%s')<CR>%s" 
    let l:autoFeedFn = "AUTOCOMPLETE_FeedAutoComplete"
    let l:ShowPopupAndOriginalWord = "<C-x><C-u><C-n><C-p>"
    for i in range(len(b:keys))
        let k = b:keys[i]
        execute printf(l:strMap, k, l:autoFeedFn, k, l:ShowPopupAndOriginalWord)
    endfor

    " map separator keys
    let l:khFeedFn = "AUTOCOMPLETE_FeedKeyHandlerIfMatch"
    for j in range(len(b:separators))
        let k = b:separators[j]
        if k =~ '\s'
            let k = "<space>"
        endif
        execute printf(l:strMap, k, l:khFeedFn, k, '')
    endfor

endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

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
endfunction

source ~/vim/autofinder.vim

Autocmpl AddKey identifier \a[\a\d]*
Autocmpl AddKey variable %(identifier) before=var|function
Autocmpl SetKeyWordHandler KeyWordHandler params=%(variable)

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" get list of words starting with b:currentWord
" TODO: support fuzzy lookup
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

au BufRead *.js call AUTOCOMPLETE_Init()
"au InsertEnter *.js call AUTOCOMPLETE_InsertEnterHandler()
au InsertLeave *.js call AUTOCOMPLETE_InsertLeaveHandler()

set completefunc=AUTOCOMPLETE_CompleteFunction
set completeopt=longest,menuone
highlight Pmenu ctermfg=white ctermbg=green
highlight PmenuSel ctermfg=white ctermbg=brown

"nnoremap <C-i> :call AUTOCOMPLETE_SetCurrentWord(expand("<cword>"))<CR>:call AUTOCOMPLETE_AddWordToWordList()<CR>

