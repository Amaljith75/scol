# Cut and join
title.ml: മുറിക്കാം, ചേർക്കാം
objective: See that shapes can be cut into, and built from, other shapes.
concept: shape-join
concept.name: Shapes inside shapes
concept.name.ml: രൂപങ്ങൾക്കുള്ളിലെ രൂപങ്ങൾ

## say
en: Take a paper rectangle. Cut it in a straight line from one corner to the opposite corner.
ml: ഒരു ചതുരക്കടലാസ് എടുക്കൂ. ഒരു മൂലയിൽ നിന്ന് എതിർമൂലയിലേക്ക് നേരെ മുറിക്കൂ.
visual: shapes rectangle

## say
en: Look, you get two triangles! Shapes can hide inside other shapes.
ml: നോക്കൂ, രണ്ട് ത്രികോണങ്ങൾ കിട്ടി! രൂപങ്ങൾക്കുള്ളിൽ വേറെ രൂപങ്ങൾ ഒളിഞ്ഞിരിക്കാം.
visual: shapes triangle triangle

## ask
form: number
en: A rectangle is cut once, from corner to corner. How many triangles do you get?
ml: ഒരു ചതുരം മൂലയിൽ നിന്ന് മൂലയിലേക്ക് ഒരു തവണ മുറിച്ചു. എത്ര ത്രികോണങ്ങൾ കിട്ടും?
answer: 2
hint.en: One cut makes two pieces. What shape is each piece?
hint.ml: ഒരു മുറിക്കൽ രണ്ട് കഷണങ്ങൾ തരും. ഓരോ കഷണത്തിന്റെയും രൂപം എന്താണ്?
explain.en: One corner-to-corner cut gives 2 triangles.
explain.ml: മൂലയിൽ നിന്ന് മൂലയിലേക്ക് ഒരു തവണ മുറിച്ചാൽ 2 ത്രികോണങ്ങൾ കിട്ടും.
mistake 1: did not count both pieces
mistake 4: counted corners instead of pieces

## ask
form: choice
en: Put the two triangles back exactly as they were. Which shape comes back?
ml: ആ രണ്ട് ത്രികോണങ്ങൾ പഴയതുപോലെ ചേർത്തുവെച്ചാൽ ഏത് രൂപം തിരിച്ചുകിട്ടും?
visual: shapes triangle triangle
options: rectangle | circle
options.ml: ചതുരം | വൃത്തം
answer: rectangle
hint.en: What shape did we cut at the start?
hint.ml: ആദ്യം നമ്മൾ മുറിച്ചത് ഏത് രൂപമായിരുന്നു?
explain.en: The two triangles join to make the rectangle again.
explain.ml: രണ്ട് ത്രികോണങ്ങൾ ചേർന്നാൽ വീണ്ടും ചതുരമാകും.

## ask
form: choice
level: 2
en: Can one straight cut turn a circle into two triangles?
ml: ഒരു വൃത്തം നേരെ ഒരു തവണ മുറിച്ചാൽ രണ്ട് ത്രികോണങ്ങൾ കിട്ടുമോ?
visual: shapes circle
options: No | Yes
options.ml: ഇല്ല | കിട്ടും
answer: No
hint.en: A triangle needs straight sides. Does a circle have any straight side?
hint.ml: ത്രികോണത്തിന് നേർവശങ്ങൾ വേണം. വൃത്തത്തിന് നേർവശമുണ്ടോ?
explain.en: The pieces of a circle keep a curved edge, so they are not triangles.
explain.ml: വൃത്തത്തിന്റെ കഷണങ്ങൾക്ക് വളഞ്ഞ അരികുണ്ട്. അതുകൊണ്ട് അവ ത്രികോണങ്ങളല്ല.
mistake Yes: thinks any cut piece is a triangle

## ask
form: number
level: 2
en: One triangle has 3 sides. How many sides do two separate triangles have altogether?
ml: ഒരു ത്രികോണത്തിന് 3 വശങ്ങൾ. വേറെ വേറെ വെച്ച രണ്ട് ത്രികോണങ്ങൾക്ക് ആകെ എത്ര വശങ്ങൾ?
visual: shapes triangle triangle
answer: 6
hint.en: Count the sides of the first one, then keep counting on the second.
hint.ml: ആദ്യത്തേതിന്റെ വശങ്ങൾ എണ്ണൂ, പിന്നെ രണ്ടാമത്തേതിൽ തുടർന്ന് എണ്ണൂ.
explain.en: 3 and 3 make 6 sides.
explain.ml: 3-ഉം 3-ഉം ചേർന്നാൽ 6 വശങ്ങൾ.
mistake 3: counted only one triangle

## story
en: Amma cuts a rectangular dosa from corner to corner. Now there are two triangle pieces, one for you and one for me. Put them back together and the rectangle returns.
ml: അമ്മ ചതുരത്തിലുള്ള ഒരു ദോശ മൂലയിൽ നിന്ന് മൂലയിലേക്ക് മുറിച്ചു. ഇപ്പോൾ രണ്ട് ത്രികോണക്കഷണങ്ങൾ, ഒന്ന് നിനക്ക്, ഒന്ന് എനിക്ക്. അവ ചേർത്തുവെച്ചാൽ ചതുരം തിരിച്ചുവരും.

## picture
visual: shapes rectangle triangle triangle
en: One rectangle. One cut from corner to corner. Two triangles.
ml: ഒരു ചതുരം. മൂലയിൽ നിന്ന് മൂലയിലേക്ക് ഒരു മുറിക്കൽ. രണ്ട് ത്രികോണങ്ങൾ.
