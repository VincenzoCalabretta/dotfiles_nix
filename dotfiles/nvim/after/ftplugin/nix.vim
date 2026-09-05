" Keep matchit patterns as regexes: double-quoted Vimscript strings would
" consume the word-boundary backslashes and make `%` look for `<let>`.
let b:match_words = '\<if\>:\<then\>:\<else\>,\<let\>:\<in\>'
