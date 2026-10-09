Scriptname JM_RE_HydraProvider Hidden
{Hydra Slavegirls provider for JM Road Encounters.
Faction membership is authoritative. Exact audited bases refine caravan roles but never suppress a faction-confirmed road contact.}

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
	If akActor == None
		Return False
	EndIf
	Faction f = GetSacredBandFaction()
	Return f != None && akActor.IsInFaction(f)
EndFunction

Bool Function BaseMatches(Actor akActor, Int aiLocalFormID) Global
	If akActor == None
		Return False
	EndIf
	ActorBase wanted = Game.GetFormFromFile(aiLocalFormID, GetPluginName()) as ActorBase
	If wanted == None
		Return False
	EndIf
	Return akActor.GetActorBase() == wanted || akActor.GetLeveledActorBase() == wanted
EndFunction

Bool Function IsCaravanLeader(Actor akActor) Global
	Return BaseMatches(akActor, 0x0000A07A) || BaseMatches(akActor, 0x0000A091) || BaseMatches(akActor, 0x0000A609) || BaseMatches(akActor, 0x0000DC49) || BaseMatches(akActor, 0x0000DC5E) || BaseMatches(akActor, 0x00012D81) || BaseMatches(akActor, 0x00012D8B) || BaseMatches(akActor, 0x00019A06) || BaseMatches(akActor, 0x00019A0E) || BaseMatches(akActor, 0x00019A1E)
EndFunction

Bool Function IsCaravanGuard(Actor akActor) Global
	Return BaseMatches(akActor, 0x0000A07F) || BaseMatches(akActor, 0x0000A095) || BaseMatches(akActor, 0x0000A60B) || BaseMatches(akActor, 0x0000DC4B) || BaseMatches(akActor, 0x0000DC61) || BaseMatches(akActor, 0x00012D83) || BaseMatches(akActor, 0x00012D8F) || BaseMatches(akActor, 0x00019A0A) || BaseMatches(akActor, 0x00019A12) || BaseMatches(akActor, 0x00019A20) || BaseMatches(akActor, 0x00066819) || BaseMatches(akActor, 0x0006681B) || BaseMatches(akActor, 0x00066821) || BaseMatches(akActor, 0x00066825) || BaseMatches(akActor, 0x00066829) || BaseMatches(akActor, 0x0006682D) || BaseMatches(akActor, 0x00066D93) || BaseMatches(akActor, 0x00066D99) || BaseMatches(akActor, 0x00066D9D) || BaseMatches(akActor, 0x00066DA1)
EndFunction

Bool Function IsCaravanSlave(Actor akActor) Global
	Return BaseMatches(akActor, 0x0000A07C) || BaseMatches(akActor, 0x0000A093) || BaseMatches(akActor, 0x0000A60A) || BaseMatches(akActor, 0x0000DC4D) || BaseMatches(akActor, 0x0000DC63) || BaseMatches(akActor, 0x00012D85) || BaseMatches(akActor, 0x00012D8D) || BaseMatches(akActor, 0x00019A08) || BaseMatches(akActor, 0x00019A10) || BaseMatches(akActor, 0x00019A22) || BaseMatches(akActor, 0x00066817) || BaseMatches(akActor, 0x0006681D) || BaseMatches(akActor, 0x0006681F) || BaseMatches(akActor, 0x00066823) || BaseMatches(akActor, 0x00066827) || BaseMatches(akActor, 0x0006682B) || BaseMatches(akActor, 0x00066D91) || BaseMatches(akActor, 0x00066D97) || BaseMatches(akActor, 0x00066D9B) || BaseMatches(akActor, 0x00066D9F) || BaseMatches(akActor, 0x00073583) || BaseMatches(akActor, 0x00073584) || BaseMatches(akActor, 0x00073585) || BaseMatches(akActor, 0x00073586) || BaseMatches(akActor, 0x00073588) || BaseMatches(akActor, 0x00073589) || BaseMatches(akActor, 0x0007358A) || BaseMatches(akActor, 0x0007358B) || BaseMatches(akActor, 0x0007358C)
EndFunction

Int Function GetCaravanRole(Actor akActor) Global
	; 0 none, 1 known leader, 2 known guard, 3 known slave, 4 faction-confirmed caravan member.
	If akActor == None
		Return 0
	EndIf
	Faction caravan = GetCaravanFaction()
	If caravan == None || !akActor.IsInFaction(caravan)
		Return 0
	EndIf
	If IsCaravanLeader(akActor)
		Return 1
	ElseIf IsCaravanGuard(akActor)
		Return 2
	ElseIf IsCaravanSlave(akActor)
		Return 3
	EndIf
	; Critical v6 behavior: faction membership is enough to remain actionable.
	Return 4
EndFunction

Bool Function IsOtherSlaver(Actor akActor) Global
	If akActor == None
		Return False
	EndIf
	Faction slaver = GetSlaverFaction()
	If slaver == None || !akActor.IsInFaction(slaver)
		Return False
	EndIf
	If GetCaravanRole(akActor) != 0 || IsSacredBand(akActor)
		Return False
	EndIf
	Return True
EndFunction
