# Animal status inspector

Hover an animal or face one within interaction range to inspect it. Mouse hover
wins when another animal is in front of the player. Only one information panel
is shown; the existing needs bars and idle response still support both targets.
Opening inventory/shop hides the inspector and releases the interaction hold.
Removing, selling or killing the animal clears the panel safely.

The screen-space panel shows species and short persistent ID, time until
maturity (or Adult), remaining lifetime, current produce, cycle percentage
and the reason production is paused. It refreshes
while focused and responds to live language changes.

The production blockers match the lifecycle calculation:

- Not mature yet.
- Needs food (satiety is zero).
- Needs water (hydration is zero).
- Missing/invalid production configuration or an unavailable animal.

Multiple blockers appear together. Idle, focus, resting, sleeping and accumulated
output do not stop the production clock, so they are never reported as blockers.
The cycle percentage retains partial progress while paused. Age/lifetime keep
following the existing real-time clock and offline rules.

`AnimalInfoPanel` owns the UI; `AnimalStatusText` reads the animal without
advancing time or changing growth, needs, stock or inventory. `ContextBarsComponent`
automatically creates the shared `scenes/ui/animal_info.tscn` inspector if no
instance is assigned. Resale details reuse the same status text. The UI requires
no save schema migration. All messages are in the English/Vietnamese PO catalogs.
