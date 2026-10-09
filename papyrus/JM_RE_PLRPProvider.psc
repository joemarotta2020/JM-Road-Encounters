Scriptname JM_RE_PLRPProvider Hidden
{PLRP SE v3.2 provider for JM Road Encounters.
No hard plugin dependency. All forms are resolved at runtime.}

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

Faction Function GetVanillaVigilantFaction() Global
	; Skyrim.esm Vigilant of Stendarr faction.
	Return Game.GetFormFromFile(0x000B3292, "Skyrim.esm") as Faction
EndFunction

Bool Function BaseMatches(Actor akActor, Int aiLocalFormID) Global
	ActorBase wantedBase
	ActorBase directBase
	ActorBase leveledBase

	If akActor == None
		Return False
	EndIf

	wantedBase = Game.GetFormFromFile(aiLocalFormID, GetPluginName()) as ActorBase
	If wantedBase == None
		Return False
	EndIf

	directBase = akActor.GetActorBase()
	If directBase == wantedBase
		Return True
	EndIf

	leveledBase = akActor.GetLeveledActorBase()
	If leveledBase == wantedBase
		Return True
	EndIf

	Return False
EndFunction

Int Function GetAdventurerRole(Actor akActor) Global
	; 1 leader, 2 warrior, 3 archer, 4 rogue, 5 wizard, 6 solitary/mounted.

	If BaseMatches(akActor, 0x00014198)
		Return 1
	ElseIf BaseMatches(akActor, 0x000141A4)
		Return 1
	ElseIf BaseMatches(akActor, 0x000141B8)
		Return 1
	EndIf

	If BaseMatches(akActor, 0x000141B1)
		Return 2
	EndIf

	If BaseMatches(akActor, 0x0001419E)
		Return 3
	ElseIf BaseMatches(akActor, 0x000141BB)
		Return 3
	EndIf

	If BaseMatches(akActor, 0x000141A0)
		Return 4
	ElseIf BaseMatches(akActor, 0x000141B3)
		Return 4
	ElseIf BaseMatches(akActor, 0x000141BD)
		Return 4
	EndIf

	If BaseMatches(akActor, 0x000141A2)
		Return 5
	ElseIf BaseMatches(akActor, 0x000141B5)
		Return 5
	ElseIf BaseMatches(akActor, 0x000141BF)
		Return 5
	EndIf

	If BaseMatches(akActor, 0x00014164)
		Return 6
	ElseIf BaseMatches(akActor, 0x00014165)
		Return 6
	ElseIf BaseMatches(akActor, 0x00014166)
		Return 6
	ElseIf BaseMatches(akActor, 0x00014167)
		Return 6
	ElseIf BaseMatches(akActor, 0x00013BE6)
		Return 6
	ElseIf BaseMatches(akActor, 0x00013BEE)
		Return 6
	ElseIf BaseMatches(akActor, 0x0001415F)
		Return 6
	EndIf

	Return 0
EndFunction

Bool Function IsVigilant(Actor akActor) Global
	If akActor == None || akActor.IsDead() || akActor.IsDisabled()
		Return False
	EndIf

	; Primary structural classifier: any actor in the standard Vigilant faction.
	Faction vigilantFaction = GetVanillaVigilantFaction()
	If vigilantFaction != None && akActor.IsInFaction(vigilantFaction)
		Return True
	EndIf

	; Compatibility fallback for PLRP records that may not retain faction membership
	; through templates/overrides.
	If BaseMatches(akActor, 0x0000BDCF)
		Return True
	ElseIf BaseMatches(akActor, 0x0000BDD2)
		Return True
	ElseIf BaseMatches(akActor, 0x0000BDD3)
		Return True
	ElseIf BaseMatches(akActor, 0x0000BDD6)
		Return True
	ElseIf BaseMatches(akActor, 0x0000BDD7)
		Return True
	ElseIf BaseMatches(akActor, 0x0000BDD9)
		Return True
	ElseIf BaseMatches(akActor, 0x0000BDDB)
		Return True
	EndIf

	Return False
EndFunction
