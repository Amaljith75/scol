# Making numbers from digits
title.ml: അക്കങ്ങൾ കൊണ്ട് സംഖ്യകൾ
objective: Make the largest and the smallest number from given digits.
concept: digits-make-numbers
concept.name: Building numbers from digits
concept.name.ml: അക്കങ്ങളിൽ നിന്ന് സംഖ്യകൾ ഉണ്ടാക്കൽ

## say
en: Here are three cards: 2, 5 and 7. Use each card once. To make the largest number, put the biggest digit in the hundreds place.
ml: ഇതാ മൂന്ന് കാർഡുകൾ: 2, 5, 7. ഓരോന്നും ഒരു തവണ ഉപയോഗിക്കാം. ഏറ്റവും വലിയ സംഖ്യ ഉണ്ടാക്കാൻ ഏറ്റവും വലിയ അക്കം നൂറിന്റെ സ്ഥാനത്ത് വെക്കൂ.
visual: text 7 5 2

## say
en: For the smallest number, do the opposite. Put the smallest digit first: 257.
ml: ഏറ്റവും ചെറിയ സംഖ്യയ്ക്ക് നേരെ തിരിച്ച് ചെയ്യൂ. ഏറ്റവും ചെറിയ അക്കം ആദ്യം: 257.
visual: text 2 5 7

## ask
form: number
en: Use the digits 3, 8 and 1 once each. What is the largest number you can make?
ml: 3, 8, 1 എന്നീ അക്കങ്ങൾ ഓരോ തവണ ഉപയോഗിച്ച് ഉണ്ടാക്കാവുന്ന ഏറ്റവും വലിയ സംഖ്യ ഏത്?
visual: text 3 8 1
answer: 831
hint.en: Biggest digit in the hundreds place, then the next biggest.
hint.ml: ഏറ്റവും വലിയ അക്കം നൂറിന്റെ സ്ഥാനത്ത്, പിന്നെ അടുത്ത വലുത്.
explain.en: 8 hundreds, 3 tens, 1 one: 831.
explain.ml: 8 നൂറുകൾ, 3 പത്തുകൾ, 1 ഒന്ന്: 831.
mistake 813: put the smallest digit in the tens place
mistake 381: kept the digits in the given order

## ask
form: number
en: With the same digits 3, 8 and 1, what is the smallest number?
ml: അതേ അക്കങ്ങൾ 3, 8, 1 കൊണ്ട് ഉണ്ടാക്കാവുന്ന ഏറ്റവും ചെറിയ സംഖ്യ ഏത്?
visual: text 3 8 1
answer: 138
hint.en: Smallest digit in the hundreds place, then the next smallest.
hint.ml: ഏറ്റവും ചെറിയ അക്കം നൂറിന്റെ സ്ഥാനത്ത്, പിന്നെ അടുത്ത ചെറുത്.
explain.en: 1 hundred, 3 tens, 8 ones: 138.
explain.ml: 1 നൂറ്, 3 പത്തുകൾ, 8 ഒന്നുകൾ: 138.
mistake 183: put the largest digit in the tens place
mistake 831: gave the largest number instead

## ask
form: choice
level: 2
en: Use 4, 0 and 6 once each. What is the smallest three-digit number?
ml: 4, 0, 6 ഓരോ തവണ ഉപയോഗിച്ച് ഉണ്ടാക്കാവുന്ന ഏറ്റവും ചെറിയ മൂന്നക്ക സംഖ്യ ഏത്?
visual: text 4 0 6
options: 406 | 046 | 460
answer: 406
hint.en: A three-digit number cannot begin with 0.
hint.ml: മൂന്നക്ക സംഖ്യ 0-ൽ തുടങ്ങാൻ പറ്റില്ല.
explain.en: 0 cannot go first, so 4 goes first, then 0, then 6: 406.
explain.ml: 0 ആദ്യം വെക്കാൻ പറ്റില്ല. അതുകൊണ്ട് ആദ്യം 4, പിന്നെ 0, പിന്നെ 6: 406.
mistake 046: put zero in the hundreds place
mistake 460: did not put the zero in the tens place

## ask
form: number
level: 2
en: 7 hundreds, 6 tens and 5 ones. Which number is it?
ml: 7 നൂറുകൾ, 6 പത്തുകൾ, 5 ഒന്നുകൾ. ഏത് സംഖ്യ?
visual: place 7 6 5
answer: 765
hint.en: Write the hundreds first, then the tens, then the ones.
hint.ml: ആദ്യം നൂറുകൾ, പിന്നെ പത്തുകൾ, പിന്നെ ഒന്നുകൾ എഴുതൂ.
explain.en: 700 and 60 and 5 make 765.
explain.ml: 700-ഉം 60-ഉം 5-ഉം ചേർന്നാൽ 765.
mistake 675: swapped the hundreds and the tens
mistake 567: wrote the places in the opposite order

## ask
form: abacus
level: 2
en: Use the digits 1, 4 and 2 once each. Show the largest number on the abacus.
ml: 1, 4, 2 എന്നീ അക്കങ്ങൾ ഓരോ തവണ ഉപയോഗിച്ച് ഉണ്ടാക്കാവുന്ന ഏറ്റവും വലിയ സംഖ്യ മണിച്ചട്ടത്തിൽ കാണിക്കൂ.
answer: 421
hint.en: The biggest digit goes on the hundreds rod.
hint.ml: ഏറ്റവും വലിയ അക്കം നൂറിന്റെ കമ്പിയിൽ.
explain.en: 4 hundreds, 2 tens, 1 one: 421.
explain.ml: 4 നൂറുകൾ, 2 പത്തുകൾ, 1 ഒന്ന്: 421.
mistake 142: kept the digits in the given order
mistake 124: made the smallest number instead

## story
en: Three children want to sit in a row of three chairs. The first chair is worth hundreds, so for the largest number the biggest digit sits there. For the smallest number the smallest digit sits first. But zero is too shy to sit in the first chair.
ml: മൂന്ന് കുട്ടികൾക്ക് മൂന്ന് കസേരകളിൽ ഇരിക്കണം. ആദ്യത്തെ കസേര നൂറിന്റേതാണ്, അതുകൊണ്ട് ഏറ്റവും വലിയ സംഖ്യയ്ക്ക് ഏറ്റവും വലിയ അക്കം അവിടെ ഇരിക്കും. ഏറ്റവും ചെറിയ സംഖ്യയ്ക്ക് ഏറ്റവും ചെറിയ അക്കം ആദ്യം. പക്ഷേ പൂജ്യത്തിന് ആദ്യത്തെ കസേരയിൽ ഇരിക്കാൻ നാണമാണ്.

## picture
visual: steps Largest: 7 5 2 / Smallest: 2 5 7
en: The hundreds place matters most. Put your biggest digit there for the largest number.
ml: നൂറിന്റെ സ്ഥാനമാണ് ഏറ്റവും പ്രധാനം. ഏറ്റവും വലിയ സംഖ്യയ്ക്ക് ഏറ്റവും വലിയ അക്കം അവിടെ വെക്കൂ.
