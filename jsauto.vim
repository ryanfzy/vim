
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

let b:listIdentifier = []
let b:listVariable = []

function AutoComplAddKeyCmd(params)
    "let b:listIdentifier = add(b:listIdentifier, a:identifier)
    echom "AutoComplAddKeyCmd params:".GetListAsString(a:params)
endfunction

function AutoComplSetCompleteFunctionCmd(params)
    "let b:listVariable = add(b:listVariable, a:variable)
    echom "AutoCmplSetCompleteFunctionCmd params:".GetListAsString(a:params)
endfunction

function AutocompleteCommand(args)
    let l:listArgs = split(a:args)
    let l:cmd = l:listArgs[0]
    let l:params = GetSubList(l:listArgs, 1)
    if l:cmd =~ "AddKey"
        call AutoComplAddKeyCmd(l:params)
    elseif l:cmd =~ "SetCompleteFunction"
        call AutoComplSetCompleteFunctionCmd(l:params)
    endif
endfunction

command -narg=+ Autocmpl :call AutocompleteCommand(<q-args>)

Autocmpl AddKey identifier \a(\a|\d)*
Autocmpl AddKey variable %(identifier) after=var
Autocmpl SetCompleteFunction CompleteFn params=%(variable)
