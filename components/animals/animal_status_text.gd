class_name AnimalStatusText
extends RefCounted
## Read-only presentation shared by the field inspector and animal resale details.
## Focus/rest/sleep and stored output do not pause the production clock.
func is_available(animal: AnimalActor) -> bool:
	return is_instance_valid(animal) and not animal.is_queued_for_deletion() and animal.is_inside_tree() and animal.definition != null and not animal.is_dead() and animal.growth != null and not animal.growth.is_dead()

func remaining(seconds: float) -> String:
	var total: int = ceili(maxf(0.0, seconds))
	if total >= 86400:
		return tr("{days}d {hours}h").format({"days": total / 86400, "hours": total % 86400 / 3600})
	if total >= 3600:
		return tr("{hours}h {minutes}m").format({"hours": total / 3600, "minutes": total % 3600 / 60})
	if total >= 60:
		return tr("{minutes}m {seconds}s").format({"minutes": total / 60, "seconds": total % 60})
	return tr("{seconds}s").format({"seconds": total})

func maturity(animal: AnimalActor) -> String:
	var result: String = tr("Adult") if animal.growth.is_adult() else tr("Matures in {time}").format({"time": remaining(animal.growth.seconds_until_adult())})
	return result

func lifetime(animal: AnimalActor) -> String:
	return tr("Life left: {time}").format({"time": remaining(animal.growth.seconds_until_death())})

func produce(animal: AnimalActor) -> String:
	var definition: AnimalProductionDefinition = animal.production.definition
	if definition == null or not definition.is_valid():
		return tr("No produce configured")
	var result: String = tr("{item}: {percent}%").format({"item": tr(definition.production_item.display_name), "percent": floori(clampf(animal.production.progress_ratio(), 0.0, 1.0) * 100.0)})

	return result + " · " + tr("Tonic") if animal.production.tonic_pending else result

func production_state(animal: AnimalActor) -> String:
	if not is_available(animal):
		return tr("Animal unavailable")
	if animal.production.definition == null or not animal.production.definition.is_valid():
		return tr("No produce configured")
	var reasons: PackedStringArray = []
	if not animal.growth.is_adult():
		reasons.append(tr("Not mature yet"))
	if animal.needs.satiety <= 0.0:
		reasons.append(tr("Needs food"))
	if animal.needs.hydration <= 0.0:
		reasons.append(tr("Needs water"))
	if not reasons.is_empty():
		return tr("Paused: {reasons}").format({"reasons": tr(" · ").join(reasons)})
	if animal.needs.weather != null and animal.needs.time_manager != null:
		var weather: int = animal.needs.weather.weather_at(animal.needs.time_manager.now())
		if weather == WeatherSchedule.Weather.RAIN and animal.pen is PondPen and animal.definition.eggs_on_land:
			return tr("Rain comfort · Produce +10%")
		if weather == WeatherSchedule.Weather.CLOUDY:
			return tr("Producing · Water use -25%")
	return tr("Producing")

func summary(animal: AnimalActor) -> String:
	if not is_available(animal):
		return tr("Animal unavailable")
	return "\n".join([maturity(animal), lifetime(animal), produce(animal), production_state(animal)])
