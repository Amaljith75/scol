# What animals eat
title.ml: മൃഗങ്ങൾ എന്ത് കഴിക്കുന്നു
objective: Group animals by what they eat: herbivores, carnivores and omnivores.
concept: animal-food
concept.name: Herbivores, carnivores and omnivores
concept.name.ml: സസ്യാഹാരികൾ, മാംസാഹാരികൾ, മിശ്രാഹാരികൾ
minutes: 6

## say
en: Different animals eat different food. A butterfly drinks nectar from flowers. A praying mantis eats ants and small insects.
ml: വെവ്വേറെ മൃഗങ്ങൾ വെവ്വേറെ ഭക്ഷണമാണ് കഴിക്കുന്നത്. ചിത്രശലഭം പൂക്കളിൽ നിന്ന് തേൻ കുടിക്കുന്നു. വെട്ടുക്കിളി ഉറുമ്പുകളെയും ചെറിയ പ്രാണികളെയും തിന്നുന്നു.
visual: picture 🦋 🌸 🦗

## say
en: Animals that eat only plant parts are called herbivores. Cows, goats and elephants are herbivores.
ml: സസ്യഭാഗങ്ങൾ മാത്രം തിന്നുന്ന ജീവികളെ സസ്യാഹാരികൾ എന്ന് വിളിക്കുന്നു. പശു, ആട്, ആന എന്നിവ സസ്യാഹാരികളാണ്.
visual: picture 🐄 🐐 🐘 🌿

## say
en: Animals that eat only other animals are called carnivores. Lions, eagles and kingfishers are carnivores.
ml: മറ്റു ജീവികളെ മാത്രം തിന്നുന്ന ജീവികളെ മാംസാഹാരികൾ എന്ന് വിളിക്കുന്നു. സിംഹം, പരുന്ത്, പൊന്മാൻ എന്നിവ മാംസാഹാരികളാണ്.
visual: picture 🦁 🦅 🐟

## say
en: Animals that eat both plants and animals are called omnivores. Crows and hens are omnivores.
ml: സസ്യങ്ങളെയും മറ്റു ജീവികളെയും തിന്നുന്ന ജീവികളെ മിശ്രാഹാരികൾ എന്ന് വിളിക്കുന്നു. കാക്കയും കോഴിയും മിശ്രാഹാരികളാണ്.
visual: picture 🐦‍⬛ 🐔

## say
label: example
en: Bodies match food. Carnivores have sharp nails and pointed teeth to catch and tear their prey. Eagles have strong, sharp beaks and bent claws. Herbivores have teeth for chewing plants.
ml: ജീവികളുടെ ശരീരഘടന അവ കഴിക്കുന്ന ഭക്ഷണത്തിന് അനുയോജ്യമാണ്. മാംസാഹാരികൾക്ക് ഇരയെ പിടിക്കാനും കീറിമുറിക്കാനും മൂർച്ചയുള്ള നഖങ്ങളും കൂർത്ത പല്ലുകളുമുണ്ട്. പരുന്തിന് ശക്തമായ മൂർച്ചയുള്ള ചുണ്ടും വളഞ്ഞ നഖങ്ങളുമുണ്ട്. സസ്യാഹാരികൾക്ക് ചെടികൾ അരച്ചരച്ച് തിന്നാൻ പറ്റിയ പല്ലുകളുണ്ട്.
visual: steps carnivore → sharp teeth, claws / herbivore → chewing teeth

## ask
form: choice
en: A cow eats only grass and leaves. What is it?
ml: പശു പുല്ലും ഇലകളും മാത്രമേ തിന്നുകയുള്ളൂ. അത് ഏത് വിഭാഗത്തിൽപ്പെടുന്നു?
options: herbivore | carnivore | omnivore
options.ml: സസ്യാഹാരി | മാംസാഹാരി | മിശ്രാഹാരി
answer: herbivore
hint.en: Herb means plant.
hint.ml: ചെടികൾ മാത്രം തിന്നുന്ന ജീവി.
explain.en: Animals that eat only plant parts are herbivores.
explain.ml: സസ്യഭാഗങ്ങൾ മാത്രം തിന്നുന്ന ജീവികളാണ് സസ്യാഹാരികൾ.
mistake carnivore: mixed up herbivore and carnivore
mistake omnivore: mixed up herbivore and omnivore

## ask
form: choice
en: A lion eats only meat. What is it?
ml: സിംഹം മാംസം മാത്രമേ തിന്നുകയുള്ളൂ. അത് ഏത് വിഭാഗത്തിൽപ്പെടുന്നു?
options: carnivore | herbivore | omnivore
options.ml: മാംസാഹാരി | സസ്യാഹാരി | മിശ്രാഹാരി
answer: carnivore
hint.en: It hunts other animals.
hint.ml: ഇത് മറ്റു ജീവികളെ വേട്ടയാടുന്നു.
explain.en: Animals that eat only meat are carnivores.
explain.ml: മാംസം മാത്രം തിന്നുന്ന ജീവികളാണ് മാംസാഹാരികൾ.
mistake herbivore: mixed up herbivore and carnivore

## ask
form: choice
en: A crow eats seeds and also small creatures. What is it?
ml: കാക്ക വിത്തുകളും ചെറിയ ജീവികളെയും തിന്നുന്നു. അത് ഏത് വിഭാഗത്തിൽപ്പെടുന്നു?
options: omnivore | herbivore | carnivore
options.ml: മിശ്രാഹാരി | സസ്യാഹാരി | മാംസാഹാരി
answer: omnivore
hint.en: It eats both plants and animals.
hint.ml: ഇത് സസ്യങ്ങളെയും ജീവികളെയും തിന്നുന്നു.
explain.en: Animals that eat both plants and animals are omnivores.
explain.ml: സസ്യങ്ങളെയും ജീവികളെയും തിന്നുന്നവയാണ് മിശ്രാഹാരികൾ.
mistake carnivore: did not notice it also eats plants

## ask
form: choice
en: What helps an eagle catch its prey?
ml: ഇരയെ പിടിക്കാൻ പരുന്തിനെ സഹായിക്കുന്നത് എന്താണ്?
options: sharp bent claws | flat teeth | soft feathers on its feet
options.ml: മൂർച്ചയുള്ള വളഞ്ഞ നഖങ്ങൾ | പരന്ന പല്ലുകൾ | കാലുകളിലെ മൃദുവായ തൂവലുകൾ
answer: sharp bent claws
hint.en: Look at its feet.
hint.ml: അതിന്റെ കാലുകളിലേക്ക് നോക്കൂ.
explain.en: An eagle has strong legs with sharp bent claws, and a sharp beak.
explain.ml: പരുന്തിന് മൂർച്ചയുള്ള വളഞ്ഞ നഖങ്ങളുള്ള ശക്തമായ കാലുകളും മൂർച്ചയുള്ള ചുണ്ടുമുണ്ട്.

## ask
form: number
en: Cow, lion, crow. How many of these eat only plant parts?
ml: പശു, സിംഹം, കാക്ക. ഇവയിൽ എത്രയെണ്ണം സസ്യഭാഗങ്ങൾ മാത്രമേ തിന്നുകയുള്ളൂ?
answer: 1
hint.en: Only the cow eats just plants.
hint.ml: പശു മാത്രമേ സസ്യങ്ങൾ മാത്രം തിന്നുന്നുള്ളൂ.
explain.en: Only 1: the cow. The lion eats meat and the crow eats both.
explain.ml: 1 മാത്രം: പശു. സിംഹം മാംസവും കാക്ക രണ്ടും തിന്നുന്നു.
mistake 2: counted the crow, which eats both

## story
en: Cow, Lion and Crow met for lunch. Cow brought grass. Lion said, no thank you, I eat only meat. Crow said, I will eat a little of everything! Their friend the owl laughed: a herbivore, a carnivore and an omnivore at one table!
ml: പശുവും സിംഹവും കാക്കയും ഉച്ചഭക്ഷണത്തിന് ഒരുമിച്ചുകൂടി. പശു പുല്ല് കൊണ്ടുവന്നു. സിംഹം പറഞ്ഞു, വേണ്ട നന്ദി, ഞാൻ മാംസം മാത്രമേ തിന്നൂ. കാക്ക പറഞ്ഞു, ഞാൻ എല്ലാം കുറച്ചവീതം തിന്നാം! അവരുടെ കൂട്ടുകാരൻ മൂങ്ങ ചിരിച്ചു: ഒരു സസ്യാഹാരിയും മാംസാഹാരിയും മിശ്രാഹാരിയും ഒരു മേശയ്ക്ക് ചുറ്റും!

## picture
visual: steps herbivore 🐄 → 🌿 / carnivore 🦁 → 🍖 / omnivore 🐔 → 🌿 + 🐛
en: Three groups, by what they eat.
ml: കഴിക്കുന്ന ഭക്ഷണത്തിന്റെ അടിസ്ഥാനത്തിൽ മൂന്ന് കൂട്ടങ്ങൾ.
