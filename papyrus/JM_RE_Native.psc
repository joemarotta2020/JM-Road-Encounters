Scriptname JM_RE_Native Hidden
{Native proximity API for JM Road Encounters.
The DLL only finds nearby loaded actors. Encounter classification and gameplay remain in Papyrus.}

Bool Function IsAvailable() Global Native

Actor[] Function GetNearbyActors(ObjectReference akCenter, Float afRadius = 3500.0, Int aiMaxResults = 32) Global Native
