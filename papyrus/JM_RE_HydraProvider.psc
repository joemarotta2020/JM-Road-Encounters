Scriptname JM_RE_HydraProvider Hidden
{Hydra Slavegirls provider for JM Road Encounters.

Exact-base caravan classifier built from JM_RE_HydraAudit output.
hyd_caravans contains 59 audited NPC bases:
- 10 caravan leaders
- 20 caravan guards
- 29 caravan slaves

Runtime caravan recognition requires an explicit ActorBase match.
Caravan role recognition requires explicit ActorBase matches.
Sacred Band recognition uses its dedicated hyd_sacredband faction only.
}

String Function GetPluginName() Global
	Return "hydra_slavegirls.esp"
EndFunction

Bool Function IsInstalled() Global
	Return (Game.GetFormFromFile(0x00072F71, GetPluginName()) as Faction) != None
EndFunction

Faction Function GetCaravanFaction() Global
	Return Game.GetFormFromFile(0x00072F71, GetPluginName()) as Faction
EndFunction

Faction Function GetSlaverFaction() Global
	Return Game.GetFormFromFile(0x0000B670, GetPluginName()) as Faction
EndFunction

Faction Function GetSacredBandFaction() Global
	Return Game.GetFormFromFile(0x0006CC45, GetPluginName()) as Faction
EndFunction

Bool Function IsSacredBand(Actor akActor) Global
	; The dedicated hyd_sacredband faction is the authoritative and cheapest
	; classifier for this observation-only population.
	If akActor == None
		Return False
	EndIf
	Faction sacredFaction = GetSacredBandFaction()
	Return sacredFaction != None && akActor.IsInFaction(sacredFaction)
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

Bool Function IsCaravanLeader(Actor akActor) Global
	; 10 audited hyd_straderXX_SlaveTrader bases.

	If BaseMatches(akActor, 0x0000A07A)
		Return True
	ElseIf BaseMatches(akActor, 0x0000A091)
		Return True
	ElseIf BaseMatches(akActor, 0x0000A609)
		Return True
	ElseIf BaseMatches(akActor, 0x0000DC49)
		Return True
	ElseIf BaseMatches(akActor, 0x0000DC5E)
		Return True
	ElseIf BaseMatches(akActor, 0x00012D81)
		Return True
	ElseIf BaseMatches(akActor, 0x00012D8B)
		Return True
	ElseIf BaseMatches(akActor, 0x00019A06)
		Return True
	ElseIf BaseMatches(akActor, 0x00019A0E)
		Return True
	ElseIf BaseMatches(akActor, 0x00019A1E)
		Return True
	EndIf

	Return False
EndFunction

Bool Function IsCaravanGuard(Actor akActor) Global
	; 20 audited hyd_sbguardXX caravan guard bases.

	; Primary guards.
	If BaseMatches(akActor, 0x0000A07F)
		Return True
	ElseIf BaseMatches(akActor, 0x0000A095)
		Return True
	ElseIf BaseMatches(akActor, 0x0000A60B)
		Return True
	ElseIf BaseMatches(akActor, 0x0000DC4B)
		Return True
	ElseIf BaseMatches(akActor, 0x0000DC61)
		Return True
	ElseIf BaseMatches(akActor, 0x00012D83)
		Return True
	ElseIf BaseMatches(akActor, 0x00012D8F)
		Return True
	ElseIf BaseMatches(akActor, 0x00019A0A)
		Return True
	ElseIf BaseMatches(akActor, 0x00019A12)
		Return True
	ElseIf BaseMatches(akActor, 0x00019A20)
		Return True

	; Alternate/b guards.
	ElseIf BaseMatches(akActor, 0x00066819)
		Return True
	ElseIf BaseMatches(akActor, 0x0006681B)
		Return True
	ElseIf BaseMatches(akActor, 0x00066821)
		Return True
	ElseIf BaseMatches(akActor, 0x00066825)
		Return True
	ElseIf BaseMatches(akActor, 0x00066829)
		Return True
	ElseIf BaseMatches(akActor, 0x0006682D)
		Return True
	ElseIf BaseMatches(akActor, 0x00066D93)
		Return True
	ElseIf BaseMatches(akActor, 0x00066D99)
		Return True
	ElseIf BaseMatches(akActor, 0x00066D9D)
		Return True
	ElseIf BaseMatches(akActor, 0x00066DA1)
		Return True
	EndIf

	Return False
EndFunction

Bool Function IsCaravanSlave(Actor akActor) Global
	; 29 audited caravan slave bases.

	; Primary caravan slaves.
	If BaseMatches(akActor, 0x0000A07C)
		Return True
	ElseIf BaseMatches(akActor, 0x0000A093)
		Return True
	ElseIf BaseMatches(akActor, 0x0000A60A)
		Return True
	ElseIf BaseMatches(akActor, 0x0000DC4D)
		Return True
	ElseIf BaseMatches(akActor, 0x0000DC63)
		Return True
	ElseIf BaseMatches(akActor, 0x00012D85)
		Return True
	ElseIf BaseMatches(akActor, 0x00012D8D)
		Return True
	ElseIf BaseMatches(akActor, 0x00019A08)
		Return True
	ElseIf BaseMatches(akActor, 0x00019A10)
		Return True
	ElseIf BaseMatches(akActor, 0x00019A22)
		Return True

	; Alternate/b caravan slaves.
	ElseIf BaseMatches(akActor, 0x00066817)
		Return True
	ElseIf BaseMatches(akActor, 0x0006681D)
		Return True
	ElseIf BaseMatches(akActor, 0x0006681F)
		Return True
	ElseIf BaseMatches(akActor, 0x00066823)
		Return True
	ElseIf BaseMatches(akActor, 0x00066827)
		Return True
	ElseIf BaseMatches(akActor, 0x0006682B)
		Return True
	ElseIf BaseMatches(akActor, 0x00066D91)
		Return True
	ElseIf BaseMatches(akActor, 0x00066D97)
		Return True
	ElseIf BaseMatches(akActor, 0x00066D9B)
		Return True
	ElseIf BaseMatches(akActor, 0x00066D9F)
		Return True

	; Pre-generated / legacy caravan slave bases.
	ElseIf BaseMatches(akActor, 0x00073583)
		Return True
	ElseIf BaseMatches(akActor, 0x00073584)
		Return True
	ElseIf BaseMatches(akActor, 0x00073585)
		Return True
	ElseIf BaseMatches(akActor, 0x00073586)
		Return True
	ElseIf BaseMatches(akActor, 0x00073588)
		Return True
	ElseIf BaseMatches(akActor, 0x00073589)
		Return True
	ElseIf BaseMatches(akActor, 0x0007358A)
		Return True
	ElseIf BaseMatches(akActor, 0x0007358B)
		Return True
	ElseIf BaseMatches(akActor, 0x0007358C)
		Return True
	EndIf

	Return False
EndFunction

Int Function GetCaravanRole(Actor akActor) Global
	; 0 none, 1 leader, 2 guard, 3 slave.
	; Fast faction gate first; exact ActorBase matching only runs for actual
	; hyd_caravans members instead of every NPC seen by Road Encounters.

	If akActor == None
		Return 0
	EndIf

	Faction caravanFaction = GetCaravanFaction()
	If caravanFaction == None || !akActor.IsInFaction(caravanFaction)
		Return 0
	EndIf

	If IsCaravanLeader(akActor)
		Return 1
	EndIf

	If IsCaravanGuard(akActor)
		Return 2
	EndIf

	If IsCaravanSlave(akActor)
		Return 3
	EndIf

	Return 0
EndFunction

Bool Function IsOtherSlaver(Actor akActor) Global
	; Deliberately disabled for now.
	;
	; hyd_SlaverFaction is valid, but it contains a much broader Hydra
	; population than the road caravans. Before Road Encounters starts using
	; those NPCs, we should audit which of them actually have roaming/travel
	; packages appropriate to this system.
	Return False
EndFunction