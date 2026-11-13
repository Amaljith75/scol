# Sorting waste
title.ml: മാലിന്യങ്ങൾ തരംതിരിക്കൽ
objective: Sort waste into organic, inorganic and hazardous.
concept: waste
concept.name: Sorting waste
concept.name.ml: മാലിന്യങ്ങൾ തരംതിരിക്കൽ
minutes: 6

## say
en: Why do schools have separate bins for waste? Because different waste must be handled in different ways.
ml: വിദ്യാലയങ്ങളിൽ എന്തിനാണ് വെവ്വേറെ മാലിന്യപ്പട്ടികൾ വെച്ചിരിക്കുന്നത്? കാരണം ഓരോ തരം മാലിന്യവും വ്യത്യസ്ത രീതിയിലാണ് സംസ്കരിക്കേണ്ടത്.
visual: picture 🗑️ 🗑️ 🗑️

## say
en: Organic waste rots in the soil. Food scraps, vegetable peels, banana skins and fish waste are organic.
ml: ജൈവമാലിന്യങ്ങൾ മണ്ണിൽ അളിഞ്ഞുചേരും. ഭക്ഷണ അവശിഷ്ടങ്ങൾ, പച്ചക്കറിത്തോലുകൾ, പഴത്തോലുകൾ, മീൻ അവശിഷ്ടങ്ങൾ എന്നിവ ജൈവമാലിന്യങ്ങളാണ്.
visual: picture 🍌 🥕 🐟

## say
en: Inorganic waste does not rot. Plastic bottles, plastic covers and PVC pipes are inorganic.
ml: അജൈവമാലിന്യങ്ങൾ മണ്ണിൽ അഴുകിപ്പോകില്ല. പ്ലാസ്റ്റിക് കുപ്പികൾ, പ്ലാസ്റ്റിക് കവറുകൾ, പി.വി.സി പൈപ്പുകൾ എന്നിവ അജൈവമാലിന്യങ്ങളാണ്.
visual: picture 🧴 🛍️

## say
en: Hazardous waste can harm us. Electronic waste, bulbs, expired medicines and pesticide bottles are hazardous.
ml: അപകടകരമായ മാലിന്യങ്ങൾ നമുക്ക് ഹാനികരമാണ്. ഇലക്ട്രോണിക് അവശിഷ്ടങ്ങൾ, ബൾബുകൾ, കാലാവധി കഴിഞ്ഞ മരുന്നുകൾ, കീടനാശിനി കുപ്പികൾ എന്നിവ അപകടകരമായ മാലിന്യങ്ങളാണ്.
visual: picture 💡 💊 🔋

## say
label: example
en: Organic waste can become manure. Put it in a compost pit and cover it with soil. In three to four months it turns into manure.
ml: ജൈവമാലിന്യങ്ങൾ വളമാക്കി മാറ്റാം. ഒരു കമ്പോസ്റ്റ് കുഴിയിലിട്ട് മണ്ണുകൊണ്ട് മൂടുക. മൂന്ന് മുതൽ നാല് മാസത്തിനുള്ളിൽ ഇത് വളമായി മാറും.
visual: steps food waste → compost pit → 3 to 4 months → manure

## say
en: Never throw plastic around and never burn it. Burning plastic harms our health. Sort it and give it to the waste collectors for recycling.
ml: പ്ലാസ്റ്റിക് വലിച്ചെറിയാനോ കത്തിക്കാനോ പാടില്ല. പ്ലാസ്റ്റിക് കത്തിക്കുന്നത് നമ്മുടെ ആരോഗ്യത്തിന് ഹാനികരമാണ്. ഇവ തരംതിരിച്ച് പുനരുപയോഗത്തിനായി മാലിന്യ ശേഖർത്താക്കൾക്ക് നൽകുക.
visual: picture 🚫🔥 ♻️

## ask
form: choice
en: A banana peel is which kind of waste?
ml: നേന്ത്രപ്പഴത്തിന്റെ തൊലി ഏത് തരം മാലിന്യമാണ്?
options: organic | inorganic | hazardous
options.ml: ജൈവമാലിന്യം | അജൈവമാലിന്യം | അപകടകരമായ മാലിന്യം
answer: organic
hint.en: Does it rot in the soil?
hint.ml: ഇത് മണ്ണിൽ അഴുകിപ്പോകുമോ?
explain.en: A banana peel rots in soil, so it is organic waste.
explain.ml: പഴത്തോൽ മണ്ണിൽ അഴുകിപ്പോകും, അതിനാൽ ഇത് ജൈവമാലിന്യമാണ്.
mistake inorganic: mixed up organic and inorganic

## ask
form: choice
en: A plastic bottle is which kind of waste?
ml: പ്ലാസ്റ്റിക് കുപ്പി ഏത് തരം മാലിന്യമാണ്?
options: inorganic | organic | hazardous
options.ml: അജൈവമാലിന്യം | ജൈവമാലിന്യം | അപകടകരമായ മാലിന്യം
answer: inorganic
hint.en: Plastic does not rot.
hint.ml: പ്ലാസ്റ്റിക് അഴുകിപ്പോകില്ല.
explain.en: Plastic does not rot, so it is inorganic waste.
explain.ml: പ്ലാസ്റ്റിക് അഴുകിപ്പോകില്ല, അതിനാൽ ഇത് അജൈവമാലിന്യമാണ്.
mistake organic: thinks plastic rots in soil

## ask
form: choice
en: An old bulb is which kind of waste?
ml: പഴയ ബൾബ് ഏത് തരം മാലിന്യമാണ്?
options: hazardous | organic | inorganic
options.ml: അപകടകരമായ മാലിന്യം | ജൈവമാലിന്യം | അജൈവമാലിന്യം
answer: hazardous
hint.en: It can hurt us if it breaks.
hint.ml: ഇത് പൊട്ടിയാൽ നമുക്ക് പരിക്കേൽക്കാം.
explain.en: Bulbs are hazardous waste.
explain.ml: ബൾബുകൾ അപകടകരമായ മാലിന്യങ്ങളാണ്.
mistake inorganic: did not know bulbs are hazardous

## ask
form: choice
en: What should we do with plastic waste?
ml: പ്ലാസ്റ്റിക് മാലിന്യങ്ങൾ നമ്മൾ എന്ത് ചെയ്യണം?
options: sort it and give it for recycling | burn it | throw it in the river
options.ml: തരംതിരിച്ച് പുനരുപയോഗത്തിനായി നൽകുക | കത്തിക്കുക | പുഴയിൽ എറിയുക
answer: sort it and give it for recycling
hint.en: Not throwing, not burning.
hint.ml: വലിച്ചെറിയുകയോ കത്തിക്കുകയോ ചെയ്യരുത്.
explain.en: Sort plastic and give it to waste collectors for recycling.
explain.ml: പ്ലാസ്റ്റിക് തരംതിരിച്ച് പുനരുപയോഗത്തിനായി നൽകുക.
mistake burn it: thinks burning plastic is safe

## ask
form: choice
en: How long does a compost pit take to turn food waste into manure?
ml: ഭക്ഷണ അവശിഷ്ടങ്ങൾ വളമായി മാറാൻ കമ്പോസ്റ്റ് കുഴിക്ക് എത്ര സമയം വേണം?
options: 3 to 4 months | 1 day | 10 years
options.ml: 3 മുതൽ 4 മാസം വരെ | 1 ദിവസം | 10 വർഷം
answer: 3 to 4 months
hint.en: It is a few months.
hint.ml: ഇത് കുറച്ച് മാസങ്ങളാണ്.
explain.en: About three to four months.
explain.ml: മൂന്ന് മുതൽ നാല് മാസം വരെ.

## ask
form: number
en: Banana peel, vegetable peel and plastic bottle. How many of these are organic waste?
ml: പഴത്തോൽ, പച്ചക്കറിത്തോൽ, പ്ലാസ്റ്റിക് കുപ്പി. ഇവയിൽ എത്രയെണ്ണം ജൈവമാലിന്യങ്ങളാണ്?
answer: 2
hint.en: Which ones rot in the soil?
hint.ml: ഇവയിൽ ഏതെല്ലാമാണ് മണ്ണിൽ അഴുകുന്നത്?
explain.en: 2: the banana peel and the vegetable peel. The plastic bottle is inorganic.
explain.ml: 2: പഴത്തോലും പച്ചക്കറിത്തോലും. പ്ലാസ്റ്റിക് കുപ്പി അജൈവമാലിന്യമാണ്.
mistake 3: thinks plastic is organic

## story
en: Three bins stood in a row at school. Green bin ate banana peels and said, yum, I will become manure! Blue bin collected plastic bottles for recycling. Red bin carefully took the old bulb and the medicine strip. Nothing ended up on the playground.
ml: വിദ്യാലയത്തിൽ മൂന്ന് മാലിന്യപ്പട്ടികൾ വരിവരിയായി ഉണ്ടായിരുന്നു. പച്ചപ്പട്ടി പഴത്തോലുകൾ തിന്ന് സന്തോഷത്തോടെ പറഞ്ഞു, ഞാൻ വളമായി മാറും! നീലപ്പട്ടി പുനരുപയോഗത്തിനായി പ്ലാസ്റ്റിക് കുപ്പികൾ ശേഖരിച്ചു. ചുവപ്പുപ്പട്ടി പഴയ ബൾബും മരുന്നിന്റെ ഉറയും ശ്രദ്ധയോടെ വാങ്ങി. കളിസ്ഥലത്ത് ഒരു മാലിന്യവും വീണുകിടന്നില്ല.

## picture
visual: steps organic 🍌 → compost / inorganic 🧴 → recycle / hazardous 💡 → special care
en: Three bins, three kinds of waste.
ml: മൂന്ന് മാലിന്യപ്പട്ടികൾ, മൂന്ന് തരം മാലിന്യങ്ങൾ.
