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
