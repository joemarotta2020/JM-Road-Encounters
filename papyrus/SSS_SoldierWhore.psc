;BEGIN FRAGMENT CODE - Do not edit anything between this and the end comment
;NEXT FRAGMENT INDEX 3
Scriptname SSS_SoldierWhore Extends TopicInfo Hidden

;BEGIN FRAGMENT Fragment_1
Function Fragment_1(ObjectReference akSpeakerRef)
Actor akSpeaker = akSpeakerRef as Actor
;BEGIN CODE
JM_SSS_WhoringController JM_Cooldown = GetOwningQuest() as JM_SSS_WhoringController
If JM_Cooldown
	If !JM_Cooldown.TryClaimOriginalIdle(akSpeaker, 2)
		Return
	EndIf
EndIf
akSoldier.ForceRefTo(akSpeaker)
Debug.notification("Your attention is needed")
;END CODE
EndFunction
;END FRAGMENT

;BEGIN FRAGMENT Fragment_2
Function Fragment_2(ObjectReference akSpeakerRef)
Actor akSpeaker = akSpeakerRef as Actor
;BEGIN CODE
Debug.notification(" A soldier needs to talk with you")
;END CODE
EndFunction
;END FRAGMENT

;END FRAGMENT CODE - Do not edit anything between this and the begin comment

ReferenceAlias Property akSoldier  Auto
