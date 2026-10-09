Scriptname JM_RE_ImmersiveWenchesProvider Hidden
{Soft-dependency classifier for Immersive Wenches travelling/Maid Wenches.
Requires Immersive Wenches to be installed and matches only the mod's "Maid Wench"
display/base name so generic inn wenches and Hateful/Forgotten/Judgment wenches are excluded.}

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

	; Existing runtime evidence showed nearby Maid Wenches were reaching Core but being
	; rejected before cadence/force-greet.  Do not require the resolved actor base to be
	; owned by Immersive Wenches: travelling actors may resolve through leveled/template
	; records whose owning plugin differs from the visible Maid Wench population.
	; The soft dependency plus exact Maid Wench name remains the exclusion boundary.
	If !IsInstalled()
		Return False
	EndIf

	ActorBase directBase = akActor.GetActorBase()
	ActorBase leveledBase = akActor.GetLeveledActorBase()

	String actorName = akActor.GetDisplayName()
	If actorName == ""
		If directBase != None
			actorName = directBase.GetName()
		EndIf
	EndIf
	If actorName == "" && leveledBase != None
		actorName = leveledBase.GetName()
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
