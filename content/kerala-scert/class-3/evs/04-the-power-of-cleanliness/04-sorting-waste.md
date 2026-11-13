# Sorting waste
objective: Sort waste into organic, inorganic and hazardous.
concept: waste
concept.name: Sorting waste
minutes: 6

## say
en: Why do schools have separate bins for waste? Because different waste must be handled in different ways.
visual: emoji 🗑️ 🗑️ 🗑️

## say
en: Organic waste rots in the soil. Food scraps, vegetable peels, banana skins and fish waste are organic.
visual: emoji 🍌 🥕 🐟

## say
en: Inorganic waste does not rot. Plastic bottles, plastic covers and PVC pipes are inorganic.
visual: emoji 🧴 🛍️

## say
en: Hazardous waste can harm us. Electronic waste, bulbs, expired medicines and pesticide bottles are hazardous.
visual: emoji 💡 💊 🔋

## say
label: example
en: Organic waste can become manure. Put it in a compost pit and cover it with soil. In three to four months it turns into manure.
visual: steps food waste → compost pit → 3 to 4 months → manure

## say
en: Never throw plastic around and never burn it. Burning plastic harms our health. Sort it and give it to the waste collectors for recycling.
visual: emoji 🚫🔥 ♻️

## ask
form: choice
en: A banana peel is which kind of waste?
options: organic | inorganic | hazardous
answer: organic
hint.en: Does it rot in the soil?
explain.en: A banana peel rots in soil, so it is organic waste.
mistake inorganic: mixed up organic and inorganic

## ask
form: choice
en: A plastic bottle is which kind of waste?
options: inorganic | organic | hazardous
answer: inorganic
hint.en: Plastic does not rot.
explain.en: Plastic does not rot, so it is inorganic waste.
mistake organic: thinks plastic rots in soil

## ask
form: choice
en: An old bulb is which kind of waste?
options: hazardous | organic | inorganic
answer: hazardous
hint.en: It can hurt us if it breaks.
explain.en: Bulbs are hazardous waste.
mistake inorganic: did not know bulbs are hazardous

## ask
form: choice
en: What should we do with plastic waste?
options: sort it and give it for recycling | burn it | throw it in the river
answer: sort it and give it for recycling
hint.en: Not throwing, not burning.
explain.en: Sort plastic and give it to waste collectors for recycling.
mistake burn it: thinks burning plastic is safe

## ask
form: choice
en: How long does a compost pit take to turn food waste into manure?
options: 3 to 4 months | 1 day | 10 years
answer: 3 to 4 months
hint.en: It is a few months.
explain.en: About three to four months.

## ask
form: number
en: Banana peel, vegetable peel and plastic bottle. How many of these are organic waste?
answer: 2
hint.en: Which ones rot in the soil?
explain.en: 2: the banana peel and the vegetable peel. The plastic bottle is inorganic.
mistake 3: thinks plastic is organic

## story
en: Three bins stood in a row at school. Green bin ate banana peels and said, yum, I will become manure! Blue bin collected plastic bottles for recycling. Red bin carefully took the old bulb and the medicine strip. Nothing ended up on the playground.

## picture
visual: steps organic 🍌 → compost / inorganic 🧴 → recycle / hazardous 💡 → special care
en: Three bins, three kinds of waste.
