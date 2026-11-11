# Adding big numbers in parts
title.ml: വലിയ സംഖ്യകൾ ഭാഗങ്ങളാക്കി കൂട്ടാം
objective: Add three-digit numbers by splitting them into hundreds, tens and ones.
concept: add-split
concept.name: Adding by splitting into hundreds, tens and ones
concept.name.ml: നൂറുകളും പത്തുകളും ഒന്നുകളുമാക്കി കൂട്ടൽ

## say
en: To add 231 and 146, split each number into hundreds, tens and ones.
ml: 231-ഉം 146-ഉം കൂട്ടാൻ, ഓരോ സംഖ്യയെയും നൂറുകൾ, പത്തുകൾ, ഒന്നുകൾ ആയി പിരിക്കൂ.
visual: steps 231 = 200 + 30 + 1 / 146 = 100 + 40 + 6

## say
en: Now add the hundreds, then the tens, then the ones. 300 and 70 and 7. The sum is 377.
ml: ഇനി നൂറുകൾ കൂട്ടൂ, പിന്നെ പത്തുകൾ, പിന്നെ ഒന്നുകൾ. 300-ഉം 70-ഉം 7-ഉം. ആകെ 377.
visual: steps 200 + 100 = 300 / 30 + 40 = 70 / 1 + 6 = 7 / 231 + 146 = 377

## ask
form: number
en: 310 + 230 = ?
ml: 310 + 230 = ?
answer: 540
hint.en: Add the hundreds: 300 and 200. Then the tens: 10 and 30.
hint.ml: നൂറുകൾ കൂട്ടൂ: 300-ഉം 200-ഉം. പിന്നെ പത്തുകൾ: 10-ഉം 30-ഉം.
explain.en: 500 and 40 make 540.
explain.ml: 500-ഉം 40-ഉം ചേർന്നാൽ 540.
mistake 504: put the tens in the ones place

## ask
form: number
en: 315 + 231 = ?
ml: 315 + 231 = ?
answer: 546
hint.en: Hundreds: 300 + 200. Tens: 10 + 30. Ones: 5 + 1.
hint.ml: നൂറുകൾ: 300 + 200. പത്തുകൾ: 10 + 30. ഒന്നുകൾ: 5 + 1.
explain.en: 500 and 40 and 6 make 546.
explain.ml: 500-ഉം 40-ഉം 6-ഉം ചേർന്നാൽ 546.
mistake 540: left out the ones

## ask
form: choice
en: 524 + 312 = ?
ml: 524 + 312 = ?
options: 836 | 846 | 736
answer: 836
hint.en: Hundreds: 500 + 300. Tens: 20 + 10. Ones: 4 + 2.
hint.ml: നൂറുകൾ: 500 + 300. പത്തുകൾ: 20 + 10. ഒന്നുകൾ: 4 + 2.
explain.en: 800 and 30 and 6 make 836.
explain.ml: 800-ഉം 30-ഉം 6-ഉം ചേർന്നാൽ 836.
mistake 846: made a slip adding the tens
mistake 736: made a slip adding the hundreds

## ask
form: number
level: 2
en: 243 children came from one school and 325 from another. How many children came in all?
ml: ഒരു സ്കൂളിൽ നിന്ന് 243 കുട്ടികളും മറ്റൊരു സ്കൂളിൽ നിന്ന് 325 കുട്ടികളും വന്നു. ആകെ എത്ര കുട്ടികൾ?
answer: 568
hint.en: Split both numbers, then add hundreds, tens and ones.
hint.ml: രണ്ട് സംഖ്യകളും പിരിച്ച്, നൂറുകളും പത്തുകളും ഒന്നുകളും കൂട്ടൂ.
explain.en: 200 + 300 = 500, 40 + 20 = 60, 3 + 5 = 8. In all 568.
explain.ml: 200 + 300 = 500, 40 + 20 = 60, 3 + 5 = 8. ആകെ 568.

## ask
form: abacus
en: Work out 120 + 230. Show the answer on the abacus.
ml: 120 + 230 കണക്കാക്കൂ. ഉത്തരം മണിച്ചട്ടത്തിൽ കാണിക്കൂ.
answer: 350
hint.en: Hundreds: 1 and 2. Tens: 2 and 3.
hint.ml: നൂറുകൾ: 1-ഉം 2-ഉം. പത്തുകൾ: 2-ഉം 3-ഉം.
explain.en: 300 and 50 make 350: 3 beads on hundreds and 5 on tens.
explain.ml: 300-ഉം 50-ഉം ചേർന്നാൽ 350: നൂറിൽ 3 മണി, പത്തിൽ 5.
mistake 305: put the tens on the ones rod

## story
en: Two classes bring coins in three jars: one jar for hundreds, one for tens, one for ones. Pour hundreds with hundreds, tens with tens, ones with ones. Then read the three jars.
ml: രണ്ട് ക്ലാസുകൾ മൂന്ന് ഭരണികളിൽ നാണയങ്ങൾ കൊണ്ടുവന്നു: നൂറിന് ഒന്ന്, പത്തിന് ഒന്ന്, ഒന്നിന് ഒന്ന്. നൂറുകൾ നൂറുകളോട്, പത്തുകൾ പത്തുകളോട്, ഒന്നുകൾ ഒന്നുകളോട് ചേർക്കൂ. പിന്നെ മൂന്ന് ഭരണികളും വായിക്കൂ.

## picture
visual: steps 231 + 146 / 200 + 100 = 300 / 30 + 40 = 70 / 1 + 6 = 7 / 300 + 70 + 7 = 377
en: Add each place on its own. Then put them together.
ml: ഓരോ സ്ഥാനവും വെവ്വേറെ കൂട്ടൂ. പിന്നെ എല്ലാം ചേർക്കൂ.
