Scriptname JM_RE_ImmersiveWenchesProvider Hidden
{Soft-dependency classifier for Immersive Wenches travelling/Maid Wenches.
Uses plugin ownership plus the mod's Maid Wench display name so generic inn wenches
and wenches from Hateful/Forgotten/Judgment are never classified as this road category.}

String Function GetPluginName() Global
	Return "Immersive Wenches.esp"
EndFunction

Bool Function IsInstalled() Global
	Return Game.GetModByName(GetPluginName()) != 255
EndFunction

Bool Function IsFormFromPlugin(Form akForm) Global
	If akForm == None
		Return False
	EndIf

	Int modIndex = Game.GetModByName(GetPluginName())
	If modIndex == 255
		Return False
	EndIf

	Int formID = akForm.GetFormID()
	Return (formID / 0x01000000) == modIndex
EndFunction

Bool Function IsMaidWench(Actor akActor) Global
	If akActor == None || akActor.IsDead() || akActor.IsDisabled() || akActor.IsPlayerTeammate()
		Return False
	EndIf

	ActorBase directBase = akActor.GetActorBase()
	ActorBase leveledBase = akActor.GetLeveledActorBase()
	If !IsFormFromPlugin(directBase) && !IsFormFromPlugin(leveledBase)
		Return False
	EndIf

	String actorName = akActor.GetDisplayName()
	If actorName == ""
		If directBase != None
			actorName = directBase.GetName()
		EndIf
	EndIf

	; The upstream mod labels its travelling/castle-maid population "Maid Wench".
	; Keep both common capitalization variants for old/localized record revisions.
	If StringUtil.Find(actorName, "Maid Wench") >= 0
		Return True
	EndIf
	If StringUtil.Find(actorName, "Maid wench") >= 0
		Return True
	EndIf

	Return False
EndFunction
