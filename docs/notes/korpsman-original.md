# Korpsman: original vs. redux

Source: liverfailurewar `fates/list/korpsman.lua` plus its `surgeries/` directory.

- Kit is knives (knife/shank) and a weapon permit. There is no generic "surgical tools" item.
- First revive of someone else, with ReviveFee: fee = floor((corpse bones + patient bones) * revive_fee / 100), taken from the body first, then the player. The korpsman is promoted (`GR_UpgradedMedic`) and gets a lovebox.
- Lovebox: primary heals the patient (+2 HP for 1 HP of the holder's), secondary lowers Pox (-3 for 2 HP; the holder may catch some), reload on a patient under 1/4 health pulls out a parasite.
- Surgeries are timed actions (`Actions` kind "surgery") that freeze both players, then the server rolls. Failure costs the patient 10 HP and the korpsman 10 Despair. Interrupting stuns the patient briefly and changes nothing else.
- Procedures: seal, bloodletting, thinning, sanguinary, parasitectomy, laparotomy, cripplement, plastic, cardiac, rage, bullet.

## Deviation
In the original, paying HP at <=1 HP could kill the korpsman. Here the lovebox refuses ("too weak") when the payment would leave less than 1 HP.
