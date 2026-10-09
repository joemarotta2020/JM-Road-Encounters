Scriptname JM_RE_PLRPProvider Hidden
{PLRP SE v3.2 provider for JM Road Encounters.
No hard plugin dependency. Factions are primary structural classifiers; exact bases are fallback/subtype detail only.}

String Function GetPluginName() Global
	Return "Populated Lands Roads Paths Legendary.esp"
EndFunction

Bool Function IsInstalled() Global
	Return Game.GetFormFromFile(0x0000B859, GetPluginName()) != None
EndFunction

Faction Function GetMerchantFaction() Global
	Return Game.GetFormFromFile(0x0000EF7F, GetPluginName()) as Faction
EndFunction
Faction Function GetMerchantBodyguardFaction() Global
	Return Game.GetFormFromFile(0x0001158C, GetPluginName()) as Faction
EndFunction
Faction Function GetAssassinFaction() Global
	Return Game.GetFormFromFile(0x0000A815, GetPluginName()) as Faction
EndFunction
Faction Function GetBountyHunterFaction() Global
	Return Game.GetFormFromFile(0x0000B859, GetPluginName()) as Faction
EndFunction
Faction Function GetWanderingMagicianFaction() Global
	Return Game.GetFormFromFile(0x0000C34C, GetPluginName()) as Faction
EndFunction
Faction Function GetWanderingKnightFaction() Global
	Return Game.GetFormFromFile(0x0000C358, GetPluginName()) as Faction
EndFunction
Faction Function GetMercenaryWizardFaction() Global
	Return Game.GetFormFromFile(0x0000C375, GetPluginName()) as Faction
EndFunction
Faction Function GetMercenaryWarriorFaction() Global
	Return Game.GetFormFromFile(0x0000C37F, GetPluginName()) as Faction
EndFunction
Faction Function GetMercenaryMissileFaction() Global
	Return Game.GetFormFromFile(0x0000C394, GetPluginName()) as Faction
EndFunction
Faction Function GetKnightOfTheFaithFaction() Global
	Return Game.GetFormFromFile(0x0000C90C, GetPluginName()) as Faction
EndFunction
Faction Function GetPilgrimFaction() Global
	Return Game.GetFormFromFile(0x0000D941, GetPluginName()) as Faction
EndFunction
Faction Function GetRefugeeFaction() Global
	Return Game.GetFormFromFile(0x000125E9, GetPluginName()) as Faction
EndFunction
Faction Function GetAdventurerFaction() Global
	Return Game.GetFormFromFile(0x00013BE8, GetPluginName()) as Faction
EndFunction

Bool Function BaseMatches(Actor akActor, Int aiLocalFormID) Global
	If akActor == None
		Return False
	EndIf
	ActorBase wantedBase = Game.GetFormFromFile(aiLocalFormID, GetPluginName()) as ActorBase
	If wantedBase == None
		Return False
	EndIf
	Return akActor.GetActorBase() == wantedBase || akActor.GetLeveledActorBase() == wantedBase
EndFunction

Int Function GetAdventurerRole(Actor akActor) Global
	; 1 leader, 2 warrior, 3 archer, 4 rogue, 5 wizard, 6 solitary/mounted, 7 generic/unknown adventurer.
	If akActor == None
		Return 0
	EndIf
	Faction adv = GetAdventurerFaction()
	If adv == None || !akActor.IsInFaction(adv)
		Return 0
	EndIf
	If BaseMatches(akActor, 0x00014198) || BaseMatches(akActor, 0x000141A4) || BaseMatches(akActor, 0x000141B8)
		Return 1
	ElseIf BaseMatches(akActor, 0x000141B1)
		Return 2
	ElseIf BaseMatches(akActor, 0x0001419E) || BaseMatches(akActor, 0x000141BB)
		Return 3
	ElseIf BaseMatches(akActor, 0x000141A0) || BaseMatches(akActor, 0x000141B3) || BaseMatches(akActor, 0x000141BD)
		Return 4
	ElseIf BaseMatches(akActor, 0x000141A2) || BaseMatches(akActor, 0x000141B5) || BaseMatches(akActor, 0x000141BF)
		Return 5
	ElseIf BaseMatches(akActor, 0x00014164) || BaseMatches(akActor, 0x00014165) || BaseMatches(akActor, 0x00014166) || BaseMatches(akActor, 0x00014167) || BaseMatches(akActor, 0x00013BE6) || BaseMatches(akActor, 0x00013BEE) || BaseMatches(akActor, 0x0001415F)
		Return 6
	EndIf
	; Do not discard a faction-confirmed adventurer just because its base was not in the old audit.
	Return 7
EndFunction

Bool Function IsVigilant(Actor akActor) Global
	If akActor == None
		Return False
	EndIf
	; Primary structural identity: vanilla Vigilant of Stendarr faction.
	Faction vigilantFaction = Game.GetFormFromFile(0x000B3292, "Skyrim.esm") as Faction
	If vigilantFaction != None && akActor.IsInFaction(vigilantFaction)
		Return True
	EndIf
	; Compatibility fallback for known PLRP bases whose faction may be altered by another plugin.
	Return BaseMatches(akActor, 0x0000BDCF) || BaseMatches(akActor, 0x0000BDD2) || BaseMatches(akActor, 0x0000BDD3) || BaseMatches(akActor, 0x0000BDD6) || BaseMatches(akActor, 0x0000BDD7) || BaseMatches(akActor, 0x0000BDD9) || BaseMatches(akActor, 0x0000BDDB)
EndFunction
