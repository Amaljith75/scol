# Odd and even
title.ml: ഒറ്റയും ഇരട്ടയും
objective: Tell odd numbers from even numbers and see what happens when they are added.
concept: odd-even
concept.name: Odd and even numbers
concept.name.ml: ഒറ്റ, ഇരട്ട സംഖ്യകൾ

## say
en: Even numbers can be shared into two equal groups with nothing left over. 2, 4, 6, 8 and 10 are even.
ml: ഇരട്ട സംഖ്യകളെ ബാക്കിയില്ലാതെ രണ്ട് തുല്യ കൂട്ടങ്ങളാക്കാം. 2, 4, 6, 8, 10 ഇരട്ട സംഖ്യകളാണ്.
visual: groups 2 3 🔵

## say
en: Odd numbers always leave one out. 1, 3, 5, 7 and 9 are odd. To check a big number, just look at its last digit.
ml: ഒറ്റ സംഖ്യകളിൽ എപ്പോഴും ഒന്ന് ബാക്കി വരും. 1, 3, 5, 7, 9 ഒറ്റ സംഖ്യകളാണ്. വലിയ സംഖ്യ പരിശോധിക്കാൻ അവസാനത്തെ അക്കം നോക്കിയാൽ മതി.
visual: count 7 🔵

## ask
form: choice
en: Which of these is an even number?
ml: ഇവയിൽ ഇരട്ട സംഖ്യ ഏത്?
options: 14 | 15 | 21
answer: 14
hint.en: Look at the last digit. Is it 0, 2, 4, 6 or 8?
hint.ml: അവസാനത്തെ അക്കം നോക്കൂ. അത് 0, 2, 4, 6, 8 ഇവയിലൊന്നാണോ?
explain.en: 14 ends in 4, so it is even.
explain.ml: 14 അവസാനിക്കുന്നത് 4-ൽ, അതുകൊണ്ട് അത് ഇരട്ട സംഖ്യ.
mistake 15: mixed up odd and even
mistake 21: looked at the first digit instead of the last

## ask
form: choice
en: Which of these is an odd number?
ml: ഇവയിൽ ഒറ്റ സംഖ്യ ഏത്?
options: 47 | 30 | 52
answer: 47
hint.en: Look at the last digit. Is it 1, 3, 5, 7 or 9?
hint.ml: അവസാനത്തെ അക്കം നോക്കൂ. അത് 1, 3, 5, 7, 9 ഇവയിലൊന്നാണോ?
explain.en: 47 ends in 7, so it is odd.
explain.ml: 47 അവസാനിക്കുന്നത് 7-ൽ, അതുകൊണ്ട് അത് ഒറ്റ സംഖ്യ.
mistake 30: looked at the first digit instead of the last
mistake 52: looked at the first digit instead of the last

## ask
form: choice
level: 2
en: Add two odd numbers, like 3 + 5 or 7 + 9. What kind of number is the answer?
ml: 3 + 5, 7 + 9 എന്നിങ്ങനെ രണ്ട് ഒറ്റ സംഖ്യകൾ കൂട്ടിയാൽ കിട്ടുന്ന ഉത്തരം എങ്ങനെയുള്ളതാണ്?
options: always even | always odd
options.ml: എപ്പോഴും ഇരട്ട | എപ്പോഴും ഒറ്റ
answer: always even
hint.en: Work out 3 + 5 and 7 + 9. Look at the answers.
hint.ml: 3 + 5, 7 + 9 ഇവ കണക്കാക്കി ഉത്തരങ്ങൾ നോക്കൂ.
explain.en: 3 + 5 = 8 and 7 + 9 = 16. The two left-over ones join to make a pair, so the sum is even.
explain.ml: 3 + 5 = 8, 7 + 9 = 16. ബാക്കി വന്ന രണ്ട് ഒന്നുകൾ ചേർന്ന് ഒരു ജോഡിയാകും. അതുകൊണ്ട് ഉത്തരം ഇരട്ട സംഖ്യ.
mistake always odd: assumed odd numbers always give odd answers

## ask
form: choice
level: 2
en: Add two numbers that are next to each other, like 5 + 6 or 8 + 9. What kind of number is the answer?
ml: 5 + 6, 8 + 9 എന്നിങ്ങനെ അടുത്തടുത്തുള്ള രണ്ട് സംഖ്യകൾ കൂട്ടിയാൽ കിട്ടുന്ന ഉത്തരം എങ്ങനെയുള്ളതാണ്?
options: always odd | always even
options.ml: എപ്പോഴും ഒറ്റ | എപ്പോഴും ഇരട്ട
answer: always odd
hint.en: Work out 5 + 6 and 8 + 9. Look at the answers.
hint.ml: 5 + 6, 8 + 9 ഇവ കണക്കാക്കി ഉത്തരങ്ങൾ നോക്കൂ.
explain.en: 5 + 6 = 11 and 8 + 9 = 17. One of the two is odd and the other even, so one is always left over.
explain.ml: 5 + 6 = 11, 8 + 9 = 17. ഒന്ന് ഒറ്റയും മറ്റേത് ഇരട്ടയും ആയതുകൊണ്ട് എപ്പോഴും ഒന്ന് ബാക്കി വരും.

## ask
form: number
en: Which even number comes just after 16?
ml: 16-ന് തൊട്ടുശേഷം വരുന്ന ഇരട്ട സംഖ്യ ഏത്?
answer: 18
hint.en: 17 is odd. Go one more step.
hint.ml: 17 ഒറ്റ സംഖ്യയാണ്. ഒരു പടി കൂടി മുന്നോട്ട്.
explain.en: 17 is odd, so the next even number is 18.
explain.ml: 17 ഒറ്റയാണ്. അതുകൊണ്ട് അടുത്ത ഇരട്ട സംഖ്യ 18.
mistake 17: gave the next number without checking it is even

## story
en: Children walk to the assembly in pairs, holding hands. If everyone has a partner, the number is even. If one child is left without a partner, the number is odd.
ml: കുട്ടികൾ കൈ പിടിച്ച് ജോഡികളായി അസംബ്ലിക്ക് പോകുന്നു. എല്ലാവർക്കും കൂട്ടുണ്ടെങ്കിൽ സംഖ്യ ഇരട്ട. ഒരു കുട്ടിക്ക് കൂട്ടില്ലെങ്കിൽ സംഖ്യ ഒറ്റ.

## picture
visual: groups 3 2 🧒
en: Six children make 3 pairs and nobody is left out. Six is even. One more child would have no partner, so seven is odd.
ml: ആറ് കുട്ടികൾ 3 ജോഡിയാകും, ആരും ബാക്കിയില്ല. ആറ് ഇരട്ട. ഒരു കുട്ടി കൂടി വന്നാൽ കൂട്ടില്ല, അതുകൊണ്ട് ഏഴ് ഒറ്റ.
