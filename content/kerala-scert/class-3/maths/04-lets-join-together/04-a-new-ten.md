# When the ones make a new ten
title.ml: ഒന്നുകൾ ഒരു പുതിയ പത്താകുമ്പോൾ
objective: Add three-digit numbers when the ones add up to more than 9.
concept: add-carry
concept.name: Adding when the ones make a new ten
concept.name.ml: ഒന്നുകൾ പത്താകുമ്പോഴുള്ള കൂട്ടൽ

## say
en: Let us add 248 and 135. Look at the ones first: 8 and 5 make 13. That is 1 ten and 3 ones.
ml: 248-ഉം 135-ഉം കൂട്ടാം. ആദ്യം ഒന്നുകൾ നോക്കൂ: 8-ഉം 5-ഉം ചേർന്നാൽ 13. അതായത് 1 പത്തും 3 ഒന്നുകളും.
visual: text 8 + 5 = 13

## say
en: The new ten moves over to join the tens. 300 and 70 and 13 make 383.
ml: ആ പുതിയ പത്ത് പത്തുകളുടെ കൂടെ ചേരും. 300-ഉം 70-ഉം 13-ഉം ചേർന്നാൽ 383.
visual: steps 200 + 100 = 300 / 40 + 30 = 70 / 8 + 5 = 13 / 300 + 70 + 13 = 383

## ask
form: number
en: 327 + 145 = ?
ml: 327 + 145 = ?
answer: 472
hint.en: Ones: 7 + 5 = 12. Keep the 2 and move the ten over to the tens.
hint.ml: ഒന്നുകൾ: 7 + 5 = 12. 2 അവിടെ വെച്ച്, പത്തിനെ പത്തുകളുടെ കൂടെ ചേർക്കൂ.
explain.en: 400 and 60 and 12 make 472.
explain.ml: 400-ഉം 60-ഉം 12-ഉം ചേർന്നാൽ 472.
mistake 462: forgot to add the new ten
mistake 4612: wrote 12 in the ones place without moving the ten

## ask
form: number
en: 418 + 357 = ?
ml: 418 + 357 = ?
answer: 775
hint.en: Ones: 8 + 7 = 15. Tens: 10 + 50, and one more ten.
hint.ml: ഒന്നുകൾ: 8 + 7 = 15. പത്തുകൾ: 10 + 50, പിന്നെ ഒരു പത്ത് കൂടി.
explain.en: 700 and 60 and 15 make 775.
explain.ml: 700-ഉം 60-ഉം 15-ഉം ചേർന്നാൽ 775.
mistake 765: forgot to add the new ten
mistake 7615: wrote 15 in the ones place without moving the ten

## ask
form: choice
en: 465 + 228 = ?
ml: 465 + 228 = ?
options: 693 | 683 | 6813
answer: 693
hint.en: Ones: 5 + 8 = 13. Do not forget the new ten.
hint.ml: ഒന്നുകൾ: 5 + 8 = 13. പുതിയ പത്ത് മറക്കരുത്.
explain.en: 600 and 80 and 13 make 693.
explain.ml: 600-ഉം 80-ഉം 13-ഉം ചേർന്നാൽ 693.
mistake 683: forgot to add the new ten
mistake 6813: wrote 13 in the ones place without moving the ten

## ask
form: number
level: 2
en: Try this one in your head. 640 + 360 = ?
ml: ഇത് മനസ്സിൽ ചെയ്തു നോക്കൂ. 640 + 360 = ?
answer: 1000
hint.en: 40 and 60 make a new hundred. Then add the hundreds.
hint.ml: 40-ഉം 60-ഉം ചേർന്നാൽ ഒരു പുതിയ നൂറ്. പിന്നെ നൂറുകൾ കൂട്ടൂ.
explain.en: 600 + 300 = 900, and 40 + 60 = 100. Together 1000.
explain.ml: 600 + 300 = 900, 40 + 60 = 100. ചേർന്നാൽ 1000.
mistake 900: forgot the new hundred made by the tens

## story
en: The ones jar can hold only 9 coins. When 8 coins and 5 coins meet, there are 13. Ten of them are tied into a bundle and moved to the tens jar. Only 3 stay behind.
ml: ഒന്നിന്റെ ഭരണിയിൽ 9 നാണയം മാത്രമേ കൊള്ളൂ. 8 നാണയവും 5 നാണയവും ചേർന്നാൽ 13. അതിൽ പത്തെണ്ണം ഒരു കെട്ടാക്കി പത്തിന്റെ ഭരണിയിലേക്ക് മാറ്റും. 3 മാത്രം ബാക്കി.

## picture
visual: steps 8 + 5 = 13 / 13 = 10 + 3 / the 10 joins the tens
en: When the ones go past 9, a new ten is made. Move it over to the tens.
ml: ഒന്നുകൾ 9 കടന്നാൽ ഒരു പുതിയ പത്ത് ഉണ്ടാകും. അതിനെ പത്തുകളിലേക്ക് മാറ്റൂ.
