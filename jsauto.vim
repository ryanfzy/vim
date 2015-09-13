
"auto key params [^()]*
"auto key lamFn \<function\>\(%(params)\)
"auto key fn \<function\>\s+%(identifier)\(%(params)\)

"auto scope global
"auto scope function start=(%(lamFn)|%(fn))\s*\{ end=\}
"auto scope for for\([^\)]\)\{%(forBody)\}
"auto scope while while\([^\)]\)\{%(whileBody)\}


function CompleteFn(variable)
    return ["abc", "bbc"]
endfunction

function AutoMockFn()
    echom "mock"
endfunction

let b:dictKeys = {}
let b:completeFn = function('AutoMockFn')
let b keyWordHanlderFn = function('AutoMockFn')
let b:listCompleteFnParams = []

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" AddKey command
function AutoComplAddKeyCmd(params)
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
    echom "AutoComplAddKeyCmd :".string(b:dictKeys)
endfunction

" a user defined key is in format %(<key-name>)
function AUTOCOMPLETE_IsKey(key)
    if a:key =~ '\%\((\d|\a)\)'
        return g:TRUE
    else
        return g:FALSE
    endif
endfunction

" get the <key-name> from %(<key-name>)
function AUTOCOMPLETE_StripKey(key)
    return strpart(a:key, 2, len(a:key)-3)
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" SetKeyWordHandler command
function AutoComplSetKeyWordHandlerCmd(params)
    let l:fnName = a:params[0]
    let l:dictParams = AUTOCOMPLETE_GetArgsDict(GetSubList(a:params, 1))
    let l:param = l:dictParams['params']

    if !AUTOCOMPLETE_IsKey(l:param)
        return
    endif

    let b:keyWordHandlerFn = function(l:fnName)
    let l:listWords = GetListOfTokensOfCurrentFile()
    for n in range(len(l:listWords))
        if AUTOCOMPLETE_CheckWord(l:listWords, n, l:param)
            call b:keyWordHandler(l:listWords[n])        
        endif
    endfor
    "echom "AutoCmplSetCompleteFunctionCmd:".string(b:listCompleteFnParams)
endfunction

function AUTOCOMPLETE_CheckWord(listWords, index, key)
    let l:word = a:listWords[a:index]
    if !AUTOCOMPLETE_IsKey(a:key)
        let l:dictValue = b:dictKeys[a:key]
        let l:value = l:dictValue['value']
        if !AUTOCOMPLETE_Match(l:word, l:value)
            return g:FALSE
        elseif has_key(l:dictValue, 'before')
            let l:beforeValue = l:dictValue['before']
            let l:beforeWord = a:listWords[a:index]
            if !AUTOCOMPLETE_Match(l:beforeWord, l:beforeValue)
                return g:FALSE
            endif
        endif
        return g:TRUE
    else
        let l:stripKey = AUTOCOMPELTE_StripKey(a:key)
        " TODO get recursion works
    endif
endfunction

function AUTOCOMPLETE_GetArgsDict(listArgs)
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
    if AUTOCOMPLETE_IsKey(a:key)
        let l:stripKey = AUTOCOMPLETE_StripKey(a:key)
        return AUTOCOMPLETE_ValidateKeyInDict(l:stripKey)
    elseif AUTOCOMPLETE_GetCurrentWord() =~ a:key
        return g:TRUE
    endif
    return g:FALSE
endfunction

function AUTOCOMPLETE_ValidateKeyInDict(key)
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
function AutocompleteCommand(args)
    let l:listArgs = split(a:args)
    let l:cmd = l:listArgs[0]
    let l:params = GetSubList(l:listArgs, 1)
    if l:cmd =~ "AddKey"
        call AutoComplAddKeyCmd(l:params)
    elseif l:cmd =~ "SetKeyWordHandler"
        call AutoComplSetKeyWordHandlerCmd(l:params)
    endif
endfunction

command -narg=+ Autocmpl :call AutocompleteCommand(<q-args>)

Autocmpl AddKey identifier \a(\a|\d)*
Autocmpl AddKey variable %(identifier) before=var
Autocmpl SetKeyWordHandler KeyWordHandler params=%(variable)
