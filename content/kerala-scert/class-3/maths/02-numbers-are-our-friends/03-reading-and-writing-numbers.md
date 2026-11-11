# Reading and writing numbers
title.ml: സംഖ്യകൾ വായിക്കാം, എഴുതാം
objective: Read and write three-digit numbers in words and count on across a hundred.
concept: number-names
concept.name: Number names and counting on
concept.name.ml: സംഖ്യാനാമങ്ങളും തുടർന്നെണ്ണലും

## say
en: Numbers can be written in words too. On a cheque, people write the amount in words. 125 is one hundred twenty five.
ml: സംഖ്യകൾ അക്ഷരത്തിലും എഴുതാം. ചെക്കിൽ തുക അക്ഷരത്തിൽ എഴുതാറുണ്ട്. 125 എന്നാൽ നൂറ്റി ഇരുപത്തിയഞ്ച്.
visual: text 125

## ask
form: choice
en: Which number is four hundred five?
ml: നാനൂറ്റി അഞ്ച് ഏത് സംഖ്യയാണ്?
options: 405 | 450 | 45
answer: 405
hint.en: Four hundred, no tens, and five ones.
hint.ml: നാനൂറ്, പത്തുകളില്ല, അഞ്ച് ഒന്നുകൾ.
explain.en: 400 and 5 make 405. The tens place has 0.
explain.ml: 400-ഉം 5-ഉം ചേർന്നാൽ 405. പത്തിന്റെ സ്ഥാനത്ത് 0.
mistake 450: put the five in the tens place
mistake 45: left out the zero for the empty tens place

## ask
form: choice
en: How do we say 617?
ml: 617 എങ്ങനെ വായിക്കും?
options: six hundred seventeen | six hundred seventy | sixty one seven
options.ml: അറുനൂറ്റി പതിനേഴ് | അറുനൂറ്റി എഴുപത് | അറുപത്തിയൊന്ന് ഏഴ്
answer: six hundred seventeen
hint.en: 6 hundreds, then 17.
hint.ml: 6 നൂറുകൾ, പിന്നെ 17.
explain.en: 617 is 600 and 17: six hundred seventeen.
explain.ml: 617 എന്നാൽ 600-ഉം 17-ഉം: അറുനൂറ്റി പതിനേഴ്.
mistake six hundred seventy: confused seventeen with seventy

## say
en: Now let us count on. After 299 the ones and tens are full, so a new hundred begins.
ml: ഇനി തുടർന്ന് എണ്ണാം. 299 കഴിഞ്ഞാൽ ഒന്നുകളും പത്തുകളും നിറഞ്ഞു, അതുകൊണ്ട് പുതിയ നൂറ് തുടങ്ങും.
visual: pattern 297 298 299 ?

## ask
form: number
en: Which number comes just after 299?
ml: 299-ന് തൊട്ടുശേഷം വരുന്ന സംഖ്യ ഏത്?
visual: pattern 297 298 299 ?
answer: 300
hint.en: 299 and one more. The 99 becomes a full hundred.
hint.ml: 299-ഉം ഒന്ന് കൂടിയും. 99 ഒരു മുഴുവൻ നൂറാകും.
explain.en: 299 and 1 more make 300.
explain.ml: 299-ഉം 1-ഉം ചേർന്നാൽ 300.
mistake 2100: wrote ten in the ones place instead of starting a new hundred
mistake 290: went back instead of forward

## ask
form: number
level: 2
en: Which number comes just before 500?
ml: 500-ന് തൊട്ടുമുമ്പ് വരുന്ന സംഖ്യ ഏത്?
answer: 499
hint.en: One less than 500. Think of 100 minus 1 first.
hint.ml: 500-നെക്കാൾ ഒന്ന് കുറവ്. ആദ്യം 100-ൽ നിന്ന് 1 കുറച്ചാൽ എത്രയെന്ന് ആലോചിക്കൂ.
explain.en: One less than 500 is 499.
explain.ml: 500-ൽ നിന്ന് ഒന്ന് കുറച്ചാൽ 499.
mistake 501: gave the number after, not before
mistake 490: went back ten instead of one
