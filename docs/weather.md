# Day, night and weather

`FarmWorld` composes one typed `WeatherManager`. `WeatherSchedule` owns the daily
forecast and modifiers; `DayNightComponent`, `WeatherEffects` and `WeatherHUD`
render it. No plugin is required.

## Clock and forecast

The existing monotonic Unix `FarmClock` remains authoritative. A day is **24 real
hours**, displayed in **UTC+7**. Weather changes at **06:00 local time**, not at
midnight. The integer day/seed roll is deterministic: 60% sunny, 20% rain, 10%
cloudy and 10% wind. Reloading the same day does not reroll. The seed and any
manual overrides are saved. `world.weather.set_weather(WeatherManager.Weather.RAIN)`
changes the remaining day, first settling all progress up to the change time.
Overrides expire at the next dawn; their timestamps preserve offline history.
Use the Remote inspector or a scratch test clock to preview other times without
changing the operating-system clock or an existing profile.

## World presentation

`CanvasModulate` multiplies only the world canvas. Independent HUD CanvasLayers
stay readable. Palette stops interpolate smoothly: navy `(0.22,0.25,0.45)` until
04:30, pink `(1,.85,.75)` at 05:00, white at 07:00 through 16:30, amber
`(.95,.65,.45)` at 18:30, navy again at 19:00. Warm PointLight2D lamps fade with
darkness at the authored building/window/gate anchors and follow the moving land
sign. Twelve small fireflies per garden appear at dusk/night and hide in rain.

Rain uses the existing drop and five-frame splash assets. Cloud shadows drift
across the farm at 15% opacity. Wind uses small procedural pink petal accents and a quiet, seamless eight-second
audio loop. It does not emit leaf sprites. Camera
coverage follows zoom and viewport resizing. Old weather fades out for one second,
then the next effect fades in for one second; renderers never overlap. Rapid
changes cancel the old tween. Simulation switches immediately at the timestamp.

## Gameplay

- **Rain:** wets every marked planting cell in unlocked columns, including newly
  opened columns during a rainy day. Locked soil and weeds remain dry. Moisture
  does not evaporate during rain. Pond ducks/geese produce 10% faster during
  supplied adult time; growth, lifetime, hunger and tonic rules remain intact.
  Bees shelter, removing active pollen/crop buffs. Stored honey and existing pollen
  credit remain; indoor work continues at the base Wild Honey rate.
- **Cloudy:** hydration drains at 75% of its normal rate, so animals visit the
  water trough less often. Trough stock is spent only on actual servings, as
  before. Soil evaporates at 75% speed.
- **Windy:** effective hive radius is 120px instead of 80px (+50%), including
  flower assignment, non-stacking crop buffs, focus circles and placement preview.
  Shared hive Resources are never mutated.
- **Sunny:** normal rates and radius.

Wet soil has a six-real-hour moisture budget; cloudy weather stretches a full
budget to eight hours. Rain refills it. Drying changes soil appearance and makes
watering available again; it does not delete plants or add a new growth gate.
Only tracked wet cells are visited during evaporation; wet tile edges are rebuilt
in one batch when cells expire.

## Saving and offline progress

Schema **10** adds `weather: {seed, changes:[{at,weather}]}` and `soil[].moisture`.
Version 9 migration preserves all farm progress and gives existing wet cells a
full moisture budget at `saved_at`. Weather and soil restore before animal/hive
catch-up. Moisture, hydration, produce and pollination split intervals at dawn
and manual weather boundaries. Today's weather never applies retroactively to
all offline time. Bad weather/history/moisture rejects the complete load before
mutation. Repeated loads/captures at the same timestamp do not duplicate progress.

Tests: `tests/unit/test_weather_schedule.gd` and
`tests/integration/test_weather.gd`, plus the existing save, farming, bee and
animal suites. Rendered previews should exercise all four weather types, night
lamps/fireflies and the 500×400 layout in an isolated profile.
