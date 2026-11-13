# Packets and boxes
title.ml: പാക്കറ്റുകളും പെട്ടികളും
objective: Group in tens and hundreds, up to one thousand.
concept: tens-hundreds
concept.name: Tens, hundreds and a thousand
concept.name.ml: പത്തുകളും നൂറുകളും ആയിരവും

## say
en: A pencil factory is packing pencils. 10 pencils go into one packet.
ml: ഒരു പെൻസിൽ ഫാക്ടറിയിൽ പെൻസിലുകൾ പാക്ക് ചെയ്യുന്നു. ഒരു പാക്കറ്റിൽ 10 പെൻസിൽ.
visual: count 10 ✏️

## say
en: 10 packets go into one box. 10 tens make 100. So one box holds 100 pencils.
ml: ഒരു പെട്ടിയിൽ 10 പാക്കറ്റ്. 10 പത്തുകൾ ചേർന്നാൽ 100. അതുകൊണ്ട് ഒരു പെട്ടിയിൽ 100 പെൻസിൽ.
visual: text 10 tens = 100

## say
en: Grouping makes counting quick. Instead of counting 30 pencils one by one, count the packets: 10, 20, 30.
ml: കൂട്ടങ്ങളാക്കിയാൽ എണ്ണാൻ എളുപ്പമാണ്. 30 പെൻസിൽ ഓരോന്നായി എണ്ണുന്നതിന് പകരം പാക്കറ്റുകൾ എണ്ണൂ: 10, 20, 30.
visual: groups 3 10 ✏️

## say
label: example
en: 2 boxes and 3 packets: 2 hundreds and 3 tens. That is 200 and 30, which is 230 pencils.
ml: 2 പെട്ടികളും 3 പാക്കറ്റുകളും: 2 നൂറുകളും 3 പത്തുകളും. 200-ഉം 30-ഉം, അതായത് 230 പെൻസിൽ.
visual: steps 2 boxes = 200 / 3 packets = 30 / 200 + 30 = 230

## ask
form: number
en: How many pencils are in 3 packets?
ml: 3 പാക്കറ്റിൽ ആകെ എത്ര പെൻസിൽ?
visual: groups 3 10 ✏️
answer: 30
hint.en: Count in tens: 10, 20, ...
hint.ml: പത്ത് വീതം എണ്ണൂ: 10, 20, ...
explain.en: 10, 20, 30. Three tens make 30.
explain.ml: 10, 20, 30. മൂന്ന് പത്തുകൾ 30.
mistake 13: added 3 and 10 instead of counting three tens
mistake 3: counted packets, not pencils

## ask
form: number
en: One box holds 100 pencils. How many pencils are in 2 boxes?
ml: ഒരു പെട്ടിയിൽ 100 പെൻസിൽ. 2 പെട്ടിയിൽ എത്ര പെൻസിൽ?
answer: 200
hint.en: 100 and 100 more.
hint.ml: 100-ഉം ഒരു 100 കൂടിയും.
explain.en: 100 and 100 make 200.
explain.ml: 100-ഉം 100-ഉം ചേർന്നാൽ 200.
mistake 102: added 2 to 100 instead of taking two hundreds

## ask
form: choice
level: 2
en: 5 boxes and 4 packets. How many pencils is that?
ml: 5 പെട്ടികളും 4 പാക്കറ്റുകളും. ആകെ എത്ര പെൻസിൽ?
options: 540 | 54 | 504
answer: 540
hint.en: 5 boxes are 5 hundreds. 4 packets are 4 tens.
hint.ml: 5 പെട്ടികൾ എന്നാൽ 5 നൂറുകൾ. 4 പാക്കറ്റുകൾ എന്നാൽ 4 പത്തുകൾ.
explain.en: 5 hundreds are 500. 4 tens are 40. Together 540.
explain.ml: 5 നൂറുകൾ 500. 4 പത്തുകൾ 40. ചേർന്നാൽ 540.
mistake 54: wrote the counts side by side without their place values
mistake 504: put the tens in the ones place

## ask
form: number
level: 2
en: There are 10 boxes. Each box holds 100 pencils. How many pencils in all?
ml: 10 പെട്ടികളുണ്ട്. ഓരോന്നിലും 100 പെൻസിൽ. ആകെ എത്ര പെൻസിൽ?
answer: 1000
hint.en: Count in hundreds: 100, 200, 300, ... ten times.
hint.ml: നൂറ് വീതം എണ്ണൂ: 100, 200, 300, ... പത്ത് തവണ.
explain.en: 10 hundreds make 1000. We call it one thousand.
explain.ml: 10 നൂറുകൾ ചേർന്നാൽ 1000. അതിനെ ആയിരം എന്ന് പറയും.
mistake 110: added 10 and 100 instead of taking ten hundreds

## ask
form: abacus
level: 2
en: 5 boxes of 100 and 2 packets of 10. Move the beads to show how many pencils that is.
ml: 100 വീതമുള്ള 5 പെട്ടികളും 10 വീതമുള്ള 2 പാക്കറ്റുകളും. ആകെ പെൻസിലുകളുടെ എണ്ണം മണികൾ നീക്കി കാണിക്കൂ.
answer: 520
hint.en: Boxes are hundreds. Packets are tens. There are no loose pencils.
hint.ml: പെട്ടികൾ നൂറുകൾ. പാക്കറ്റുകൾ പത്തുകൾ. ഒറ്റ പെൻസിലുകളില്ല.
explain.en: 5 hundreds and 2 tens make 520. The ones rod stays empty.
explain.ml: 5 നൂറുകളും 2 പത്തുകളും ചേർന്നാൽ 520. ഒന്നിന്റെ കമ്പി ഒഴിഞ്ഞിരിക്കും.
mistake 502: put the tens on the ones rod
mistake 52: left the hundreds rod empty

## story
en: A shopkeeper ties 10 pencils with a rubber band. That is one ten. He puts 10 bundles in a box. That is one hundred. Ten boxes fill a carton. That is one thousand.
ml: ഒരു കടക്കാരൻ 10 പെൻസിൽ റബ്ബർബാൻഡ് ഇട്ട് കെട്ടുന്നു. അതൊരു പത്ത്. അങ്ങനെ 10 കെട്ടുകൾ ഒരു പെട്ടിയിൽ. അതൊരു നൂറ്. പത്ത് പെട്ടികൾ ഒരു വലിയ പെട്ടിയിൽ. അതൊരു ആയിരം.

## picture
visual: steps 10 ones = 1 ten / 10 tens = 1 hundred / 10 hundreds = 1 thousand
en: Every time we have 10 of something, we pack it into the next bigger one.
ml: ഏതെങ്കിലും 10 എണ്ണം ആയാൽ, അതിനെ അടുത്ത വലിയ ഒന്നാക്കി പാക്ക് ചെയ്യും.
