# Past one thousand
title.ml: ആയിരത്തിനപ്പുറം
objective: Read and continue numbers beyond 1000.
concept: beyond-1000
concept.name: Numbers beyond 1000
concept.name.ml: ആയിരത്തിന് മുകളിലുള്ള സംഖ്യകൾ

## say
en: It is sports day in the forest, and every runner gets a chest number. After 999 comes 1000, one thousand. It has four digits.
ml: കാട്ടിൽ കായികമേളയാണ്. ഓരോ ഓട്ടക്കാരനും ഒരു നമ്പർ കിട്ടും. 999 കഴിഞ്ഞാൽ 1000, അതായത് ആയിരം. അതിന് നാല് അക്കങ്ങളുണ്ട്.
visual: pattern 997 998 999 ?

## say
en: 1000 and 1 together make 1001. Then come 1002, 1003, and so on.
ml: 1000-ഉം 1-ഉം ചേർന്നാൽ 1001. പിന്നെ 1002, 1003 എന്നിങ്ങനെ.
visual: text 1000 + 1 = 1001

## ask
form: number
en: Which chest number comes just after 1004?
ml: 1004-ന് തൊട്ടുശേഷം വരുന്ന നമ്പർ ഏത്?
visual: pattern 1002 1003 1004 ?
answer: 1005
hint.en: Only the ones digit changes. What comes after 4?
hint.ml: ഒന്നിന്റെ സ്ഥാനത്തെ അക്കം മാത്രം മാറും. 4 കഴിഞ്ഞാൽ?
explain.en: 1004 and 1 more make 1005.
explain.ml: 1004-ഉം 1-ഉം ചേർന്നാൽ 1005.
mistake 2004: added one to the thousands instead of the ones

## ask
form: number
en: 1000 and 12 together make which number?
ml: 1000-ഉം 12-ഉം ചേർന്നാൽ ഏത് സംഖ്യ?
answer: 1012
hint.en: Keep the 1000 and put 12 in the last two places.
hint.ml: 1000 അങ്ങനെ വെച്ച്, അവസാന രണ്ട് സ്ഥാനങ്ങളിൽ 12 വെക്കൂ.
explain.en: 1000 and 12 make 1012.
explain.ml: 1000-ഉം 12-ഉം ചേർന്നാൽ 1012.
mistake 100012: wrote the two numbers side by side
mistake 1120: put the 12 in the wrong places

## ask
form: choice
en: Which number is larger?
ml: ഏത് സംഖ്യയാണ് വലുത്?
options: 1001 | 999
answer: 1001
hint.en: Count the digits in each number.
hint.ml: ഓരോ സംഖ്യയിലെയും അക്കങ്ങൾ എണ്ണൂ.
explain.en: 1001 has four digits. Every four-digit number is larger than any three-digit number.
explain.ml: 1001-ന് നാല് അക്കങ്ങളുണ്ട്. ഏത് നാലക്ക സംഖ്യയും ഏത് മൂന്നക്ക സംഖ്യയെക്കാളും വലുതാണ്.
mistake 999: judged by the size of the digits, not the number of digits

## ask
form: number
level: 2
en: Which number comes just after 1099?
ml: 1099-ന് തൊട്ടുശേഷം വരുന്ന സംഖ്യ ഏത്?
answer: 1100
hint.en: The 99 is full. One more makes a new hundred.
hint.ml: 99 നിറഞ്ഞു. ഒന്ന് കൂടി ചേർന്നാൽ പുതിയ നൂറ്.
explain.en: 1099 and 1 more make 1100: one thousand one hundred.
explain.ml: 1099-ഉം 1-ഉം ചേർന്നാൽ 1100: ആയിരത്തി ഒരുനൂറ്.
mistake 2000: jumped to the next thousand
mistake 1090: went back instead of forward

## story
en: A car's meter shows 999 kilometres. One more kilometre and all the nines roll over to zero, and a 1 appears in front: 1000. After that it simply keeps counting: 1001, 1002.
ml: ഒരു കാറിന്റെ മീറ്ററിൽ 999 കിലോമീറ്റർ. ഒരു കിലോമീറ്റർ കൂടി ഓടിയാൽ എല്ലാ ഒമ്പതുകളും പൂജ്യമാകും, മുന്നിൽ ഒരു 1 വരും: 1000. പിന്നെ അത് എണ്ണിക്കൊണ്ടേയിരിക്കും: 1001, 1002.

## picture
visual: pattern 998 999 1000 1001 1002
en: After 999 the counting does not stop. A new place opens for thousands.
ml: 999 കഴിഞ്ഞാലും എണ്ണൽ നിൽക്കില്ല. ആയിരങ്ങൾക്കായി ഒരു പുതിയ സ്ഥാനം തുറക്കും.
