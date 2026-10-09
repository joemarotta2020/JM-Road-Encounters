Scriptname JM_RE_ImmersiveWenchesProvider Hidden
{Soft-dependency classifier for Immersive Wenches road contacts.
Uses the upstream Immersive Wenches faction rather than display names or actor-base ownership.}

String Function GetPluginName() Global
	Return "Immersive Wenches.esp"
EndFunction

Int Function GetWenchFactionLocalFormID() Global
	; Structural identifier used by other integrations in this load order.
	Return 0x0020D4D5
EndFunction

Bool Function IsInstalled() Global
	Return Game.GetModByName(GetPluginName()) != 255
EndFunction

Faction Function GetWenchFaction() Global
	If !IsInstalled()
		Return None
	EndIf
	Return Game.GetFormFromFile(GetWenchFactionLocalFormID(), GetPluginName()) as Faction
EndFunction

Bool Function IsMaidWench(Actor akActor) Global
	If akActor == None || akActor.IsDead() || akActor.IsDisabled() || akActor.IsPlayerTeammate()
		Return False
	EndIf

	Faction wenchFaction = GetWenchFaction()
	If wenchFaction == None
		Return False
	EndIf

	Return akActor.IsInFaction(wenchFaction)
EndFunction
