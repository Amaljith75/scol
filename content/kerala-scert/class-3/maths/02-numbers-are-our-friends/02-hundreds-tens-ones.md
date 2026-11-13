# Hundreds, tens and ones
title.ml: നൂറുകൾ, പത്തുകൾ, ഒന്നുകൾ
objective: Build and read three-digit numbers using place value.
concept: place-value
concept.name: Place value
concept.name.ml: സ്ഥാനവില

## say
en: Every three-digit number has three places: hundreds, tens and ones. Each bead on this abacus stands for one of them.
ml: മൂന്നക്ക സംഖ്യയ്ക്ക് മൂന്ന് സ്ഥാനങ്ങളുണ്ട്: നൂറുകൾ, പത്തുകൾ, ഒന്നുകൾ. ഈ മണിച്ചട്ടത്തിലെ ഓരോ മണിയും അവയിലൊന്നിനെ കാണിക്കുന്നു.
visual: place 3 4 2

## say
en: 3 beads in hundreds, 4 in tens, 2 in ones. That is 300 and 40 and 2. The number is 342.
ml: നൂറിൽ 3 മണി, പത്തിൽ 4, ഒന്നിൽ 2. അതായത് 300-ഉം 40-ഉം 2-ഉം. സംഖ്യ 342.
visual: text 342 = 300 + 40 + 2

## say
en: The same digit is worth different amounts in different places. In 222, the first 2 is 200, the next is 20, and the last is just 2.
ml: ഒരേ അക്കത്തിന് സ്ഥാനമനുസരിച്ച് വില മാറും. 222-ൽ ആദ്യത്തെ 2 എന്നാൽ 200, അടുത്തത് 20, അവസാനത്തേത് 2 മാത്രം.
visual: steps 222 = 200 + 20 + 2

## say
label: example
en: If a place is empty, we write 0 to keep its spot. 5 hundreds and 7 ones, with no tens, is 507.
ml: ഒരു സ്ഥാനം ഒഴിഞ്ഞാൽ അതിന്റെ ഇടം കാക്കാൻ 0 എഴുതും. 5 നൂറുകളും 7 ഒന്നുകളും, പത്തുകളില്ല: 507.
visual: place 5 0 7

## ask
form: number
en: What number does this abacus show?
ml: ഈ മണിച്ചട്ടം കാണിക്കുന്ന സംഖ്യ ഏത്?
visual: place 2 5 6
answer: 256
hint.en: Count the beads on each rod, starting from hundreds.
hint.ml: നൂറിൽ നിന്ന് തുടങ്ങി ഓരോ കമ്പിയിലെയും മണികൾ എണ്ണൂ.
explain.en: 2 hundreds, 5 tens and 6 ones make 256.
explain.ml: 2 നൂറുകളും 5 പത്തുകളും 6 ഒന്നുകളും ചേർന്നാൽ 256.
mistake 652: read the rods from ones to hundreds
mistake 13: added all the beads together

## ask
form: choice
en: In the number 764, what is the 6 worth?
ml: 764 എന്ന സംഖ്യയിൽ 6-ന്റെ വില എത്ര?
visual: place 7 6 4
options: 60 | 6 | 600
answer: 60
hint.en: Which place is the 6 standing in?
hint.ml: 6 ഏത് സ്ഥാനത്താണ് നിൽക്കുന്നത്?
explain.en: The 6 is in the tens place. 6 tens are 60.
explain.ml: 6 പത്തിന്റെ സ്ഥാനത്താണ്. 6 പത്തുകൾ 60.
mistake 6: read the digit without its place value
mistake 600: confused the tens place with the hundreds place

## ask
form: number
level: 2
en: 4 hundreds, no tens, and 9 ones. Which number is it?
ml: 4 നൂറുകൾ, പത്തുകളില്ല, 9 ഒന്നുകൾ. ഏത് സംഖ്യ?
visual: place 4 0 9
answer: 409
hint.en: No tens means a 0 sits in the tens place.
hint.ml: പത്തുകളില്ല എന്നാൽ പത്തിന്റെ സ്ഥാനത്ത് 0.
explain.en: 400 and 9 make 409. The 0 keeps the tens place.
explain.ml: 400-ഉം 9-ഉം ചേർന്നാൽ 409. പത്തിന്റെ സ്ഥാനത്ത് 0 നിൽക്കുന്നു.
mistake 49: left out the zero for the empty tens place
mistake 490: put the ones in the tens place

## ask
form: choice
level: 2
en: 6 hundred-rupee notes, 8 ten-rupee notes and 5 one-rupee coins. How many rupees?
ml: 6 നൂറു രൂപ നോട്ടുകൾ, 8 പത്തു രൂപ നോട്ടുകൾ, 5 ഒരു രൂപ നാണയങ്ങൾ. ആകെ എത്ര രൂപ?
visual: notes 100 10 1
options: 685 | 658 | 865
answer: 685
hint.en: Hundreds first, then tens, then ones.
hint.ml: ആദ്യം നൂറുകൾ, പിന്നെ പത്തുകൾ, പിന്നെ ഒന്നുകൾ.
explain.en: 600 and 80 and 5 make 685.
explain.ml: 600-ഉം 80-ഉം 5-ഉം ചേർന്നാൽ 685.
mistake 658: swapped the tens and the ones
mistake 865: swapped the hundreds and the tens

## ask
form: abacus
en: Move the beads to show the number 235.
ml: മണികൾ നീക്കി 235 എന്ന സംഖ്യ കാണിക്കൂ.
answer: 235
hint.en: 2 beads on hundreds, 3 on tens, 5 on ones.
hint.ml: നൂറിൽ 2 മണി, പത്തിൽ 3, ഒന്നിൽ 5.
explain.en: 235 is 2 hundreds, 3 tens and 5 ones.
explain.ml: 235 എന്നാൽ 2 നൂറുകൾ, 3 പത്തുകൾ, 5 ഒന്നുകൾ.
mistake 532: put the digits on the rods in the opposite order

## ask
form: abacus
level: 2
en: Show the number four hundred six on the abacus.
ml: നാനൂറ്റി ആറ് എന്ന സംഖ്യ മണിച്ചട്ടത്തിൽ കാണിക്കൂ.
answer: 406
hint.en: There are no tens, so leave the tens rod empty.
hint.ml: പത്തുകളില്ല, അതുകൊണ്ട് പത്തിന്റെ കമ്പി ഒഴിച്ചിടൂ.
explain.en: 406 is 4 hundreds, no tens and 6 ones.
explain.ml: 406 എന്നാൽ 4 നൂറുകൾ, പത്തുകളില്ല, 6 ഒന്നുകൾ.
mistake 460: put the ones on the tens rod
mistake 46: left the hundreds rod empty

## story
en: Three friends share a house. Hundreds lives in the first room, Tens in the middle room, Ones in the last room. In 342, Hundreds has 3, Tens has 4 and Ones has 2. If a room is empty, a 0 hangs on its door.
ml: മൂന്ന് കൂട്ടുകാർ ഒരു വീട്ടിൽ താമസിക്കുന്നു. ആദ്യത്തെ മുറിയിൽ നൂറുകൾ, നടുവിലെ മുറിയിൽ പത്തുകൾ, അവസാന മുറിയിൽ ഒന്നുകൾ. 342-ൽ നൂറിന് 3, പത്തിന് 4, ഒന്നിന് 2. ഒരു മുറി ഒഴിഞ്ഞാൽ അതിന്റെ വാതിലിൽ 0 തൂക്കും.

## picture
visual: place 3 4 2
en: Each rod has its own job. The first counts hundreds, the middle counts tens, the last counts ones. Read them from left to right.
ml: ഓരോ കമ്പിക്കും ഓരോ ജോലി. ആദ്യത്തേത് നൂറുകൾ, നടുവിലേത് പത്തുകൾ, അവസാനത്തേത് ഒന്നുകൾ. ഇടത്തു നിന്ന് വലത്തോട്ട് വായിക്കൂ.
