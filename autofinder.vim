
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

let b:handlerFns = []
let b:reservedChars = ['=', '&', '|']

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function AUTOCOMPLETE_CallKeyWordHandlerFnIfMatch(listWords, index)
    for fnParam in b:handlerFns
        let l:HandlerFn = function(fnParam[0])
        let l:param = fnParam[1]
        if AUTOCOMPLETE_CheckWord(a:listWords, a:index, l:param)
            call l:HandlerFn(a:listWords[a:index])
        endif
    endfor
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" AddKey command
" e.g. Autocmpl AddKey someKey someValue attrKey1=attrValue1 attrKey2=attrValue2
" { someKey : 
"   {
"       'value' : someValue,
"       'before' : []
"       'after' : []
"       attrKey1 : attrValue1,
"       attrKey2 : attrValue2
"   }
"   ...
" }
" NB: for attributes 'before' and 'after', their values will be parsed in this stage
function AUTOCOMPLETE_AddKeyCmd(params)
    call Debug("AUTOCOMPLETE_AddKeyCmd()")
    let l:key = a:params[0]
    let l:value = {}
    let l:value['value'] = a:params[1]
    if len(a:params) > 2
        for n in range(2, len(a:params)-1)
            " \(\\\)\@<!= this matches =, doesn't match escaped \=
            let l:keyValue = split(a:params[n], '\(\\\)\@<!=')
            let l:value[l:keyValue[0]] = l:keyValue[1]
        endfor
    endif
    if has_key(l:value, 'before')
        let l:value['before'] = AUTOCOMPLETE_ParseAttrValueMain(l:value['before'])
    endif
    if has_key(l:value, 'after')
        let l:value['after'] = AUTOCOMPLETE_ParseAttrValueMain(l:value['after'])
    endif
    let b:dictKeys[l:key] = l:value
    echom string(l:value)
endfunction

function AUTOCOMPLETE_ParseAttrValueMain(attrValue)
    "echom "parse attr value main"
    return AUTOCOMPLETE_ParseAttrValue(a:attrValue, 0)[0]
endfunction

" parse the attribute value for 'before' and 'after'
" e.g. before=a|b, this will return [['a'], ['b']]
" e.g. before=a&b|c, this will return [['a', b'], ['a', 'c']]
function AUTOCOMPLETE_ParseAttrValue(attrValue, index)
    let l:listOfListValidValues = []
    let l:escapeNextChar = g:FALSE
    let l:foundOr = g:FALSE
    let l:foundAnd = g:FALSE
    let l:listIndexes = [0]
    let l:value = ''
    let l:index = a:index

    while l:index < len(a:attrValue)
        "echom 'len:'.len(a:attrValue).'('.l:index.')'
        "echom a:attrValue[l:index]
        "echom 'value:'.l:value

        let l:ch = a:attrValue[l:index]

        " in some case, we don't want to apend l:ch to l:value
        let l:addChar = g:TRUE
        " current l:ch should be escaped or not
        let l:escape = g:FALSE
        " in case this function calls itself, we want to jump the index
        let l:nextIndex = l:index+1

        " this is used for '|' operator
        " e.g. if we have a&...&i&j|k, when we see '|', this function will
        " make a copy from a to i and append it 'k'
        " the index of i is kept in here
        let l:listIndexesTmp = []

        " escape next character
        if l:ch =~ '\'
            let l:escapeNextChar = g:TRUE
            let l:addChar = g:FALSE
        " add the escaped character
        elseif l:escapeNextChar
            let l:escapeNextChar = g:FALSE
            let l:escape = g:TRUE
        endif
        " add value to each valid values in valid values list
        " the boundaries for each value is either (, ), &, | or reached the last ch
        if (!escape && IsAnyChar(l:ch, ['(', ')', '&', '|'])) || l:index == len(a:attrValue)-1
            let l:addChar = g:FALSE
            let l:listSubValidValues = []

            " append l:ch to l:value if l:ch is the last char because we
            " are adding it to valid values list
            if l:index == len(a:attrValue)-1
                if !IsAnyChar(l:ch, ['(', ')', '&', '|']) || l:escape
                    let l:value = l:value . l:ch
                endif

            elseif l:ch =~ '&'
                let l:foundAnd = g:TRUE
            elseif l:ch =~ '|' && !l:foundAnd
                let l:foundOr = g:TRUE
            " when we see '(', this function will call itselt
            " it treats (...) as a subset and will add the return value to the valid value list
            elseif l:ch =~ '('
                let l:listValidValuesAndIndex = AUTOCOMPLETE_ParseAttrValue(a:attrValue, l:index+1)
                let l:listSubValidValues = l:listValidValuesAndIndex[0]
                " update the indexes
                let l:nextIndex = l:listValidValuesAndIndex[1]
                for listValidValues in l:listOfListValidValues
                    let l:listIndexesTmp = add(l:listIndexesTmp, len(listValidValues))
                endfor
            endif

            " if we don't see '(', we will transfer the current value to the correct format
            if len(l:listSubValidValues) < 1 && !IsEmptyString(l:value)
                let l:listSubValidValues = [[l:value]]
            endif

            " add new the values found to the valid values list
            if len(l:listSubValidValues) > 0
                " for the first set of values, we simply add the to the valid values list
                if len(l:listOfListValidValues) < 1
                    for i in range(len(l:listSubValidValues))
                        let l:listOfListValidValues = add(l:listOfListValidValues, l:listSubValidValues[i])
                    endfor
                " for more new values
                else
                    if len(l:listIndexesTmp) < 1
                        let l:listIndexesTmp = l:listIndexes
                    endif
                    let l:listIndexes = []
                    for i in range(len(l:listOfListValidValues))
                        for j in range(len(l:listSubValidValues))
                            " updates the indexes before adding new values
                            let l:listIndexes = add(l:listIndexes, len(l:listOfListValidValues[i]))
                            
                            " for | operator, create a copy of valid values
                            " and add the new value to the new valid values then
                            " add the new valid values to the valid values list
                            if l:foundOr
                                let l:foundOr = g:FALSE
                                let l:subList = GetSubList(l:listOfListValidValues[i], 0, l:listIndexesTmp[i])
                                let l:subList = extend(l:subList, l:listSubValidValues[j])
                                let l:listOfListValidValues = add(l:listOfListValidValues, l:subList)
                            " for other cases, add the new value to the existing valid values list
                            else
                                if l:foundAnd
                                    let l:foundAnd = g:FALSE
                                    let l:nextIndex = l:index
                                endif
                                let l:listOfListValidValues[i] = extend(l:listOfListValidValues[i], l:listSubValidValues[j])
                            endif
                        endfor
                    endfor
                endif
                let l:value = ''
            endif

            " when we see ')', we finish parsing the current sub set
            " break the loop and return the result
            if l:ch =~ ')'
                let l:addChar = g:FALSE
                break
            endif
        endif

        if l:addChar
            let l:value = l:value . l:ch
        endif
        let l:index = l:nextIndex
    endwhile

    return [l:listOfListValidValues, l:index+1]
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

    " add the handler fn to handlerFns list
    "let l:lst = [l:fnName, l:dictParams['params']]
    let b:handlerFns = add(b:handlerFns, [l:fnName, l:dictParams['params']])
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function AUTOCOMPLETE_Match(word, pat)
    call Debug("AUTOCOMPLETE_Match()")
    let l:listPats = []
    if type(a:pat) == type("")
        let l:listPats = add(l:listPats, a:pat)
    else
        let l:listPats = l:listPats + a:pat
    endif
    for p in l:listPats
        if match(a:word, p) == 0
            return g:TRUE
        endif
    endfor
    return g:FALSE
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

function AUTOCOMPLETE_CheckAddKeyCmdBeforeAttr(listWords, index, listOfListValidValues)
    let l:index = a:index
    for listValidValues in a:listOfListValidValues
        let l:bMatch = g:TRUE
        for i in range(len(listValidValues)-1, 0, -1)
            if l:index < 0 || !AUTOCOMPLETE_Match(a:listWords[l:index], listValidValues[i])
                let l:bMatch = g:FALSE
                break
            endif
            let l:index =- 1
        endfor
        if l:bMatch
            return g:TRUE
        endif
    endfor
    return g:FALSE
endfunction

function AUTOCOMPLETE_CheckAddKeyCmdAfterAttr(listWords, index, listOfListValidValues)
    let l:index = a:index
    let l:wordLen = len(a:listWords)
    for listValidValues in a:listOfListValidValues
        let l:bMatch = g:TRUE
        for word in listValidValues
            if l:index > l:wordLen-1 || !AUTOCOMPLETE_Match(a:listWords[l:index], word)
                let l:bMatch = g:FALSE
                break
            endif
            let l:index =+ 1
        endfor
        if l:bMatch
            return g:TRUE
        endif
    endfor
    return g:FALSE
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
        let l:listOfListValidValues = l:dictValue['before']
        "echom string(l:listOfListValidValues)
        if !AUTOCOMPLETE_CheckAddKeyCmdBeforeAttr(a:listWords, a:index-1, l:listOfListValidValues)
            return g:FALSE
        endif
    endif
    if has_key(l:dictValue, 'after')
        " last word doesn't have after words
        if a:index == len(a:listWords)-1
            return g:FALSE
        endif
        let l:listOfListValidValues = l:dictValue['after']
        "echom string(l:listOfListValidValues)
        if !AUTOCOMPLETE_CheckAddKeyCmdAfterAttr(a:listWords, a:index+1, l:listOfListValidValues)
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
        call AUTOCOMPLETE_SetKeyWordHandlerCmd(l:params)
    endif
endfunction

function AUTOCOMPLETE_RunFinder()
    call Debug("AUTOCOMPLETE_Run()")
    let l:listWords = GetListOfTokensOfCurrentFile()
    for i in range(len(l:listWords))
        call AUTOCOMPLETE_CallKeyWordHandlerFnIfMatch(l:listWords, i)
    endfor

"    " run key word handler
"    "let l:param = b:keyWordHandlerFnParams
"    for n in range(len(l:listWords))
"        "if AUTOCOMPLETE_CheckWord(l:listWords, n, l:param)
"            "call b:keyWordHandlerFn(l:listWords[n])        
"        "endif
"        for fnIndex in range(len(b:handlerFns))
"            let l:fnParams = b:handlerFns[fnIndex]
"            echom string(l:fnParams)
"            let l:Fn = function(l:fnParams[0])
"            let l:param = l:fnParams[1]
"            if AUTOCOMPLETE_CheckWord(l:listWords, n, l:param)
"                call l:Fn(l:listWords[n])
"            endif
"        endfor
"    endfor
endfunction

" not being used
function AUTOCOMPLETE_ShouldCallKeyWordHandlerFn(listOfWord, index)
    for fnParams in b:handlerFns
    endfor
    let l:param = b:keyWordHandlerFnParams
    return AUTOCOMPLETE_CheckWord(a:listOfWords, a:index, l:param)
endfunction

command -narg=+ Autocmpl :call AUTOCOMPLETE_CmdProcessor(<q-args>)
