# Pairs that make 1000
title.ml: 1000 ആക്കുന്ന ജോഡികൾ
objective: Find the number that pairs with another to make 1000.
concept: pairs-1000
concept.name: Pairs that make 1000
concept.name.ml: 1000 ആക്കുന്ന ജോഡികൾ

## say
en: The same idea works for bigger numbers. 3 and 7 make 10. So 300 and 700 make 1000.
ml: ഇതേ ആശയം വലിയ സംഖ്യകളിലും ശരിയാണ്. 3-ഉം 7-ഉം ചേർന്നാൽ 10. അതുപോലെ 300-ഉം 700-ഉം ചേർന്നാൽ 1000.
visual: split 1000 300 700

## say
en: What about 150? Go up to the next hundred first: 150 to 200 is 50. Then 200 to 1000 is 800. So 150 pairs with 850.
ml: 150 ആണെങ്കിലോ? ആദ്യം അടുത്ത നൂറിലേക്ക്: 150 മുതൽ 200 വരെ 50. പിന്നെ 200 മുതൽ 1000 വരെ 800. അപ്പോൾ 150-ന്റെ ജോഡി 850.
visual: steps 150 + 50 = 200 / 200 + 800 = 1000 / 150 + 850 = 1000

## say
en: Pairs of 10 also help with 1000. 4 and 6 make 10, so 400 and 600 make 1000.
ml: 10-ന്റെ ജോഡികൾ 1000-നും സഹായിക്കും. 4-ഉം 6-ഉം 10, അതുകൊണ്ട് 400-ഉം 600-ഉം 1000.
visual: split 1000 400 600

## say
label: example
en: For 250: up 50 to reach 300, then 700 to reach 1000. 50 and 700 is 750.
ml: 250-ന്: 50 കൂടി 300, പിന്നെ 700 കൂടി 1000. 50-ഉം 700-ഉം ചേർന്നാൽ 750.
visual: steps 250 + 50 = 300 / 300 + 700 = 1000 / 50 + 700 = 750

## ask
form: number
en: Which number pairs with 400 to make 1000?
ml: 400-നോടൊപ്പം ചേർന്ന് 1000 ആക്കുന്ന സംഖ്യ ഏത്?
visual: split 1000 400 ?
answer: 600
hint.en: 4 and what make 10?
hint.ml: 4-നോട് എത്ര ചേർന്നാൽ 10?
explain.en: 4 and 6 make 10, so 400 and 600 make 1000.
explain.ml: 4-ഉം 6-ഉം 10. അതുകൊണ്ട് 400-ഉം 600-ഉം ചേർന്നാൽ 1000.
mistake 1400: added instead of finding the missing part

## ask
form: number
en: Which number pairs with 250 to make 1000?
ml: 250-നോടൊപ്പം ചേർന്ന് 1000 ആക്കുന്ന സംഖ്യ ഏത്?
visual: split 1000 250 ?
answer: 750
hint.en: 250 to 300 is 50. Then 300 to 1000 is?
hint.ml: 250 മുതൽ 300 വരെ 50. പിന്നെ 300 മുതൽ 1000 വരെ?
explain.en: 50 and 700 make 750. So 250 and 750 make 1000.
explain.ml: 50-ഉം 700-ഉം ചേർന്നാൽ 750. അതുകൊണ്ട് 250-ഉം 750-ഉം ചേർന്നാൽ 1000.
mistake 850: made the hundreds add to ten and forgot the fifties already make a hundred

## ask
form: number
en: Which number pairs with 950 to make 1000?
ml: 950-നോടൊപ്പം ചേർന്ന് 1000 ആക്കുന്ന സംഖ്യ ഏത്?
answer: 50
hint.en: 950 is very close to 1000. How far away?
hint.ml: 950, 1000-ന് വളരെ അടുത്താണ്. എത്ര ദൂരം?
explain.en: 950 and 50 make 1000.
explain.ml: 950-ഉം 50-ഉം ചേർന്നാൽ 1000.
mistake 150: made the hundreds add to ten and forgot the fifties already make a hundred

## ask
form: choice
level: 2
en: A shop wants 1000 pencils. It has 450. How many more does it need?
ml: ഒരു കടയ്ക്ക് 1000 പെൻസിൽ വേണം. കയ്യിൽ 450 ഉണ്ട്. ഇനി എത്ര വേണം?
options: 550 | 650 | 450
answer: 550
hint.en: 450 to 500 is 50. Then 500 to 1000 is 500.
hint.ml: 450 മുതൽ 500 വരെ 50. പിന്നെ 500 മുതൽ 1000 വരെ 500.
explain.en: 50 and 500 make 550. So 450 and 550 make 1000.
explain.ml: 50-ഉം 500-ഉം ചേർന്നാൽ 550. അതുകൊണ്ട് 450-ഉം 550-ഉം ചേർന്നാൽ 1000.
mistake 650: made the hundreds add to ten and forgot the fifties already make a hundred

## story
en: A water tank holds 1000 litres. If 400 litres are already inside, 600 more will fill it. What is inside and what is missing always make 1000.
ml: ഒരു വാട്ടർ ടാങ്കിൽ 1000 ലിറ്റർ കൊള്ളും. 400 ലിറ്റർ ഉള്ളിലുണ്ടെങ്കിൽ 600 കൂടി ഒഴിച്ചാൽ നിറയും. ഉള്ളിലുള്ളതും ഇനി വേണ്ടതും ചേർന്നാൽ എപ്പോഴും 1000.

## picture
visual: steps 4 + 6 = 10 / 40 + 60 = 100 / 400 + 600 = 1000
en: The same pair works for ones, for tens and for hundreds.
ml: ഒരേ ജോഡി ഒന്നുകളിലും പത്തുകളിലും നൂറുകളിലും ശരിയാണ്.
