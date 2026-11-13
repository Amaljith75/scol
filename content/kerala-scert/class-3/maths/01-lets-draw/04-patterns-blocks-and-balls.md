# Patterns, blocks and balls
title.ml: ക്രമങ്ങളും കട്ടകളും പന്തുകളും
objective: Continue a repeating pattern and tell a block from a sphere.
concept: patterns-solids
concept.name: Patterns and solid shapes
concept.name.ml: ക്രമങ്ങളും ഘനരൂപങ്ങളും

## say
en: Shapes can make a pattern. A pattern repeats in the same order, again and again.
ml: രൂപങ്ങൾ കൊണ്ട് ഒരു ക്രമം ഉണ്ടാക്കാം. ഒരേ രീതിയിൽ വീണ്ടും വീണ്ടും ആവർത്തിക്കുന്നതാണ് ക്രമം.
visual: pattern 🔺 ⚪ 🔺 ⚪ 🔺 ?

## say
en: To find what comes next, find the part that repeats. Say it aloud: triangle, circle. Triangle, circle.
ml: അടുത്തത് കണ്ടെത്താൻ ആവർത്തിക്കുന്ന ഭാഗം കണ്ടുപിടിക്കൂ. ഉറക്കെ പറയൂ: ത്രികോണം, വൃത്തം. ത്രികോണം, വൃത്തം.
visual: pattern 🔺 ⚪ | 🔺 ⚪ | 🔺 ?

## say
label: example
en: The repeating part can be longer too. In square, square, triangle, the part that repeats has three shapes.
ml: ആവർത്തിക്കുന്ന ഭാഗം നീളമുള്ളതുമാകാം. ചതുരം, ചതുരം, ത്രികോണം എന്നതിൽ മൂന്ന് രൂപങ്ങളാണ് ആവർത്തിക്കുന്നത്.
visual: pattern 🟦 🟦 🔺 🟦 🟦 🔺

## ask
form: choice
en: What comes next in this pattern?
ml: ഈ ക്രമത്തിൽ അടുത്തത് ഏത്?
visual: pattern 🔺 ⚪ 🔺 ⚪ 🔺 ?
options: ⚪ | 🔺 | 🟦
answer: ⚪
hint.en: Say it aloud: triangle, circle, triangle, circle...
hint.ml: ഉറക്കെ പറഞ്ഞു നോക്കൂ: ത്രികോണം, വൃത്തം, ത്രികോണം, വൃത്തം...
explain.en: Triangle and circle take turns. After a triangle comes a circle.
explain.ml: ത്രികോണവും വൃത്തവും മാറിമാറി വരുന്നു. ത്രികോണത്തിന് ശേഷം വൃത്തം.
mistake 🔺: repeated the last shape instead of following the pattern

## ask
form: choice
level: 2
en: Now a harder one. What comes next?
ml: ഇനി അല്പം കൂടി പ്രയാസമുള്ളത്. അടുത്തത് ഏത്?
visual: pattern 🟦 🟦 🔺 🟦 🟦 🔺 🟦 ?
options: 🟦 | 🔺
answer: 🟦
hint.en: Find the part that repeats: square, square, triangle.
hint.ml: ആവർത്തിക്കുന്ന ഭാഗം കണ്ടെത്തൂ: ചതുരം, ചതുരം, ത്രികോണം.
explain.en: The repeating part is square, square, triangle. After one square comes another square.
explain.ml: ചതുരം, ചതുരം, ത്രികോണം എന്നതാണ് ആവർത്തിക്കുന്നത്. ഒരു ചതുരത്തിന് ശേഷം ഒരു ചതുരം കൂടി.
mistake 🔺: did not find the repeating part of three

## say
en: Some things are flat, like paper. Some are solid. A brick is a rectangular block. A ball is a sphere.
ml: ചിലത് കടലാസ് പോലെ പരന്നതാണ്. ചിലത് ഘനമുള്ളതാണ്. ഇഷ്ടിക ഒരു ചതുരക്കട്ടയാണ്. പന്ത് ഒരു ഗോളമാണ്.
visual: emoji 🧱 ⚽

## ask
form: choice
en: Which one is shaped like a sphere?
ml: ഗോളത്തിന്റെ രൂപമുള്ളത് ഏത്?
options: an orange | a book | a brick
options.ml: ഓറഞ്ച് | പുസ്തകം | ഇഷ്ടിക
answer: an orange
hint.en: A sphere is round on every side and can roll anywhere.
hint.ml: ഗോളം എല്ലാ വശത്തും ഉരുണ്ടതാണ്, എങ്ങോട്ടും ഉരുളും.
explain.en: An orange is round on every side, like a ball. It is a sphere.
explain.ml: ഓറഞ്ച് പന്ത് പോലെ എല്ലാ വശത്തും ഉരുണ്ടതാണ്. അത് ഗോളമാണ്.

## ask
form: choice
level: 2
en: A matchbox is shaped like which one?
ml: തീപ്പെട്ടിയുടെ രൂപം ഏതുപോലെയാണ്?
options: a rectangular block | a sphere
options.ml: ചതുരക്കട്ട | ഗോളം
answer: a rectangular block
hint.en: Does a matchbox roll like a ball, or does it have flat faces?
hint.ml: തീപ്പെട്ടി പന്ത് പോലെ ഉരുളുമോ, അതോ പരന്ന മുഖങ്ങളുണ്ടോ?
explain.en: A matchbox has flat rectangle faces, like a brick. It is a rectangular block.
explain.ml: തീപ്പെട്ടിക്ക് ഇഷ്ടിക പോലെ പരന്ന ചതുരമുഖങ്ങളുണ്ട്. അത് ചതുരക്കട്ടയാണ്.

## ask
form: number
en: Look at this pattern. How many triangles are in it?
ml: ഈ ക്രമം നോക്കൂ. ഇതിൽ എത്ര ത്രികോണങ്ങളുണ്ട്?
visual: pattern 🔺 ⚪ 🔺 ⚪ 🔺 ⚪
answer: 3
hint.en: Point to each triangle and count. Skip the circles.
hint.ml: ഓരോ ത്രികോണവും ചൂണ്ടി എണ്ണൂ. വൃത്തങ്ങൾ വിട്ടേക്കൂ.
explain.en: There are 3 triangles and 3 circles, taking turns.
explain.ml: 3 ത്രികോണങ്ങളും 3 വൃത്തങ്ങളും മാറിമാറി വരുന്നു.
mistake 6: counted every shape, not only the triangles

## story
en: A drummer plays dum, tak, dum, tak. If you know the beat, you know what comes next. Shapes can follow a beat too.
ml: ഒരു ചെണ്ടക്കാരൻ ഡും, തക്, ഡും, തക് എന്ന് കൊട്ടുന്നു. താളം അറിഞ്ഞാൽ അടുത്തത് എന്തെന്ന് അറിയാം. രൂപങ്ങൾക്കും ഒരു താളമുണ്ടാകാം.

## picture
visual: pattern 🔺 ⚪ 🔺 ⚪ 🔺 ⚪
en: Clap for a triangle, tap for a circle. Clap, tap, clap, tap. The pattern tells you what comes next.
ml: ത്രികോണത്തിന് കൈയടി, വൃത്തത്തിന് തട്ട്. കൈയടി, തട്ട്, കൈയടി, തട്ട്. അടുത്തത് എന്തെന്ന് ക്രമം പറഞ്ഞുതരും.
