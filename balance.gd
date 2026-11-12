class_name Balance
extends RefCounted
## Tous les chiffres d'équilibrage du jeu au même endroit.
## Tu peux les modifier ici sans toucher au reste du code.
## (L'équilibrage définitif de l'économie est prévu en phase 9.)

const START_MONEY := 250000                 # argent au début d'une nouvelle partie (CDF)
const TEST_BONUS := 5000000                 # bouton "Mode test" du profil (outil de test, à retirer avant publication)
const START_VEHICLE_ID := "tvs_hlx150"      # véhicule de départ
const START_CONDITION := 82.0               # état de la moto de départ (%), elle est d'occasion
const FUEL_PRICE_CDF := 2900                # prix d'un litre de carburant (CDF)
const FUEL_SCALE := 15.0                    # 1 km joué consomme comme 15 km réels (la carte de test est petite)
const WEAR_PER_KM := 0.25                   # points d'état perdus par km joué
const CRASH_MIN_IMPACT := 2.5               # m/s perdus d'un coup avant de compter comme un choc
const CRASH_DAMAGE_PER_MS := 1.2            # points d'état perdus par m/s au-delà du seuil
const RESALE_BASE := 0.40                   # part du prix récupérée à la revente (état 0 %)
const RESALE_CONDITION := 0.40              # part en plus selon l'état (état 100 % -> 80 % du prix)
const REPAIR_COST_PER_POINT_PCT := 0.002    # réparer 1 point d'état coûte 0,2 % du prix du véhicule
const MIN_CONDITION_FACTOR := 0.70          # un véhicule à 0 % d'état garde 70 % de ses performances
const MAX_LEDGER := 400                     # nombre maximum de lignes gardées dans l'historique
const SAVE_VERSION := 1


## Formate un montant : 3000000 -> "3 000 000 CDF"
static func cdf(amount: int) -> String:
	var digits := str(absi(amount))
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = " " + out
	return ("-" if amount < 0 else "") + out + " CDF"
