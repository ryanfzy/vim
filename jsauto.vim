
"auto key params [^()]*
"auto key lamFn \<function\>\(%(params)\)
"auto key fn \<function\>\s+%(identifier)\(%(params)\)

"auto scope global
"auto scope function start=(%(lamFn)|%(fn))\s*\{ end=\}
"auto scope for for\([^\)]\)\{%(forBody)\}
"auto scope while while\([^\)]\)\{%(whileBody)\}


function AutoMockFn()
    echom "mock"
endfunction

let b:dictKeys = {}
let b:completeFn = function('AutoMockFn')
let b:keyWordHanlderFn = function('AutoMockFn')
let b:keyWordHandlerFnParams = ""

let b:words = []

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" AddKey command
function AUTOCOMPLETE_AddKeyCmd(params)
    call Debug("AUTOCOMPLETE_AddKeyCmd()")
    let l:key = a:params[0]
    let l:value = {}
    let l:value['value'] = a:params[1]
    if len(a:params) > 2
        for n in range(2, len(a:params)-1)
            let l:keyValue = split(a:params[n], '=')
            let l:value[l:keyValue[0]] = l:keyValue[1]
        endfor
    endif
    let b:dictKeys[l:key] = l:value
endfunction

" a user defined key is in format %(<key-name>)
function AUTOCOMPLETE_IsKey(key)
    call Debug("AUTCOMPLETE_IsKey:")
    let l:pat = '%(\a\+)'
    if match(a:key, l:pat) == 0
        return g:TRUE
    else
        return g:FALSE
    endif
endfunction

" get the <key-name> from %(<key-name>)
function AUTOCOMPLETE_StripKey(key)
    call Debug("AUTOCOMPLETE_StripKey()")
    return strpart(a:key, 2, len(a:key)-3)
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" SetKeyWordHandler command
function AUTOCOMPLETE_SetKeyWordHandlerCmd(params)
    call Debug("AUTOCOMPLETE_SetKeyWordHandlerCmd()")
    let l:fnName = a:params[0]
    let b:keyWordHandlerFn = function(l:fnName)

    let l:dictParams = AUTOCOMPLETE_GetArgsDict(GetSubList(a:params, 1))
    let b:keyWordHandlerFnParams = l:dictParams['params']
endfunction

function AUTOCOMPLETE_Match(word, pat)
    call Debug("AUTOCOMPLETE_Match()")
    if match(a:word, a:pat) == 0
        return g:TRUE
    else
        return g:FALSE
    endif
endfunction

function AUTOCOMPLETE_CheckWord(listWords, index, key)
    call Debug("AUTOCOMPLETE_CheckWord()")
    if !AUTOCOMPLETE_IsKey(a:key)
        return AUTOCOMPLETE_CheckWordFromKeyDict(a:listWords, a:index, a:key)
    else
        let l:stripKey = AUTOCOMPLETE_StripKey(a:key)
        return AUTOCOMPLETE_CheckWord(a:listWords, a:index, l:stripKey)
    endif
endfunction

function AUTOCOMPLETE_CheckWordFromKeyDict(listWords, index, key)
    call Debug("AUTOCOMPLETE_CheckWordFromKeyDict()")
    let l:dictValue = b:dictKeys[a:key]
    let l:value = l:dictValue['value']
    let l:word = a:listWords[a:index]
    if AUTOCOMPLETE_IsKey(l:value)
        let l:stripKey = AUTOCOMPLETE_StripKey(l:value)
        if !AUTOCOMPLETE_CheckWordFromKeyDict(a:listWords, a:index, l:stripKey)
            return g:FALSE
        endif
    elseif !AUTOCOMPLETE_Match(l:word, l:value)
        return g:FALSE
    endif
    if has_key(l:dictValue, 'before')
        " first word doesn't have before word
        if a:index < 1
            return g:FALSE
        endif
        let l:beforeValue = l:dictValue['before']
        let l:beforeWord = a:listWords[a:index-1]
        if !AUTOCOMPLETE_Match(l:beforeWord, l:beforeValue)
            return g:FALSE
        endif
    endif
    return g:TRUE
endfunction

function AUTOCOMPLETE_GetArgsDict(listArgs)
    call Debug("AUTOCOMPLETE_GetArgsDict()")
    let l:dictArgs = {}
    for arg in a:listArgs
        let l:args = split(arg, '=')
        let l:dictArgs[l:args[0]] = l:args[1]
    endfor
    return l:dictArgs
endfunction

" validate each param in param list of the complete function
" if a param is %(<param-name>), we just check if <param-name> is a valid key
" if a param is native, we check if it same as <current-word>
function AUTOCOMPLETE_ValidateKey(key)
    call Debug("AUTOCOMPLETE_ValidateKey()")
    if AUTOCOMPLETE_IsKey(a:key)
        let l:stripKey = AUTOCOMPLETE_StripKey(a:key)
        return AUTOCOMPLETE_ValidateKeyInDict(l:stripKey)
    elseif AUTOCOMPLETE_GetCurrentWord() =~ a:key
        return g:TRUE
    endif
    return g:FALSE
endfunction

function AUTOCOMPLETE_ValidateKeyInDict(key)
    call Debug("AUTOCOMPLETE_ValidateKeyInDict()")
    " get the value of the <key> in key dictionary
    let l:value = b:dictKeys[a:key]['value']
    if AUTCOMPLETE_IsKey(l:value)
        let l:stripKey = AUTOCOMPLETE_StripKey(a:key)
        return AUTOCOMPLETE_ValidateKeyInDict(l:stripKey)
    elseif !has_key(b:dictKeys, a:key)
        return g:FALSE
    endif
endfunction

" check we should call the complete function
function AUTCOMPLETE_ShouldCallCompleteFn()
    call Debug("AUTOCOMPLETE_ShouldCallCompleteFn()")
    let l:curWord = AUTOCOMPLETE_GetCurrentWord()
    for n in b:listCompleteFnParams
        if !AUTOCOMPLETE_ValidateKey(n)
            return g:FALSE
        endif
    endfor
    return g:TRUE
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"control function, it parse the argument list and
"call respective command
function AUTOCOMPLETE_CmdProcessor(args)
    call Debug("AUTOCOMPLETE_CmdProcessor()")
    let l:listArgs = split(a:args)
    let l:cmd = l:listArgs[0]
    let l:params = GetSubList(l:listArgs, 1)
    if l:cmd =~ "AddKey"
        call AUTOCOMPLETE_AddKeyCmd(l:params)
    elseif l:cmd =~ "SetKeyWordHandler"
        call AUTOOCMPLETE_SetKeyWordHandlerCmd(l:params)
    endif
endfunction

function AUTOCOMPLETE_Run()
    call Debug("AUTOCOMPLETE_Run()")
    let l:listWords = GetListOfTokensOfCurrentFile()

    " run key word handler
    let l:param = b:keyWordHandlerFnParams
    for n in range(len(l:listWords))
        if AUTOCOMPLETE_CheckWord(l:listWords, n, l:param)
            call b:keyWordHandlerFn(l:listWords[n])        
        endif
    endfor
endfunction

function KeyWordHandler(keyword)
    "echom "KeyWordHandler:".a:keyword
    let b:words = add(b:words, a:keyword)
endfunction

command -narg=+ Autocmpl :call AutocompleteCommand(<q-args>)

Autocmpl AddKey identifier \a[\a\d]*
Autocmpl AddKey variable %(identifier) before=var
Autocmpl SetKeyWordHandler KeyWordHandler params=%(variable)
