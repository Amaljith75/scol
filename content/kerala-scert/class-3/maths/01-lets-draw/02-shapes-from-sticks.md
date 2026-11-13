# Shapes from sticks
title.ml: ഈർക്കിൽ കൊണ്ട് രൂപങ്ങൾ
objective: Know how many sides a triangle and a rectangle need.
concept: shape-sides
concept.name: Sides of shapes
concept.name.ml: രൂപങ്ങളുടെ വശങ്ങൾ

## say
en: Let us make shapes with small sticks, like eerkkil bits from a coconut leaf.
ml: ഈർക്കിൽ കഷണങ്ങൾ കൊണ്ട് നമുക്ക് രൂപങ്ങൾ ഉണ്ടാക്കാം.
visual: sticks 7

## say
en: 3 sticks make a triangle. 4 sticks make a rectangle.
ml: 3 ഈർക്കിൽ കൊണ്ട് ഒരു ത്രികോണം. 4 ഈർക്കിൽ കൊണ്ട് ഒരു ചതുരം.
visual: steps Triangle = 3 sticks / Rectangle = 4 sticks

## say
en: Each straight side of a shape is one stick. So to know how many sticks you need, count the sides.
ml: ഒരു രൂപത്തിന്റെ ഓരോ നേർവശവും ഒരു ഈർക്കിലാണ്. എത്ര ഈർക്കിൽ വേണമെന്നറിയാൻ വശങ്ങൾ എണ്ണിയാൽ മതി.
visual: shapes triangle rectangle

## say
label: example
en: Two triangles need 3 sticks and 3 more sticks. That is 6 sticks.
ml: രണ്ട് ത്രികോണങ്ങൾക്ക് 3 ഈർക്കിലും 3 ഈർക്കിൽ കൂടിയും വേണം. ആകെ 6 ഈർക്കിൽ.
visual: steps 3 + 3 = 6

## ask
form: number
en: How many sticks do you need to make 2 triangles?
ml: 2 ത്രികോണങ്ങൾ ഉണ്ടാക്കാൻ എത്ര ഈർക്കിൽ വേണം?
visual: shapes triangle triangle
answer: 6
hint.en: One triangle needs 3. Now add 3 more for the second one.
hint.ml: ഒരു ത്രികോണത്തിന് 3 വേണം. രണ്ടാമത്തേതിന് 3 കൂടി ചേർക്കൂ.
explain.en: 3 and 3 make 6 sticks.
explain.ml: 3-ഉം 3-ഉം ചേർന്നാൽ 6 ഈർക്കിൽ.
mistake 3: counted sticks for only one triangle
mistake 5: added the number of shapes to the sticks

## ask
form: number
en: How many sticks do you need to make 2 rectangles?
ml: 2 ചതുരങ്ങൾ ഉണ്ടാക്കാൻ എത്ര ഈർക്കിൽ വേണം?
visual: shapes rectangle rectangle
answer: 8
hint.en: One rectangle needs 4 sticks.
hint.ml: ഒരു ചതുരത്തിന് 4 ഈർക്കിൽ വേണം.
explain.en: 4 and 4 make 8 sticks.
explain.ml: 4-ഉം 4-ഉം ചേർന്നാൽ 8 ഈർക്കിൽ.
mistake 6: used 3 sticks for a rectangle
mistake 4: counted sticks for only one rectangle

## ask
form: choice
level: 2
en: You have 12 sticks. You make only triangles. How many triangles can you make?
ml: നിന്റെ കയ്യിൽ 12 ഈർക്കിലുണ്ട്. ത്രികോണങ്ങൾ മാത്രം ഉണ്ടാക്കിയാൽ എത്രയെണ്ണം കിട്ടും?
visual: sticks 12
options: 4 | 3 | 12
answer: 4
hint.en: Keep taking 3 sticks at a time: 3, 6, 9, 12.
hint.ml: 3 വീതം എടുത്തു നോക്കൂ: 3, 6, 9, 12.
explain.en: 3 + 3 + 3 + 3 = 12. So 12 sticks make 4 triangles.
explain.ml: 3 + 3 + 3 + 3 = 12. അതുകൊണ്ട് 12 ഈർക്കിൽ കൊണ്ട് 4 ത്രികോണങ്ങൾ.
mistake 3: used 4 sticks for each triangle
mistake 12: counted the sticks instead of the triangles

## ask
form: choice
level: 2
en: With the same 12 sticks you make only rectangles. How many rectangles?
ml: അതേ 12 ഈർക്കിൽ കൊണ്ട് ചതുരങ്ങൾ മാത്രം ഉണ്ടാക്കിയാൽ എത്രയെണ്ണം?
visual: sticks 12
options: 3 | 4 | 6
answer: 3
hint.en: Keep taking 4 sticks at a time: 4, 8, 12.
hint.ml: 4 വീതം എടുത്തു നോക്കൂ: 4, 8, 12.
explain.en: 4 + 4 + 4 = 12. So 12 sticks make 3 rectangles.
explain.ml: 4 + 4 + 4 = 12. അതുകൊണ്ട് 12 ഈർക്കിൽ കൊണ്ട് 3 ചതുരങ്ങൾ.
mistake 4: used 3 sticks for each rectangle

## ask
form: build
en: Drag the sticks to build the shape that has 3 sides.
ml: 3 വശങ്ങളുള്ള രൂപം ഈർക്കിലുകൾ വലിച്ചുവെച്ച് ഉണ്ടാക്കൂ.
options: triangle | rectangle
answer: triangle
hint.en: Count the sides of each outline before you build.
hint.ml: ഉണ്ടാക്കുന്നതിന് മുമ്പ് ഓരോ രൂപരേഖയുടെയും വശങ്ങൾ എണ്ണൂ.
explain.en: A triangle has 3 sides, so it takes 3 sticks.
explain.ml: ത്രികോണത്തിന് 3 വശങ്ങൾ, അതുകൊണ്ട് 3 ഈർക്കിൽ മതി.
mistake rectangle: built the 4-sided shape when asked for 3 sides

## ask
form: build
level: 2
en: Now build the shape that needs 4 sticks.
ml: ഇനി 4 ഈർക്കിൽ വേണ്ട രൂപം ഉണ്ടാക്കൂ.
options: triangle | rectangle
answer: rectangle
hint.en: Which outline has 4 sides?
hint.ml: ഏത് രൂപരേഖയ്ക്കാണ് 4 വശങ്ങൾ?
explain.en: A rectangle has 4 sides, so it takes 4 sticks.
explain.ml: ചതുരത്തിന് 4 വശങ്ങൾ, അതുകൊണ്ട് 4 ഈർക്കിൽ വേണം.
mistake triangle: built the 3-sided shape when asked for 4 sticks

## story
en: A little bird builds with twigs. For a triangle nest it carries 3 twigs. For a rectangle window it carries 4. For two triangles it must bring 3, and then 3 more.
ml: ഒരു കൊച്ചു കിളി ചുള്ളിക്കമ്പുകൾ കൊണ്ട് പണിയുന്നു. ത്രികോണക്കൂടിന് 3 കമ്പ്. ചതുരജനലിന് 4 കമ്പ്. രണ്ട് ത്രികോണത്തിന് 3-ഉം പിന്നെ 3 കൂടിയും കൊണ്ടുവരണം.

## picture
visual: steps 1 triangle = 3 sticks / 2 triangles = 3 + 3 = 6 / 1 rectangle = 4 sticks
en: Each side is one stick. Count the sides and you know how many sticks.
ml: ഓരോ വശവും ഒരു ഈർക്കിൽ. വശങ്ങൾ എണ്ണിയാൽ എത്ര ഈർക്കിൽ വേണമെന്ന് അറിയാം.
