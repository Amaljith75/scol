# Pairs that make 100
title.ml: 100 ആക്കുന്ന ജോഡികൾ
objective: Find the number that pairs with another to make 100.
concept: pairs-100
concept.name: Pairs that make 100
concept.name.ml: 100 ആക്കുന്ന ജോഡികൾ

## say
en: Welcome to the maths fair! At this stall, two cards that add up to 100 make a pair. 80 and 20 are a pair.
ml: ഗണിതമേളയിലേക്ക് സ്വാഗതം! ഈ സ്റ്റാളിൽ, കൂട്ടിയാൽ 100 കിട്ടുന്ന രണ്ട് കാർഡുകൾ ഒരു ജോഡിയാണ്. 80-ഉം 20-ഉം ഒരു ജോഡി.
visual: split 100 80 20

## say
en: 49 and 51 are a pair too. Here is a trick: go up to the next ten first, then on to 100.
ml: 49-ഉം 51-ഉം ഒരു ജോഡിയാണ്. ഒരു സൂത്രം: ആദ്യം അടുത്ത പത്തിലേക്ക് പോകൂ, പിന്നെ 100-ലേക്ക്.
visual: steps 49 + 1 = 50 / 50 + 50 = 100 / 49 + 51 = 100

## say
en: Pairs of 10 help with pairs of 100. 3 and 7 make 10, so 30 and 70 make 100.
ml: 10-ന്റെ ജോഡികൾ 100-ന്റെ ജോഡികൾക്ക് സഹായിക്കും. 3-ഉം 7-ഉം 10, അതുകൊണ്ട് 30-ഉം 70-ഉം 100.
visual: steps 3 + 7 = 10 / 30 + 70 = 100

## say
label: example
en: To pair 35 with 100: from 35 go up 5 to reach 40, then 60 more to reach 100. 5 and 60 is 65.
ml: 35-ന്റെ ജോഡി കാണാൻ: 35-ൽ നിന്ന് 5 കൂടി 40, പിന്നെ 60 കൂടി 100. 5-ഉം 60-ഉം ചേർന്നാൽ 65.
visual: steps 35 + 5 = 40 / 40 + 60 = 100 / 5 + 60 = 65

## ask
form: number
en: Which number pairs with 60 to make 100?
ml: 60-നോടൊപ്പം ചേർന്ന് 100 ആക്കുന്ന സംഖ്യ ഏത്?
visual: split 100 60 ?
answer: 40
hint.en: 6 tens and how many more tens make 10 tens?
hint.ml: 6 പത്തുകളോട് എത്ര പത്തുകൾ ചേർന്നാൽ 10 പത്തുകൾ?
explain.en: 60 and 40 make 100.
explain.ml: 60-ഉം 40-ഉം ചേർന്നാൽ 100.
mistake 160: added instead of finding the missing part

## ask
form: number
en: Which number pairs with 35 to make 100?
ml: 35-നോടൊപ്പം ചേർന്ന് 100 ആക്കുന്ന സംഖ്യ ഏത്?
visual: split 100 35 ?
answer: 65
hint.en: From 35 to 40 is 5. From 40 to 100 is 60.
hint.ml: 35 മുതൽ 40 വരെ 5. 40 മുതൽ 100 വരെ 60.
explain.en: 5 and 60 make 65. So 35 and 65 make 100.
explain.ml: 5-ഉം 60-ഉം ചേർന്നാൽ 65. അതുകൊണ്ട് 35-ഉം 65-ഉം ചേർന്നാൽ 100.
mistake 75: made the tens add to ten and forgot the ones already make a ten

## ask
form: choice
en: Which pair makes 100?
ml: 100 ആക്കുന്ന ജോഡി ഏത്?
options: 45 + 55 | 45 + 65 | 40 + 50
answer: 45 + 55
hint.en: Add the ones first. Do they make a ten?
hint.ml: ആദ്യം ഒന്നുകൾ കൂട്ടൂ. അവ ഒരു പത്താകുന്നുണ്ടോ?
explain.en: 5 and 5 make 10. 40 and 50 make 90. Together 100.
explain.ml: 5-ഉം 5-ഉം 10. 40-ഉം 50-ഉം 90. ചേർന്നാൽ 100.
mistake 45 + 65: made the tens add to ten and forgot the ones already make a ten
mistake 40 + 50: stopped one ten short

## ask
form: number
level: 2
en: You pay 100 rupees for crayons that cost 25 rupees. How many rupees do you get back?
ml: 25 രൂപയുടെ ക്രയോണിന് നീ 100 രൂപ കൊടുത്തു. എത്ര രൂപ ബാക്കി കിട്ടും?
answer: 75
hint.en: Which number pairs with 25 to make 100?
hint.ml: 25-നോടൊപ്പം ചേർന്ന് 100 ആക്കുന്ന സംഖ്യ ഏത്?
explain.en: From 25 to 30 is 5, and 30 to 100 is 70. You get back 75 rupees.
explain.ml: 25 മുതൽ 30 വരെ 5, 30 മുതൽ 100 വരെ 70. 75 രൂപ ബാക്കി കിട്ടും.
mistake 85: made the tens add to ten and forgot the ones already make a ten
mistake 125: added instead of finding the change

## story
en: You have a 100 rupee note and buy a pen for 60 rupees. The shopkeeper gives back 40. The price and the change are a pair, because together they make 100.
ml: നിന്റെ കയ്യിൽ 100 രൂപ നോട്ടുണ്ട്. 60 രൂപയ്ക്ക് ഒരു പേന വാങ്ങി. കടക്കാരൻ 40 തിരിച്ചു തന്നു. വിലയും ബാക്കിയും ഒരു ജോഡിയാണ്, കാരണം രണ്ടും ചേർന്നാൽ 100.

## picture
visual: numberline 0 100 60
en: Stand at 60. How far is it to 100? Four more jumps of ten. So 60 pairs with 40.
ml: 60-ൽ നിൽക്കൂ. 100 വരെ എത്ര ദൂരം? പത്തിന്റെ നാല് ചാട്ടം കൂടി. അതുകൊണ്ട് 60-ന്റെ ജോഡി 40.
