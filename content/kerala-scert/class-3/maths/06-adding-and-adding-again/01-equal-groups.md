# Equal groups
title.ml: തുല്യ കൂട്ടങ്ങൾ
objective: Count objects arranged in equal groups.
objective.ml: തുല്യ കൂട്ടങ്ങളായി വെച്ച വസ്തുക്കൾ എണ്ണുക.
concept: equal-groups
concept.name: Counting equal groups
concept.name.ml: തുല്യ കൂട്ടങ്ങൾ എണ്ണൽ
minutes: 5

## say
en: It is the school anniversary, and snacks are being shared. Look! Here are 3 baskets. Each basket has 4 mangoes.
ml: സ്കൂൾ വാർഷികമാണ്, പലഹാരങ്ങൾ പങ്കുവെക്കുന്നു. നോക്കൂ! ഇതാ 3 കൊട്ടകൾ. ഓരോ കൊട്ടയിലും 4 മാങ്ങ വീതം.
visual: groups 3 4 🥭

## say
en: Every basket has the same number of mangoes. We call these equal groups. To find the total we add 4 again and again: 4 + 4 + 4.
ml: എല്ലാ കൊട്ടയിലും ഒരേ എണ്ണം മാങ്ങയുണ്ട്. ഇവയെ തുല്യ കൂട്ടങ്ങൾ എന്ന് പറയും. ആകെ എത്രയെന്നറിയാൻ 4 വീണ്ടും വീണ്ടും കൂട്ടണം: 4 + 4 + 4.
visual: groups 3 4 🥭

## say
en: Equal groups must all have the same number. If one basket had 5 mangoes and another had 3, they would not be equal groups.
ml: തുല്യ കൂട്ടങ്ങളിൽ എല്ലാത്തിലും ഒരേ എണ്ണം വേണം. ഒരു കൊട്ടയിൽ 5-ഉം മറ്റൊന്നിൽ 3-ഉം ആണെങ്കിൽ അവ തുല്യ കൂട്ടങ്ങളല്ല.
visual: groups 2 4 🥭

## say
label: example
en: 2 plates with 3 idlis each: count 3, then 6. There are 6 idlis.
ml: 3 ഇഡ്ഡലി വീതമുള്ള 2 പാത്രങ്ങൾ: 3, പിന്നെ 6. ആകെ 6 ഇഡ്ഡലി.
visual: groups 2 3 ⚪

## ask
form: choice
en: How many mangoes are there in all?
ml: ആകെ എത്ര മാങ്ങയുണ്ട്?
visual: groups 3 4 🥭
options: 7 | 12 | 34
answer: 12
hint.en: Count basket by basket: 4, then 8, then...
hint.ml: ഓരോ കൊട്ടയായി എണ്ണൂ: 4, പിന്നെ 8, പിന്നെ...
explain.en: 4 and 4 and 4 make 12. Three equal groups of 4 is 12.
explain.ml: 4-ഉം 4-ഉം 4-ഉം ചേർന്നാൽ 12. നാലിന്റെ മൂന്ന് കൂട്ടങ്ങൾ 12 ആണ്.
mistake 7: added 3 and 4 instead of counting every group
mistake 34: joined the two numbers together

## ask
form: number
en: 2 plates. 5 laddus on each plate. How many laddus altogether?
ml: 2 പാത്രങ്ങൾ. ഓരോ പാത്രത്തിലും 5 ലഡ്ഡു. ആകെ എത്ര ലഡ്ഡു?
visual: groups 2 5 🟡
answer: 10
hint.en: Count the first plate, then keep counting on the second plate.
hint.ml: ആദ്യത്തെ പാത്രം എണ്ണൂ, പിന്നെ രണ്ടാമത്തേതിൽ തുടർന്ന് എണ്ണൂ.
explain.en: 5 and 5 make 10.
explain.ml: 5-ഉം 5-ഉം ചേർന്നാൽ 10.
mistake 7: added 2 and 5 instead of counting every group

## ask
form: choice
level: 2
en: Which one means the same as 3 groups of 5?
ml: അഞ്ചിന്റെ 3 കൂട്ടങ്ങൾ എന്നതിന് തുല്യമായത് ഏത്?
options: 5 + 5 + 5 | 3 + 5 | 35
answer: 5 + 5 + 5
hint.en: Imagine 3 bags. Each bag has 5 things.
hint.ml: 3 സഞ്ചികൾ സങ്കൽപ്പിക്കൂ. ഓരോന്നിലും 5 സാധനങ്ങൾ.
explain.en: 3 groups of 5 means 5, three times: 5 + 5 + 5.
explain.ml: അഞ്ചിന്റെ 3 കൂട്ടങ്ങൾ എന്നാൽ 5 മൂന്ന് തവണ: 5 + 5 + 5.
mistake 3 + 5: added the two numbers instead of repeating the group
mistake 35: joined the two numbers together

## ask
form: number
level: 2
en: There are 4 bags. Each bag has 2 balls. How many balls?
ml: 4 സഞ്ചികളുണ്ട്. ഓരോ സഞ്ചിയിലും 2 പന്തുകൾ. ആകെ എത്ര പന്തുകൾ?
answer: 8
hint.en: Try drawing 4 bags and putting 2 dots in each.
hint.ml: 4 സഞ്ചികൾ വരച്ച് ഓരോന്നിലും 2 കുത്തുകൾ ഇട്ടു നോക്കൂ.
explain.en: 2 and 2 and 2 and 2 make 8.
explain.ml: 2-ഉം 2-ഉം 2-ഉം 2-ഉം ചേർന്നാൽ 8.
visual: groups 4 2 ⚽
mistake 6: added 4 and 2 instead of counting every group

## story
en: Amma puts 4 unniyappams on each of 3 plates. To know how many she made, she counts plate by plate: 4, 8, 12.
ml: അമ്മ 3 പാത്രങ്ങളിൽ 4 വീതം ഉണ്ണിയപ്പം വെച്ചു. ആകെ എത്രയെന്നറിയാൻ ഓരോ പാത്രമായി എണ്ണി: 4, 8, 12.

## picture
visual: array 3 4 🟤
en: 3 rows with 4 in each row. Count row by row: 4, 8, 12.
ml: 4 വീതമുള്ള 3 വരികൾ. ഓരോ വരിയായി എണ്ണൂ: 4, 8, 12.
