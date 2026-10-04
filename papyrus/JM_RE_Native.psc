Scriptname JM_RE_Native Hidden
{Native proximity API for JM Road Encounters.
The DLL only finds nearby loaded actors. Encounter classification and gameplay remain in Papyrus.}

Bool Function IsAvailable() Global Native

; Append a high-value Papyrus diagnostic line to JM_RoadEncounters.log.
Function LogDiagnostic(String asMessage) Global Native

Actor[] Function GetNearbyActors(ObjectReference akCenter, Float afRadius = 3500.0, Int aiMaxResults = 32) Global Native

; Stable indexed scanner for Papyrus consumers. ScanNearbyActors performs one
; bounded native enumeration and stores actor handles in an isolated client slot.
; GetScannedActor returns one actor at a time, avoiding native Actor[] transfer.
Int Function ScanNearbyActors(ObjectReference akCenter, Float afRadius = 3500.0, Int aiMaxResults = 32, Int aiClientId = 0) Global Native
Actor Function GetScannedActor(Int aiClientId, Int aiIndex) Global Native

; Returns the best SSS_Whoring quest alias for akActor. Exact loaded INFO
; conditions are preferred; a conservative explicit fallback keeps acquisition
; functional when dialogue-condition emulation cannot classify a valid actor.
; Returns -1 when the actor is not currently usable.
Int Function ClassifySSSWhoringActor(Actor akActor) Global Native

; True while the actor is running the SSS force-greet package/template associated with the supplied quest alias index.
Bool Function IsSSSWhoringPackageActive(Actor akActor, Int aiAliasIndex) Global Native

; Returns the nearest usable SSS_Whoring actor. Exact INFO eligibility is
; preferred; conservative explicit classification is the reliability fallback.
Actor Function FindSSSWhoringActor(ObjectReference akCenter, Float afRadius = 2200.0, Int aiMaxResults = 64, Actor akExclude1 = None, Actor akExclude2 = None, Actor akExclude3 = None) Global Native

; True only while akActor is the live dialogue speaker and the current topic belongs to SSS_Whoring.
Bool Function IsSSSWhoringDialogueActive(Actor akActor) Global Native
