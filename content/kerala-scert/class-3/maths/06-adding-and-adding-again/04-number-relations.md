# Number relations
title.ml: സംഖ്യാബന്ധങ്ങൾ
objective: Find relations between multiplication facts.
concept: mult-relations
concept.name: Relations between multiplication facts
concept.name.ml: ഗുണനത്തിലെ ബന്ധങ്ങൾ

## say
en: Look at these. 2 × 3 = 6. 4 × 3 = 12. 8 × 3 = 24. When the number of groups doubles, the answer doubles too.
ml: ഇവ നോക്കൂ. 2 × 3 = 6. 4 × 3 = 12. 8 × 3 = 24. കൂട്ടങ്ങളുടെ എണ്ണം ഇരട്ടിയാകുമ്പോൾ ഉത്തരവും ഇരട്ടിയാകും.
visual: steps 2 × 3 = 6 / 4 × 3 = 12 / 8 × 3 = 24

## say
en: Doubling is a shortcut. If you know 2 × 4 = 8, then 4 × 4 is 8 doubled, which is 16.
ml: ഇരട്ടിയാക്കൽ ഒരു എളുപ്പവഴിയാണ്. 2 × 4 = 8 എന്നറിയാമെങ്കിൽ 4 × 4 എന്നാൽ 8-ന്റെ ഇരട്ടി, 16.
visual: steps 2 × 4 = 8 / 4 × 4 = 16

## say
label: example
en: Turning rows into columns does not change the number. 2 × 5 and 5 × 2 are both 10.
ml: വരികൾ നിരകളാക്കിയാൽ എണ്ണം മാറില്ല. 2 × 5-ഉം 5 × 2-ഉം രണ്ടും 10.
visual: array 2 5 🔵

## ask
form: number
en: 2 × 5 = 10. So what is 4 × 5?
ml: 2 × 5 = 10. അപ്പോൾ 4 × 5 എത്ര?
answer: 20
hint.en: 4 groups is double 2 groups. Double the answer.
hint.ml: 4 കൂട്ടങ്ങൾ 2 കൂട്ടങ്ങളുടെ ഇരട്ടി. ഉത്തരവും ഇരട്ടിയാക്കൂ.
explain.en: Double 10 is 20. So 4 × 5 = 20.
explain.ml: 10-ന്റെ ഇരട്ടി 20. അതുകൊണ്ട് 4 × 5 = 20.
mistake 12: added 2 to the answer instead of doubling it

## ask
form: number
en: 3 × 5 = 15. So what is 5 × 3?
ml: 3 × 5 = 15. അപ്പോൾ 5 × 3 എത്ര?
visual: array 3 5 🔵
answer: 15
hint.en: Turn the picture sideways. Rows become columns. Does the number of dots change?
hint.ml: ചിത്രം ചരിച്ചു നോക്കൂ. വരികൾ നിരകളാകും. കുത്തുകളുടെ എണ്ണം മാറുമോ?
explain.en: 3 fives and 5 threes are the same dots counted another way. Both are 15.
explain.ml: 3 അഞ്ചുകളും 5 മൂന്നുകളും ഒരേ കുത്തുകൾ രണ്ട് രീതിയിൽ എണ്ണുന്നതാണ്. രണ്ടും 15.

## say
en: Different pairs can give the same answer. 1 × 12, 2 × 6 and 3 × 4 all make 12.
ml: വ്യത്യസ്ത ജോഡികൾ ഒരേ ഉത്തരം തരാം. 1 × 12, 2 × 6, 3 × 4 ഇവയെല്ലാം 12.
visual: steps 1 × 12 = 12 / 2 × 6 = 12 / 3 × 4 = 12

## ask
form: choice
en: Which of these makes 24?
ml: ഇവയിൽ 24 കിട്ടുന്നത് ഏത്?
options: 4 × 6 | 4 × 5 | 2 × 10
answer: 4 × 6
hint.en: You know 2 × 6 = 12. Double the groups.
hint.ml: 2 × 6 = 12 എന്ന് അറിയാം. കൂട്ടങ്ങൾ ഇരട്ടിയാക്കൂ.
explain.en: 2 × 6 = 12, so 4 × 6 = 24.
explain.ml: 2 × 6 = 12, അതുകൊണ്ട് 4 × 6 = 24.

## ask
form: choice
level: 2
en: 2 + 3 = 5. But what is 2 × 3?
ml: 2 + 3 = 5. എന്നാൽ 2 × 3 എത്ര?
options: 6 | 5 | 23
answer: 6
hint.en: × means groups. 2 groups of 3.
hint.ml: × എന്നാൽ കൂട്ടങ്ങൾ. മൂന്നിന്റെ 2 കൂട്ടങ്ങൾ.
explain.en: 2 groups of 3 is 3 + 3 = 6. Adding and multiplying usually give different answers.
explain.ml: മൂന്നിന്റെ 2 കൂട്ടങ്ങൾ 3 + 3 = 6. കൂട്ടലും ഗുണനവും മിക്കപ്പോഴും വ്യത്യസ്ത ഉത്തരം തരും.
mistake 5: read × as adding
mistake 23: joined the two numbers together

## ask
form: number
level: 2
en: In cricket, one over has 6 balls. How many balls are bowled in 20 overs?
ml: ക്രിക്കറ്റിൽ ഒരു ഓവറിൽ 6 പന്തുകൾ. 20 ഓവറിൽ എത്ര പന്തുകൾ എറിയും?
answer: 120
hint.en: 10 overs have 60 balls. 20 overs are double that.
hint.ml: 10 ഓവറിൽ 60 പന്തുകൾ. 20 ഓവറിൽ അതിന്റെ ഇരട്ടി.
explain.en: 60 and 60 make 120. So 20 × 6 = 120.
explain.ml: 60-ഉം 60-ഉം ചേർന്നാൽ 120. അതുകൊണ്ട് 20 × 6 = 120.
mistake 26: added 20 and 6 instead of making groups

## story
en: A shop sells pens in packets of 3. Two packets have 6 pens. If you buy twice as many packets, you get twice as many pens: 4 packets have 12.
ml: ഒരു കടയിൽ പേനകൾ 3 വീതം പാക്കറ്റിലാണ്. രണ്ട് പാക്കറ്റിൽ 6 പേന. ഇരട്ടി പാക്കറ്റ് വാങ്ങിയാൽ ഇരട്ടി പേന കിട്ടും: 4 പാക്കറ്റിൽ 12.

## picture
visual: steps 2 × 3 = 6 / 4 × 3 = 12 / twice the groups, twice the answer
en: When the groups double, the answer doubles.
ml: കൂട്ടങ്ങൾ ഇരട്ടിയായാൽ ഉത്തരവും ഇരട്ടിയാകും.
