Scriptname JM_RE_Native Hidden
{Native proximity API for JM Road Encounters.
The DLL only finds nearby loaded actors. Encounter classification and gameplay remain in Papyrus.}

Bool Function IsAvailable() Global Native

Actor[] Function GetNearbyActors(ObjectReference akCenter, Float afRadius = 3500.0, Int aiMaxResults = 32) Global Native

; Returns the authoritative SSS_Whoring quest alias index for akActor by
; evaluating the four loaded SSS_WhoringIdle INFO condition chains directly.
; Returns -1 when the actor is not currently eligible.
Int Function ClassifySSSWhoringActor(Actor akActor) Global Native

; True while the actor is running the SSS force-greet package/template associated with the supplied quest alias index.
Bool Function IsSSSWhoringPackageActive(Actor akActor, Int aiAliasIndex) Global Native

; Returns the nearest currently eligible SSS_Whoring actor, using the same
; native high-process scan plus the loaded SSS_WhoringIdle INFO conditions.
Actor Function FindSSSWhoringActor(ObjectReference akCenter, Float afRadius = 2200.0, Int aiMaxResults = 64) Global Native

; True only while akActor is the live dialogue speaker and the current topic belongs to SSS_Whoring.
Bool Function IsSSSWhoringDialogueActive(Actor akActor) Global Native
