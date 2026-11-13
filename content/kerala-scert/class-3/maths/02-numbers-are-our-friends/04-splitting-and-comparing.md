# Splitting and comparing
title.ml: പിരിക്കാം, താരതമ്യം ചെയ്യാം
objective: Split hundreds into two parts and compare three-digit numbers.
concept: split-hundreds
concept.name: Splitting hundreds
concept.name.ml: നൂറുകൾ പിരിക്കൽ

## say
en: A shop wants 1000 pencils in two bags. One bag has 300. Then the other must have 700, because 300 and 700 make 1000.
ml: ഒരു കടയ്ക്ക് 1000 പെൻസിൽ രണ്ട് സഞ്ചികളിലായി വേണം. ഒന്നിൽ 300. അപ്പോൾ മറ്റേതിൽ 700 വേണം, കാരണം 300-ഉം 700-ഉം ചേർന്നാൽ 1000.
visual: split 1000 300 700

## say
en: Splitting is easy with hundreds. Think of 10 as 3 and 7, and you know 1000 is 300 and 700.
ml: നൂറുകൾ ഉപയോഗിച്ച് പിരിക്കാൻ എളുപ്പമാണ്. 10 എന്നാൽ 3-ഉം 7-ഉം എന്ന് ഓർത്താൽ, 1000 എന്നാൽ 300-ഉം 700-ഉം എന്ന് അറിയാം.
visual: steps 3 + 7 = 10 / 300 + 700 = 1000

## say
label: example
en: To share equally into two, find the number that doubles to the total. 600 shared equally is 300 and 300.
ml: രണ്ടായി തുല്യമായി പങ്കിടാൻ, ഇരട്ടിച്ചാൽ ആകെ കിട്ടുന്ന സംഖ്യ കണ്ടെത്തൂ. 600 തുല്യമായി പങ്കിട്ടാൽ 300-ഉം 300-ഉം.
visual: split 600 300 300

## ask
form: number
en: 1000 pencils in two bags. One bag has 400. How many are in the other bag?
ml: 1000 പെൻസിൽ രണ്ട് സഞ്ചികളിൽ. ഒന്നിൽ 400. മറ്റേതിൽ എത്ര?
visual: split 1000 400 ?
answer: 600
hint.en: 4 hundreds and how many more hundreds make 10 hundreds?
hint.ml: 4 നൂറുകളോട് എത്ര നൂറുകൾ ചേർന്നാൽ 10 നൂറുകൾ?
explain.en: 400 and 600 make 1000, just as 4 and 6 make 10.
explain.ml: 4-ഉം 6-ഉം 10 ആകുന്നതുപോലെ 400-ഉം 600-ഉം ചേർന്നാൽ 1000.
mistake 1400: added instead of finding the missing part

## ask
form: number
en: 800 pencils are shared equally into two bags. How many in each bag?
ml: 800 പെൻസിൽ രണ്ട് സഞ്ചികളിൽ തുല്യമായി വെച്ചു. ഓരോന്നിലും എത്ര?
visual: split 800 ? ?
answer: 400
hint.en: Which number, taken two times, makes 800? Think of 8 first.
hint.ml: ഏത് സംഖ്യ രണ്ട് തവണ എടുത്താൽ 800 ആകും? ആദ്യം 8-നെക്കുറിച്ച് ആലോചിക്കൂ.
explain.en: 400 and 400 make 800.
explain.ml: 400-ഉം 400-ഉം ചേർന്നാൽ 800.
mistake 800: did not split the total

## say
en: To compare two numbers, look at the hundreds first. If they are the same, look at the tens.
ml: രണ്ട് സംഖ്യകൾ താരതമ്യം ചെയ്യാൻ ആദ്യം നൂറുകൾ നോക്കൂ. അവ തുല്യമാണെങ്കിൽ പത്തുകൾ നോക്കൂ.
visual: steps 244 has 2 hundreds, 4 tens / 209 has 2 hundreds, 0 tens / 244 is bigger

## ask
form: choice
concept: compare-order
concept.name: Comparing and ordering numbers
en: The Periyar river is 244 km long. The Bharathappuzha is 209 km long. Which length is longer?
ml: പെരിയാറിന്റെ നീളം 244 കി.മീ. ഭാരതപ്പുഴയുടെ നീളം 209 കി.മീ. ഏതാണ് കൂടുതൽ?
options: 244 km | 209 km
options.ml: 244 കി.മീ | 209 കി.മീ
answer: 244 km
hint.en: Both have 2 hundreds. Now compare the tens.
hint.ml: രണ്ടിലും 2 നൂറുകൾ. ഇനി പത്തുകൾ നോക്കൂ.
explain.en: 244 has 4 tens and 209 has 0 tens, so 244 is larger.
explain.ml: 244-ൽ 4 പത്തുകൾ, 209-ൽ 0 പത്തുകൾ. അതുകൊണ്ട് 244 വലുത്.
mistake 209 km: compared the ones digit instead of the tens

## ask
form: choice
level: 2
concept: compare-order
en: Which list goes from the smallest to the largest?
ml: ചെറുതിൽ നിന്ന് വലുതിലേക്കുള്ള ക്രമം ഏത്?
options: 110, 169, 176 | 169, 110, 176 | 176, 169, 110
answer: 110, 169, 176
hint.en: All have 1 hundred. Compare the tens: 1, 6 and 7.
hint.ml: എല്ലാത്തിലും 1 നൂറ്. പത്തുകൾ നോക്കൂ: 1, 6, 7.
explain.en: 110 has the fewest tens, then 169, then 176.
explain.ml: 110-ൽ ഏറ്റവും കുറവ് പത്തുകൾ, പിന്നെ 169, പിന്നെ 176.
mistake 176, 169, 110: ordered from largest to smallest

## ask
form: number
level: 2
en: A school needs 650 pencils. It already has 5 boxes of 100 and 4 packets of 10. How many more pencils does it need?
ml: ഒരു സ്കൂളിന് 650 പെൻസിൽ വേണം. 100 വീതമുള്ള 5 പെട്ടികളും 10 വീതമുള്ള 4 പാക്കറ്റുകളും കയ്യിലുണ്ട്. ഇനി എത്ര പെൻസിൽ കൂടി വേണം?
answer: 110
hint.en: First find how many it has: 500 and 40. Then count up to 650.
hint.ml: ആദ്യം കയ്യിലുള്ളത് കണ്ടെത്തൂ: 500-ഉം 40-ഉം. പിന്നെ 650 വരെ എണ്ണൂ.
explain.en: It has 540. From 540 to 600 is 60, and 50 more reaches 650. So 110 more.
explain.ml: കയ്യിൽ 540. 540 മുതൽ 600 വരെ 60, പിന്നെ 50 കൂടി ആയാൽ 650. അതുകൊണ്ട് 110 കൂടി വേണം.
mistake 540: stopped after finding how many it already has

## ask
form: choice
en: Which pair makes 700?
ml: 700 ആക്കുന്ന ജോഡി ഏത്?
visual: split 700 ? ?
options: 300 + 400 | 300 + 300 | 500 + 100
answer: 300 + 400
hint.en: Add the hundreds in each pair. Which gives 7 hundreds?
hint.ml: ഓരോ ജോഡിയിലെയും നൂറുകൾ കൂട്ടൂ. 7 നൂറുകൾ കിട്ടുന്നത് ഏതിൽ?
explain.en: 3 hundreds and 4 hundreds make 7 hundreds. 300 + 400 = 700.
explain.ml: 3 നൂറുകളും 4 നൂറുകളും ചേർന്നാൽ 7 നൂറുകൾ. 300 + 400 = 700.

## ask
form: number
concept: compare-order
en: Three rivers are 128 km, 121 km and 176 km long. Type the largest number.
ml: മൂന്ന് പുഴകളുടെ നീളം 128, 121, 176 കി.മീ. ഏറ്റവും വലിയ സംഖ്യ ടൈപ്പ് ചെയ്യൂ.
answer: 176
hint.en: All have 1 hundred. Which has the most tens?
hint.ml: എല്ലാത്തിലും 1 നൂറ്. ഏറ്റവും കൂടുതൽ പത്തുകൾ ഏതിൽ?
explain.en: 176 has 7 tens. The others have only 2 tens. So 176 is the largest.
explain.ml: 176-ൽ 7 പത്തുകൾ. മറ്റുള്ളവയിൽ 2 പത്തുകൾ മാത്രം. അതുകൊണ്ട് 176 ഏറ്റവും വലുത്.
mistake 128: compared the ones digit instead of the tens

## story
en: Two brothers carry 1000 mangoes in two baskets. If the first carries 300, the second must carry the rest, 700. When one basket gets heavier the other gets lighter, but together it is always 1000.
ml: രണ്ട് സഹോദരന്മാർ 1000 മാങ്ങ രണ്ട് കൊട്ടകളിൽ ചുമക്കുന്നു. ഒരാൾ 300 എടുത്താൽ മറ്റേയാൾ ബാക്കി 700 എടുക്കണം. ഒരു കൊട്ടയിൽ കൂടിയാൽ മറ്റേതിൽ കുറയും, പക്ഷേ രണ്ടും ചേർന്നാൽ എപ്പോഴും 1000.

## picture
visual: split 1000 300 700
en: The top number is the whole. The two below are its parts. The parts always add up to the whole.
ml: മുകളിലെ സംഖ്യ മുഴുവൻ. താഴെയുള്ള രണ്ടും അതിന്റെ ഭാഗങ്ങൾ. ഭാഗങ്ങൾ കൂട്ടിയാൽ എപ്പോഴും മുഴുവൻ കിട്ടും.
