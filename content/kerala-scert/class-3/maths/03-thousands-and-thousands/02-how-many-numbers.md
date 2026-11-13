# How many numbers?
title.ml: എത്ര സംഖ്യകൾ?
objective: Count how many numbers there are from one number to another.
concept: counting-range
concept.name: Counting numbers in a range
concept.name.ml: ഒരു പരിധിയിലെ സംഖ്യകൾ എണ്ണൽ

## say
en: Number cards from 10 to 20 are made for a race. How many cards is that? Careful! We must count both the first card and the last card.
ml: ഒരു ഓട്ടമത്സരത്തിന് 10 മുതൽ 20 വരെ നമ്പർ കാർഡുകൾ ഉണ്ടാക്കി. എത്ര കാർഡുകൾ? ശ്രദ്ധിക്കൂ! ആദ്യത്തെ കാർഡും അവസാനത്തെ കാർഡും എണ്ണണം.
visual: numberline 10 20

## say
en: 20 minus 10 is 10. But that leaves out the first card. Add 1 for it. So there are 11 cards.
ml: 20-ൽ നിന്ന് 10 കുറച്ചാൽ 10. പക്ഷേ അതിൽ ആദ്യത്തെ കാർഡ് ഇല്ല. അതിനായി 1 ചേർക്കൂ. അപ്പോൾ 11 കാർഡുകൾ.
visual: text 20 − 10 + 1 = 11

## say
en: Here is the rule: last number, take away the first number, then add 1.
ml: നിയമം ഇതാണ്: അവസാന സംഖ്യയിൽ നിന്ന് ആദ്യ സംഖ്യ കുറയ്ക്കുക, പിന്നെ 1 ചേർക്കുക.
visual: text last − first + 1

## say
label: example
en: Cards from 1 to 5. 5 take away 1 is 4. Add 1, and you get 5 cards: 1, 2, 3, 4, 5.
ml: 1 മുതൽ 5 വരെ കാർഡുകൾ. 5-ൽ നിന്ന് 1 കുറച്ചാൽ 4. 1 ചേർത്താൽ 5 കാർഡുകൾ: 1, 2, 3, 4, 5.
visual: numberline 1 5

## ask
form: number
en: Cards are numbered from 1 to 10. How many cards?
ml: 1 മുതൽ 10 വരെ നമ്പറിട്ട കാർഡുകൾ. എത്ര കാർഡുകൾ?
visual: numberline 1 10
answer: 10
hint.en: Count them on your fingers: 1, 2, 3, ...
hint.ml: വിരലിൽ എണ്ണൂ: 1, 2, 3, ...
explain.en: From 1 to 10 there are 10 cards.
explain.ml: 1 മുതൽ 10 വരെ 10 കാർഡുകൾ.
mistake 9: subtracted and forgot to count the first card

## ask
form: number
en: Cards from 30 to 50 are made for swimming. How many cards?
ml: നീന്തൽ മത്സരത്തിന് 30 മുതൽ 50 വരെ കാർഡുകൾ. എത്ര കാർഡുകൾ?
answer: 21
hint.en: 50 minus 30, then add 1 for the first card.
hint.ml: 50-ൽ നിന്ന് 30 കുറയ്ക്കൂ, പിന്നെ ആദ്യത്തെ കാർഡിനായി 1 ചേർക്കൂ.
explain.en: 50 − 30 = 20, and 1 more for the first card makes 21.
explain.ml: 50 − 30 = 20, ആദ്യത്തെ കാർഡിനായി 1 കൂടി ചേർത്താൽ 21.
mistake 20: subtracted and forgot to count the first card

## ask
form: number
level: 2
en: Cards from 60 to 100. How many cards?
ml: 60 മുതൽ 100 വരെ കാർഡുകൾ. എത്ര കാർഡുകൾ?
answer: 41
hint.en: 100 minus 60, then add 1.
hint.ml: 100-ൽ നിന്ന് 60 കുറയ്ക്കൂ, പിന്നെ 1 ചേർക്കൂ.
explain.en: 100 − 60 = 40, and 1 more makes 41.
explain.ml: 100 − 60 = 40, 1 കൂടി ചേർത്താൽ 41.
mistake 40: subtracted and forgot to count the first card

## ask
form: choice
level: 2
en: Two-digit numbers go from 10 to 99. How many two-digit numbers are there?
ml: രണ്ടക്ക സംഖ്യകൾ 10 മുതൽ 99 വരെയാണ്. ആകെ എത്ര രണ്ടക്ക സംഖ്യകളുണ്ട്?
options: 90 | 89 | 99
answer: 90
hint.en: 99 minus 10, then add 1.
hint.ml: 99-ൽ നിന്ന് 10 കുറയ്ക്കൂ, പിന്നെ 1 ചേർക്കൂ.
explain.en: 99 − 10 = 89, and 1 more makes 90.
explain.ml: 99 − 10 = 89, 1 കൂടി ചേർത്താൽ 90.
mistake 89: subtracted and forgot to count the first number
mistake 99: counted the one-digit numbers too

## story
en: Children stand in a line with tokens 10 to 20. The teacher subtracts and says there are 10 children. But the child holding token 10 says, you forgot me! So we add 1 for the first child.
ml: 10 മുതൽ 20 വരെ ടോക്കണുമായി കുട്ടികൾ വരിയായി നിൽക്കുന്നു. ടീച്ചർ കുറച്ചു നോക്കി 10 കുട്ടികൾ എന്ന് പറഞ്ഞു. പക്ഷേ 10-ാം ടോക്കണുള്ള കുട്ടി പറഞ്ഞു, എന്നെ മറന്നു! അതുകൊണ്ട് ആദ്യത്തെ കുട്ടിക്കായി 1 ചേർക്കണം.

## picture
visual: numberline 10 20
en: Count every number on the line, including the first one and the last one. There are 11.
ml: വരയിലെ എല്ലാ സംഖ്യയും എണ്ണൂ, ആദ്യത്തേതും അവസാനത്തേതും ഉൾപ്പെടെ. ആകെ 11.
