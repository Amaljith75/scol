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
