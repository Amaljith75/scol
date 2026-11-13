# The life of a butterfly
title.ml: ഒരു ചിത്രശലഭത്തിന്റെ ജീവിതം
objective: Describe the life of a butterfly.
concept: butterfly
concept.name: The life of a butterfly
concept.name.ml: ഒരു ചിത്രശലഭത്തിന്റെ ജീവിതം
minutes: 6

## say
en: Mithra found tiny pearly eggs under a leaf. Her mother said they were butterfly eggs.
ml: മിത്ര ഒരു ഇലയുടെ അടിയിൽ ചെറിയ മുത്തുപോലെയുള്ള മുട്ടകൾ കണ്ടു. അവ ചിത്രശലഭത്തിന്റെ മുട്ടകളാണെന്ന് അമ്മ പറഞ്ഞു.
visual: picture 🍃 ⚪

## say
en: A worm-like larva, called a caterpillar, comes out of each egg. It eats and eats the leaves and grows bigger.
ml: ഓരോ മുട്ടയിൽ നിന്നും പുഴു പോലെയുള്ള ലാർവ (ശലഭപ്പുഴു) പുറത്തുവരുന്നു. അത് ഇലകൾ തിന്ന് തിന്ന് വലുതാകുന്നു.
visual: picture 🐛 🍃

## say
en: Then the larva makes a hard case around itself. This stage is the pupa. Inside, a big change is happening.
ml: തുടർന്ന് ലാർവ തിന് ചുറ്റും ഒരു ഉറപ്പുളള കൂട് ഉണ്ടാക്കുന്നു. ഈ ഘട്ടമാണ് പ്യൂപ്പ. ഇതിനുള്ളിൽ വലിയ മാറ്റങ്ങൾ നടക്കുന്നു.
visual: picture 🫘

## say
en: At last, a butterfly comes out of the pupa! So a butterfly's life goes: egg, larva, pupa, butterfly.
ml: ഒടുവിൽ, പ്യൂപ്പയിൽ നിന്ന് ഒരു ചിത്രശലഭം പുറത്തുവരുന്നു! അതിനാൽ ഒരു ചിത്രശലഭത്തിന്റെ ജീവിതഘട്ടങ്ങൾ: മുട്ട, ലാർവ, പ്യൂപ്പ, ചിത്രശലഭം.
visual: pattern ⚪ 🐛 🫘 🦋

## say
en: Butterflies need plants in two ways: to lay their eggs on, and for food. Caterpillars eat leaves, and butterflies drink nectar from flowers.
ml: ചിത്രശലഭങ്ങൾക്ക് രണ്ട് കാര്യങ്ങൾക്ക് സസ്യങ്ങൾ ആവശ്യമാണ്: മുട്ടയിടാനും ഭക്ഷണത്തിനും. ശലഭപ്പുഴുക്കൾ ഇലകൾ തിന്നുന്നു, ചിത്രശലഭങ്ങൾ പൂക്കളിൽ നിന്ന് തേൻ കുടിക്കുന്നു.
visual: picture 🌿 🌺 🦋

## say
label: example
en: In Kerala, the largest butterfly is the Southern birdwing, the smallest is the Grass jewel, and our state butterfly is the Malabar banded peacock, Buddha mayoori.
ml: കേരളത്തിലെ ഏറ്റവും വലിയ ചിത്രശലഭം ഗരുഡശലഭവും (Southern birdwing), ഏറ്റവും ചെറുത് രത്നശലഭവും (Grass jewel) ആണ്. നമ്മുടെ സംസ്ഥാന ചിത്രശലഭം ബുദ്ധമയൂരി (Malabar banded peacock) ആണ്.
visual: steps largest: Southern birdwing / smallest: Grass jewel / state butterfly: Buddha mayoori

## ask
form: choice
en: What comes out of a butterfly's egg?
ml: ചിത്രശലഭത്തിന്റെ മുട്ടയിൽ നിന്ന് പുറത്തുവരുന്നത് എന്താണ്?
options: a larva | a butterfly | a pupa
options.ml: ഒരു ലാർവ | ഒരു ചിത്രശലഭം | ഒരു പ്യൂപ്പ
answer: a larva
hint.en: It looks like a little worm.
hint.ml: ഇത് ഒരു ചെറിയ പുഴുവിനെപ്പോലെ ഇരിക്കും.
explain.en: A larva, or caterpillar, comes out of the egg.
explain.ml: മുട്ടയിൽ നിന്ന് ഒരു ലാർവ (ശലഭപ്പുഴു) ആണ് പുറത്തുവരുന്നത്.
mistake a butterfly: thinks a butterfly hatches straight from the egg

## ask
form: choice
en: Which order is right?
ml: ഏത് ക്രമമാണ് ശരി?
visual: pattern ⚪ ? ? 🦋
options: egg, larva, pupa, butterfly | egg, pupa, larva, butterfly | larva, egg, butterfly, pupa
options.ml: മുട്ട, ലാർവ, പ്യൂപ്പ, ചിത്രശലഭം | മുട്ട, പ്യൂപ്പ, ലാർവ, ചിത്രശലഭം | ലാർവ, മുട്ട, ചിത്രശലഭം, പ്യൂപ്പ
answer: egg, larva, pupa, butterfly
hint.en: It starts with the egg and ends with the butterfly.
hint.ml: ഇത് മുട്ടയിൽ തുടങ്ങി ചിത്രശലഭത്തിൽ അവസാനിക്കുന്നു.
explain.en: Egg, larva, pupa, then butterfly.
explain.ml: മുട്ട, ലാർവ, പ്യൂപ്പ, പിന്നെ ചിത്രശലഭം.
mistake egg, pupa, larva, butterfly: swapped the larva and pupa stages

## ask
form: number
en: How many stages are there in a butterfly's life? Count egg, larva, pupa and butterfly.
ml: ഒരു ചിത്രശലഭത്തിന്റെ ജീവിതത്തിൽ എത്ര ഘട്ടങ്ങളുണ്ട്? മുട്ട, ലാർവ, പ്യൂപ്പ, ചിത്രശലഭം എന്നിവ എണ്ണുക.
answer: 4
hint.en: Count all four names.
hint.ml: നാല് പേരുകളും എണ്ണുക.
explain.en: There are 4 stages.
explain.ml: 4 ഘട്ടങ്ങളുണ്ട്.
mistake 3: missed one of the stages

## ask
form: choice
en: What is Kerala's state butterfly?
ml: കേരളത്തിന്റെ സംസ്ഥാന ചിത്രശലഭം ഏതാണ്?
options: Malabar banded peacock | Grass jewel | Southern birdwing
options.ml: ബുദ്ധമയൂരി | രത്നശലഭം | ഗരുഡശലഭം
answer: Malabar banded peacock
hint.en: Its Malayalam name is Buddha mayoori.
hint.ml: ഇതിന്റെ മലയാളം പേര് ബുദ്ധമയൂരി എന്നാണ്.
explain.en: The Malabar banded peacock, Buddha mayoori, is Kerala's state butterfly.
explain.ml: ബുദ്ധമയൂരി (Malabar banded peacock) ആണ് കേരളത്തിന്റെ സംസ്ഥാന ചിത്രശലഭം.

## ask
form: choice
en: Why do butterflies need plants?
ml: ചിത്രശലഭങ്ങൾക്ക് സസ്യങ്ങൾ ആവശ്യമുള്ളത് എന്തുകൊണ്ട്?
options: to lay eggs and for food | to sleep inside the roots | they don't need plants
options.ml: മുട്ടയിടാനും ഭക്ഷണത്തിനും | വേരുകൾക്കുള്ളിൽ ഉറങ്ങാൻ | അവയ്ക്ക് സസ്യങ്ങൾ ആവശ്യമില്ല
answer: to lay eggs and for food
hint.en: Think of where the eggs were, and what butterflies drink.
hint.ml: മുട്ടകൾ എവിടെയായിരുന്നുവെന്നും ചിത്രശലഭങ്ങൾ എന്താണ് കുടിക്കുന്നതെന്നും ഓർക്കുക.
explain.en: Butterflies lay eggs on plants and get food from them.
explain.ml: ചിത്രശലഭങ്ങൾ ചെടികളിൽ മുട്ടയിടുകയും അവയിൽ നിന്ന് ഭക്ഷണം നേടുകയും ചെയ്യുന്നു.

## story
en: A tiny egg sat under a curry leaf. Out wriggled Kutti the caterpillar, munching leaves all day. One day Kutti curled up inside a pupa and went quiet. A few days later, out flew a beautiful butterfly!
ml: ഒരു കറിവേപ്പിലയുടെ അടിയിൽ ഒരു ചെറിയ മുട്ടയുണ്ടായിരുന്നു. അതിൽ നിന്ന് കുട്ടി എന്ന ശലഭപ്പുഴു പുറത്തുവന്ന് ദിവസം മുഴുവൻ ഇലകൾ കടിച്ച് തിന്നു. ഒരു ദിവസം കുട്ടി ഒരു പ്യൂപ്പയ്ക്കുള്ളിൽ ചുരുണ്ടുകൂടി മിണ്ടാതിരുന്നു. കുറച്ചു ദിവസങ്ങൾക്ക് ശേഷം, മനോഹരമായ ഒരു ചിത്രശലഭം പറന്നുയർന്നു!

## picture
visual: pattern ⚪ 🐛 🫘 🦋
en: Four stages, one life.
ml: നാല് ഘട്ടങ്ങൾ, ഒരു ജീവിതം.
