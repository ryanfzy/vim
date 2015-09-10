
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

function AutoComplAddIdentifier(identifier)
    let b:listIdentifier = add(b:listIdentifier, a:identifier)
    echom "identifiers:".b:listIdentifier
endfunction

function AutoComplAddVariable(variable)
    let b:listVariable = add(b:listVariable, a:variable)
    echom "variables:".b:listVariable
endfunction

function AutocompleteCommand(args)
    let l:listArgs = split(args)
    if l:listArgs[0] =~ "identifier"
        call AutoComplAddIdentifier(l:listArgs[1])
    elseif l:listArgs[0] =~ "variable"
        call AutoComplAddVariable(l:listArgs[1])
    "elseif l:listArgs[0] =~ "completeFn"
        "call AutoComplAddCompleteFn(l:listArgs[1], l:listArgs[2])
    endif
endfunction

command -narg=+ Autocmpl :call AutocompleteCommand(<q-args>)

Autocmpl identifier \a(\a|\d)*
Autocmpl variable after=var
Autocmpl completeFn CompleteFn variable
