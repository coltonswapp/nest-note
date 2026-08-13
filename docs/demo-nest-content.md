# Demo nest content

Edit this file, then ask to apply it. I will diff against `DemoNestSeed.swift` / the seeder and update.

Use the field labels as-is. Blank line between items. `pinned: yes` or `no`. Types: `note`, `routine`, `place`.

For routines, one action per `-`  line.
For places, `preview` is the card/body text; `address` and `lat`/`lng` are the map pin.

---

Name: The Hart Nest
Address: 414 Maple Street, Austin, TX

## Household

pinned: yes

### WiFi Password

type: note
SuperStrongPassword

### Garage Code

type: note
8005

### Leaving House

type: routine

- Check all doors
- Turn off lights
- Dog in kennel
- Arm security system



### Trash Day

type: note
Bins out Tuesday night. Recycling only when above halfway full (blue bin).

### Alarm Code

type: note
4321 — disarm within 30 seconds of opening the door.

### Coming Home

type: routine

- Disarm alarm
- Hang keys by door
- Unpack bags
- Wash hands



### Thermostat

type: note
Keep around 68°F. Away mode is fine overnight.

### Water Shutoff

type: note
Basement, north wall — red valve.

### Neighbor Help

type: place
preview: Mrs. Wilson — (555) 234-5678
address: 418 Maple Street, Austin, TX
lat: 30.2672
lng: -97.7431
map: map-placeholder2

## Children

pinned: yes

### Allergies

type: note
Peanuts and penicillin. EpiPen on the top shelf in the pantry.

### Bedtime Routine

type: routine

- Brush teeth
- Put on pajamas
- Read a story
- Turn on nightlight
- Close door halfway



### School Office

type: note
(555) 111-2222 — ask for the front desk.

### After School

type: routine

- Hang up backpack
- Wash hands
- Have a snack
- Start homework



### Pediatrician

type: note
Dr. Smith — (555) 987-6543

### Bath Time

type: routine

- Fill tub to marked line
- Wash hair
- Rinse thoroughly
- Dry off and lotion



### Screen Time

type: note
45 minutes max after homework. Keep volume reasonable.

### School

type: place
preview: Lincoln Elementary — drop-off at the main loop.
address: Lincoln Elementary, Austin, TX
lat: 30.2849
lng: -97.7341
map: map-placeholder1

### Soccer Practice

type: place
preview: Thursday 4:30pm at Rec Center Field 2.
address: Rec Center Field 2, Austin, TX
lat: 30.2600
lng: -97.7530
map: map-placeholder4

## Pets

pinned: yes

### Pet Names

type: note
Dog: Max · Cat: Luna · Fish: Bubbles

### Pet Care

type: routine

- Fill water bowl
- Give food
- Let outside / litter check
- Play for 10 minutes



### Dog Food

type: note
1 cup morning and evening. Food is in the pantry bin.

### Treat Rules

type: note
Max 2 treats per day — no chocolate, ever.

### Leash Location

type: note
Hanging by the front door with the poop bags.

### No-Go Areas

type: note
Keep pets out of the formal dining room and guest bedroom.

### Veterinarian

type: note
Animal Hospital — (555) 789-4561

### Pet Sitter

type: note
Emily — (555) 222-3333

### Favorite Park

type: place
preview: Sunrise Meadow Park — Max's usual walk loop.
address: Zilker Park, Austin, TX
lat: 30.2669
lng: -97.7729
map: map-placeholder3

## Plants

pinned: no

### Watering Schedule

type: note
Most houseplants: every 7–10 days. Check soil first — if damp, wait.

### Plant Care

type: routine

- Check soil moisture
- Water until it drains
- Empty saucers
- Rotate pots a quarter turn



### Fiddle Leaf Fig

type: note
Bright indirect light by the living room window. Water sparingly.

### Herbs on Sill

type: note
Basil & mint — water when the top inch is dry. Snip often.

### Succulents

type: note
Kitchen shelf. Water lightly every 2–3 weeks. No misting.

### Plant Food

type: note
Liquid fertilizer under the sink. Use half-strength monthly in summer.

### Yard Service

type: note
Every Monday, 11am–2pm. Leave the side gate unlocked.

### Outdoor Hose

type: note
Spigot on the east side. Timer is set for early mornings.

### Garden Bed

type: place
preview: Backyard raised beds — tomatoes & peppers along the fence.
address: 414 Maple Street backyard, Austin, TX
lat: 30.2650
lng: -97.7500
map: map-placeholder5

## Sessions

Titles should not assume a weekday unless the timing is fixed. `items` is how many nest items (in catalog order) are included.

### In progress

title: Friday night
offset: -2 hours to +3 hours
items: 8

### Upcoming

title: Saturday afternoon
offset: +1 day, 4 hours long
items: 5

### Completed

title: Tuesday evening
offset: -3 days, 4 hours long
items: 6