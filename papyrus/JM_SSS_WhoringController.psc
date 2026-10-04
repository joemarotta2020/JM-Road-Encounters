Scriptname JM_SSS_WhoringController extends Quest

; JM Skyrim Shrouded Secret - deterministic acquisition + existing Predator layer.
;
; Acquisition architecture:
; - JM_RoadEncounters.dll performs the nearby high-process actor scan.
; - The DLL uses explicit, cheap actor classification; it does NOT try to
;   emulate opaque SSS dialogue INFO condition chains.
; - The ORIGINAL SSS alias/package/dialogue path is the final authority.
; - Once an actor qualifies, this script force-fills the ORIGINAL SSS_Whoring
;   alias and lets the ORIGINAL SSS force-greet package drive the approach.
; - Cooldown is committed only after the native service verifies that the
;   selected actor is actually the live SSS_Whoring dialogue speaker.
; - The old idle-dialog acquisition remains present as a fallback.  Native
;   acquisition temporarily reserves ReadyGlobal while an approach is pending,
;   preventing the two paths from racing each other.
; - No native actor scan runs during the 20-hour cooldown.
;
; Reliability / reload handling:
; - the DLL calls NativeWakeScanner() after every load/new game;
; - stale approach aliases are cleared on load so a saved force-greet package
;   cannot replay just because the save was reloaded;
; - a failed approach does NOT consume cooldown; it clears its alias, restores
;   ReadyGlobal and retries;
; - diagnostics identify every acquisition, reservation, package verification,
;   dialogue commit, timeout and cooldown transition.

GlobalVariable Property ReadyGlobal Auto
Spell Property PredatorHitListenerSpell Auto

Float Property CooldownHours = 20.0 Auto Hidden

; Deterministic acquisition.  Two seconds is intentionally persistent while
; eligible, but the scan is native and bounded to loaded/high-process actors.
Float Property AcquisitionScanSeconds = 2.0 Auto Hidden
Float Property AcquisitionPendingPollSeconds = 0.5 Auto Hidden
Float Property AcquisitionRetrySeconds = 3.0 Auto Hidden
Float Property AcquisitionRadius = 2200.0 Auto Hidden
Int Property AcquisitionMaxActors = 64 Auto Hidden
Int Property AcquisitionTimeoutTicks = 16 Auto Hidden ; 16 * 0.5s = 8 seconds
Int Property AcquisitionReevaluateEveryTicks = 2 Auto Hidden ; re-evaluate every 1 second while pending
Bool Property AcquisitionDiagnostics = True Auto Hidden

; Major encounters are intentionally rare. Once the clock is eligible, each
; committed SSS approach gets this chance unless RetaliationPending guarantees it.
Float Property MajorMinHours = 72.0 Auto Hidden
Float Property MajorMaxHours = 120.0 Auto Hidden
Int Property MajorChance = 35 Auto Hidden

; Fighting off a Predator is a real win, but accelerates/guarantees retaliation.
Float Property RetaliationMinHours = 24.0 Auto Hidden
Float Property RetaliationMaxHours = 48.0 Auto Hidden

; Predator combat tuning.
Float Property PredatorSpeedBoost = 25.0 Auto Hidden
Float Property PredatorStaminaDrain = 20.0 Auto Hidden
Float Property PredatorMagickaDrain = 15.0 Auto Hidden
Float Property PredatorHealFraction = 0.50 Auto Hidden
Int Property PredatorDisarmChance = 40 Auto Hidden

; Save-persistent cooldown / major state.
Float Property NextEligibleGameTime = 0.0 Auto Hidden
Float Property NextMajorEligibleGameTime = 0.0 Auto Hidden
Bool Property RetaliationPending = False Auto Hidden
Bool Property CurrentEncounterMajor = False Auto Hidden
Bool Property PredatorCombatActive = False Auto Hidden

; Current committed encounter / Predator state.
Actor CurrentEncounterActor = None
Actor CurrentPredator = None
ActorBase CurrentPredatorBase = None
Int OriginalRelationshipRank = 0
Bool OriginalEssential = False
Bool OriginalGhost = False
Bool OriginalNoBleedoutRecovery = False
Float AppliedSpeedBoost = 0.0
Int CombatQuietTicks = 0
Bool PlayerDefeatObserved = False

; Acquisition state.  These are intentionally simple/save-persistent values;
; NativeWakeScanner reconciles them after a load instead of trusting stale state.
Bool NativeScannerAvailable = False
Bool AcquisitionPending = False
Actor AcquisitionActor = None
Int AcquisitionAliasIndex = -1
Int AcquisitionWaitTicks = 0
Int AcquisitionScanCounter = 0
Int AcquisitionFailureCounter = 0

; A failed force-greet must not monopolize acquisition forever.  Keep a small
; rolling skip set so another eligible NPC gets a chance immediately.
Int Property AcquisitionFailureExcludeScans = 15 Auto Hidden
Actor AcquisitionFailedActor1 = None
Actor AcquisitionFailedActor2 = None
Actor AcquisitionFailedActor3 = None
Int AcquisitionFailedActor1Scans = 0
Int AcquisitionFailedActor2Scans = 0
Int AcquisitionFailedActor3Scans = 0

Event OnInit()
    JM_ResolveRuntimeForms()
    JM_RegisterEvents()
    JM_InitializeMajorClock()
    JM_ReconcileCooldown()
    JM_ClearStaleApproachAliases("OnInit")
    JM_RefreshNativeAvailability()
    JM_ScheduleAcquisitionIfReady(1.0)
    Debug.Trace("[JM SSS][BOOT] controller initialized; native=" + NativeScannerAvailable)
EndEvent

; Called directly by JM_RoadEncounters.dll on SKSE PostLoadGame/NewGame.
; This is the authoritative reload reconciliation point.
Function NativeWakeScanner()
    JM_ResolveRuntimeForms()
    JM_RegisterEvents()
    JM_InitializeMajorClock()

    ; Never trust a half-finished pre-save approach.  This is the key difference
    ; from the original implementation that could replay a force-greet on reload.
    If !PredatorCombatActive
        JM_ClearStaleApproachAliases("post-load")
        JM_ResetAcquisitionState(False)
        JM_ClearFailedActors()
    EndIf

    JM_ReconcileCooldown()
    JM_RefreshNativeAvailability()

    Float now = Utility.GetCurrentGameTime()
    Float remaining = 0.0
    If NextEligibleGameTime > now
        remaining = (NextEligibleGameTime - now) * 24.0
    EndIf

    Debug.Trace("[JM SSS][BOOT] native post-load wake: native=" + NativeScannerAvailable + ", ready=" + JM_IsReady() + ", cooldownRemainingHours=" + remaining + ", predator=" + PredatorCombatActive)

    If PredatorCombatActive
        UnregisterForUpdate()
        RegisterForSingleUpdate(0.5)
    Else
        JM_ScheduleAcquisitionIfReady(0.5)
    EndIf
EndFunction

Function JM_ResolveRuntimeForms()
    ; Keep VMAD properties for compatibility, but self-heal if the winning
    ; plugin/script attachment has stale or missing property data.
    If ReadyGlobal == None
        ReadyGlobal = Game.GetFormFromFile(0x00000800, "JM_SSS_Overhaul.esp") as GlobalVariable
    EndIf
    If PredatorHitListenerSpell == None
        PredatorHitListenerSpell = Game.GetFormFromFile(0x00000802, "JM_SSS_Overhaul.esp") as Spell
    EndIf

    If ReadyGlobal == None
        Debug.Trace("[JM SSS][BOOT] ERROR: JM_SSS_WhoringReady could not be resolved")
    EndIf
    If PredatorHitListenerSpell == None
        Debug.Trace("[JM SSS][BOOT] WARNING: JM_SSS_PredatorHitListener could not be resolved")
    EndIf
EndFunction

Function JM_RegisterEvents()
    UnregisterForModEvent("HookAnimationEnd")
    RegisterForModEvent("HookAnimationEnd", "JM_OnAnimationEnd")
EndFunction

Function JM_RefreshNativeAvailability()
    NativeScannerAvailable = JM_RE_Native.IsAvailable()
    If !NativeScannerAvailable
        Debug.Trace("[JM SSS][ACQ] WARNING: JM Road Encounters native scanner unavailable; retaining original SSS idle acquisition as fallback")
    EndIf
EndFunction

Bool Function JM_IsReady()
    If ReadyGlobal == None
        Return False
    EndIf
    Return ReadyGlobal.GetValueInt() == 1
EndFunction

Function JM_SetReady(Bool abReady)
    If ReadyGlobal == None
        Return
    EndIf
    If abReady
        ReadyGlobal.SetValueInt(1)
    Else
        ReadyGlobal.SetValueInt(0)
    EndIf
EndFunction

ReferenceAlias Function JM_GetApproachAlias(Int aiAliasIndex)
    Return GetAlias(aiAliasIndex) as ReferenceAlias
EndFunction

Function JM_ClearAliasIndex(Int aiAliasIndex, String asReason)
    ReferenceAlias approachAlias = JM_GetApproachAlias(aiAliasIndex)
    If approachAlias == None
        Return
    EndIf

    ObjectReference held = approachAlias.GetReference()
    If held != None
        If AcquisitionDiagnostics
            Debug.Trace("[JM SSS][ACQ] clearing alias " + aiAliasIndex + " ref=" + held + " reason=" + asReason)
        EndIf
        approachAlias.Clear()
        Actor heldActor = held as Actor
        If heldActor != None
            heldActor.EvaluatePackage()
        EndIf
    EndIf
EndFunction

Function JM_ClearStaleApproachAliases(String asReason)
    ; These are the four aliases populated by the four SSS_WhoringIdle entry
    ; paths that JM now acquires deterministically.
    JM_ClearAliasIndex(0, asReason)
    JM_ClearAliasIndex(2, asReason)
    JM_ClearAliasIndex(3, asReason)
    JM_ClearAliasIndex(5, asReason)
EndFunction

Function JM_ResetAcquisitionState(Bool abRestoreReady)
    AcquisitionPending = False
    AcquisitionActor = None
    AcquisitionAliasIndex = -1
    AcquisitionWaitTicks = 0

    If abRestoreReady
        Float now = Utility.GetCurrentGameTime()
        If NextEligibleGameTime <= now && !PredatorCombatActive
            JM_SetReady(True)
        EndIf
    EndIf
EndFunction

Function JM_ScheduleAcquisitionIfReady(Float afDelay = 0.0)
    If PredatorCombatActive || AcquisitionPending || !NativeScannerAvailable || !JM_IsReady()
        Return
    EndIf

    If afDelay < 0.1
        afDelay = AcquisitionScanSeconds
    EndIf

    UnregisterForUpdate()
    RegisterForSingleUpdate(afDelay)
EndFunction

Bool Function JM_CanScanNow()
    Actor PlayerRef = Game.GetPlayer()
    If PlayerRef == None || PlayerRef.IsDead() || PlayerRef.IsGhost()
        Return False
    EndIf

    If PlayerRef.GetSleepState() != 0
        Return False
    EndIf

    ; Do not seize an NPC while the player is already interacting with a menu,
    ; another conversation, or combat. The scan remains armed and retries.
    If PlayerRef.IsInCombat() || Utility.IsInMenuMode() || UI.IsMenuOpen("Dialogue Menu")
        Return False
    EndIf

    Return True
EndFunction

Function JM_ClearFailedActors()
    AcquisitionFailedActor1 = None
    AcquisitionFailedActor2 = None
    AcquisitionFailedActor3 = None
    AcquisitionFailedActor1Scans = 0
    AcquisitionFailedActor2Scans = 0
    AcquisitionFailedActor3Scans = 0
EndFunction

Function JM_TickFailedActorExclusions()
    If AcquisitionFailedActor1Scans > 0
        AcquisitionFailedActor1Scans -= 1
        If AcquisitionFailedActor1Scans <= 0
            AcquisitionFailedActor1 = None
        EndIf
    EndIf
    If AcquisitionFailedActor2Scans > 0
        AcquisitionFailedActor2Scans -= 1
        If AcquisitionFailedActor2Scans <= 0
            AcquisitionFailedActor2 = None
        EndIf
    EndIf
    If AcquisitionFailedActor3Scans > 0
        AcquisitionFailedActor3Scans -= 1
        If AcquisitionFailedActor3Scans <= 0
            AcquisitionFailedActor3 = None
        EndIf
    EndIf
EndFunction

Function JM_RememberFailedActor(Actor akActor)
    If akActor == None
        Return
    EndIf

    If AcquisitionFailedActor1 == akActor
        AcquisitionFailedActor1Scans = AcquisitionFailureExcludeScans
        Return
    ElseIf AcquisitionFailedActor2 == akActor
        AcquisitionFailedActor2Scans = AcquisitionFailureExcludeScans
        Return
    ElseIf AcquisitionFailedActor3 == akActor
        AcquisitionFailedActor3Scans = AcquisitionFailureExcludeScans
        Return
    EndIf

    ; Rotate oldest slots.  Three is enough to prevent one or two busy NPCs
    ; from starving the rest of the eligible population without creating a
    ; permanent blacklist.
    AcquisitionFailedActor3 = AcquisitionFailedActor2
    AcquisitionFailedActor3Scans = AcquisitionFailedActor2Scans
    AcquisitionFailedActor2 = AcquisitionFailedActor1
    AcquisitionFailedActor2Scans = AcquisitionFailedActor1Scans
    AcquisitionFailedActor1 = akActor
    AcquisitionFailedActor1Scans = AcquisitionFailureExcludeScans
    Debug.Trace("[JM SSS][ACQ] temporarily excluding failed actor=" + akActor + " for " + AcquisitionFailureExcludeScans + " scans")
EndFunction

Function JM_RunAcquisitionScan()
    If !NativeScannerAvailable || !JM_IsReady() || AcquisitionPending || PredatorCombatActive
        Return
    EndIf

    If !JM_CanScanNow()
        RegisterForSingleUpdate(AcquisitionRetrySeconds)
        Return
    EndIf

    Actor PlayerRef = Game.GetPlayer()
    AcquisitionScanCounter += 1
    JM_TickFailedActorExclusions()

    Actor candidate = JM_RE_Native.FindSSSWhoringActor(PlayerRef, AcquisitionRadius, AcquisitionMaxActors, AcquisitionFailedActor1, AcquisitionFailedActor2, AcquisitionFailedActor3)
    If candidate == None
        If AcquisitionDiagnostics && (AcquisitionScanCounter % 15) == 0
            Debug.Trace("[JM SSS][ACQ] scan #" + AcquisitionScanCounter + ": no eligible actor within " + AcquisitionRadius)
        EndIf
        RegisterForSingleUpdate(AcquisitionScanSeconds)
        Return
    EndIf

    Int aliasIndex = JM_RE_Native.ClassifySSSWhoringActor(candidate)
    If aliasIndex < 0
        Debug.Trace("[JM SSS][ACQ] classifier race: native-selected actor no longer eligible; actor=" + candidate)
        JM_RememberFailedActor(candidate)
        RegisterForSingleUpdate(AcquisitionRetrySeconds)
        Return
    EndIf

    ReferenceAlias approachAlias = JM_GetApproachAlias(aliasIndex)
    If approachAlias == None
        Debug.Trace("[JM SSS][ACQ] ERROR: SSS_Whoring alias " + aliasIndex + " is missing; actor=" + candidate)
        RegisterForSingleUpdate(AcquisitionRetrySeconds)
        Return
    EndIf

    ; Reserve acquisition before touching the alias.  This disables the four
    ; ambient idle INFOs temporarily so the old and new acquisition paths
    ; cannot select two different actors at the same time.
    JM_SetReady(False)

    approachAlias.Clear()
    approachAlias.ForceRefTo(candidate)

    If approachAlias.GetReference() != candidate
        Debug.Trace("[JM SSS][ACQ] ERROR: ForceRefTo verification failed for alias=" + aliasIndex + " actor=" + candidate)
        approachAlias.Clear()
        candidate.EvaluatePackage()
        AcquisitionFailureCounter += 1
        JM_RememberFailedActor(candidate)
        JM_SetReady(True)
        RegisterForSingleUpdate(AcquisitionRetrySeconds)
        Return
    EndIf

    AcquisitionPending = True
    AcquisitionActor = candidate
    AcquisitionAliasIndex = aliasIndex
    AcquisitionWaitTicks = 0

    candidate.EvaluatePackage()

    Debug.Trace("[JM SSS][ACQ] RESERVED actor=" + candidate + " alias=" + aliasIndex + " distance=" + candidate.GetDistance(PlayerRef) + " scan=" + AcquisitionScanCounter)
    RegisterForSingleUpdate(AcquisitionPendingPollSeconds)
EndFunction

Function JM_AbortAcquisition(String asReason, Float afRetry = 0.0)
    Actor actorRef = AcquisitionActor
    Int aliasIndex = AcquisitionAliasIndex

    If aliasIndex >= 0
        ReferenceAlias approachAlias = JM_GetApproachAlias(aliasIndex)
        If approachAlias != None && approachAlias.GetReference() == actorRef
            approachAlias.Clear()
        EndIf
    EndIf

    If actorRef != None
        actorRef.EvaluatePackage()
    EndIf

    AcquisitionFailureCounter += 1
    JM_RememberFailedActor(actorRef)
    Debug.Trace("[JM SSS][ACQ] ABORT actor=" + actorRef + " alias=" + aliasIndex + " reason=" + asReason + " failures=" + AcquisitionFailureCounter + " excludeScans=" + AcquisitionFailureExcludeScans)

    JM_ResetAcquisitionState(True)

    If NativeScannerAvailable && JM_IsReady() && !PredatorCombatActive
        If afRetry < 0.1
            afRetry = AcquisitionRetrySeconds
        EndIf
        RegisterForSingleUpdate(afRetry)
    EndIf
EndFunction

Function JM_FinalizeAcquisitionSuccess(String asSource)
    Debug.Trace("[JM SSS][ACQ] COMMITTED actor=" + AcquisitionActor + " alias=" + AcquisitionAliasIndex + " source=" + asSource + " waitTicks=" + AcquisitionWaitTicks)
    JM_ClearFailedActors()
    AcquisitionPending = False
    AcquisitionActor = None
    AcquisitionAliasIndex = -1
    AcquisitionWaitTicks = 0
EndFunction

Function JM_UpdatePendingAcquisition()
    If !AcquisitionPending
        JM_ScheduleAcquisitionIfReady(AcquisitionScanSeconds)
        Return
    EndIf

    Actor PlayerRef = Game.GetPlayer()
    Actor candidate = AcquisitionActor
    Int aliasIndex = AcquisitionAliasIndex
    Float now = Utility.GetCurrentGameTime()

    ; If an encounter committed through an existing fragment while we were
    ; waiting, accept it and stop touching the actor/package.
    If NextEligibleGameTime > now
        If CurrentEncounterActor == candidate
            JM_FinalizeAcquisitionSuccess("existing fragment")
        Else
            ReferenceAlias pendingAlias = JM_GetApproachAlias(aliasIndex)
            If pendingAlias != None && pendingAlias.GetReference() == candidate
                pendingAlias.Clear()
            EndIf
            Debug.Trace("[JM SSS][ACQ] another SSS encounter committed during native reservation; dropping pending actor=" + candidate)
            JM_ResetAcquisitionState(False)
        EndIf
        Return
    EndIf

    If candidate == None
        JM_AbortAcquisition("actor reference lost")
        Return
    EndIf

    If candidate.IsDead() || candidate.IsDisabled() || !candidate.Is3DLoaded()
        JM_AbortAcquisition("actor became dead/disabled/unloaded")
        Return
    EndIf

    Float distance = candidate.GetDistance(PlayerRef)
    If distance > (AcquisitionRadius + 1200.0)
        JM_AbortAcquisition("actor left acquisition radius; distance=" + distance)
        Return
    EndIf

    AcquisitionWaitTicks += 1

    ; This is the commit gate.  We do NOT consume the 20-hour cooldown merely
    ; because an alias was filled or a package started: the DLL verifies that
    ; this exact actor is currently speaking dialogue owned by SSS_Whoring.
    If JM_RE_Native.IsSSSWhoringDialogueActive(candidate)
        Debug.Trace("[JM SSS][ACQ] live SSS dialogue verified for actor=" + candidate + " alias=" + aliasIndex)
        BeginEncounter(candidate)
        ; BeginEncounter is the single commit point and finalizes the pending
        ; acquisition itself.  Do not finalize a second time here.
        Return
    EndIf

    Bool packageActive = JM_RE_Native.IsSSSWhoringPackageActive(candidate, aliasIndex)
    If packageActive
        If AcquisitionDiagnostics && (AcquisitionWaitTicks % 10) == 0
            Debug.Trace("[JM SSS][ACQ] approach package active; waiting for force-greet actor=" + candidate + " alias=" + aliasIndex + " distance=" + distance + " ticks=" + AcquisitionWaitTicks)
        EndIf
    ElseIf (AcquisitionWaitTicks % AcquisitionReevaluateEveryTicks) == 0
        ; A higher-priority AI package can briefly win, but bad candidates are
        ; rotated quickly instead of monopolizing acquisition for 30 seconds.
        candidate.EvaluatePackage()
        If AcquisitionDiagnostics
            Debug.Trace("[JM SSS][ACQ] force-greet package not active yet; re-evaluated actor=" + candidate + " alias=" + aliasIndex + " ticks=" + AcquisitionWaitTicks)
        EndIf
    EndIf

    If AcquisitionWaitTicks >= AcquisitionTimeoutTicks
        JM_AbortAcquisition("force-greet/dialogue timeout after " + AcquisitionWaitTicks + " ticks")
        Return
    EndIf

    RegisterForSingleUpdate(AcquisitionPendingPollSeconds)
EndFunction

Function BeginEncounter(Actor akSpeaker)
    If akSpeaker == None
        Debug.Trace("[JM SSS] ERROR: BeginEncounter called with None")
        Return
    EndIf

    JM_ResolveRuntimeForms()
    JM_RegisterEvents()

    Float now = Utility.GetCurrentGameTime()

    ; Multiple fragments/branches can touch the same SSS encounter.  Never
    ; reroll Major state or extend cooldown for the same committed approach.
    If NextEligibleGameTime > now
        If CurrentEncounterActor == akSpeaker
            If AcquisitionPending && AcquisitionActor == akSpeaker
                JM_FinalizeAcquisitionSuccess("duplicate fragment after commit")
            EndIf
            Debug.Trace("[JM SSS][ACQ] duplicate BeginEncounter ignored for actor=" + akSpeaker)
        Else
            Debug.Trace("[JM SSS][ACQ] BeginEncounter blocked by active cooldown; actor=" + akSpeaker + " current=" + CurrentEncounterActor)
        EndIf
        Return
    EndIf

    ; Extremely narrow race fallback: if legacy idle acquisition wins while a
    ; different native reservation is pending, release the native reservation
    ; and honor the real dialogue that actually fired.
    If AcquisitionPending && AcquisitionActor != akSpeaker
        Int oldAlias = AcquisitionAliasIndex
        ReferenceAlias oldRefAlias = JM_GetApproachAlias(oldAlias)
        If oldRefAlias != None && oldRefAlias.GetReference() == AcquisitionActor
            oldRefAlias.Clear()
        EndIf
        Debug.Trace("[JM SSS][ACQ] legacy idle path beat native reservation; oldActor=" + AcquisitionActor + " realSpeaker=" + akSpeaker)
        JM_ResetAcquisitionState(False)
    EndIf

    CurrentEncounterActor = akSpeaker
    BeginCooldown()
    CurrentEncounterMajor = JM_ShouldStartMajorEncounter()

    If AcquisitionPending && AcquisitionActor == akSpeaker
        JM_FinalizeAcquisitionSuccess("BeginEncounter")
    EndIf

    If CurrentEncounterMajor
        StorageUtil.SetIntValue(Game.GetPlayer(), "JM_SSS_MajorEncounter", 1)
        Debug.Trace("[JM SSS] Major encounter selected with " + akSpeaker)
        Debug.Notification("Something about her attention feels different this time.")

        ; Schedule the next ordinary Major window now. A combat win may replace this
        ; with the shorter retaliation window.
        Float hours = Utility.RandomFloat(MajorMinHours, MajorMaxHours)
        NextMajorEligibleGameTime = Utility.GetCurrentGameTime() + (hours / 24.0)
    Else
        StorageUtil.SetIntValue(Game.GetPlayer(), "JM_SSS_MajorEncounter", 0)
    EndIf

    Debug.Trace("[JM SSS][ACQ] encounter committed actor=" + akSpeaker + " major=" + CurrentEncounterMajor + " nextEligible=" + NextEligibleGameTime)
EndFunction

Bool Function JM_ShouldStartMajorEncounter()
    Float now = Utility.GetCurrentGameTime()

    JM_InitializeMajorClock()

    If now < NextMajorEligibleGameTime
        Return False
    EndIf

    If RetaliationPending
        Debug.Trace("[JM SSS] Retaliation makes this Major encounter guaranteed")
        RetaliationPending = False
        Return True
    EndIf

    Return Utility.RandomInt(1, 100) <= MajorChance
EndFunction

Function JM_InitializeMajorClock()
    If NextMajorEligibleGameTime <= 0.0
        Float hours = Utility.RandomFloat(MajorMinHours, MajorMaxHours)
        NextMajorEligibleGameTime = Utility.GetCurrentGameTime() + (hours / 24.0)
        Debug.Trace("[JM SSS] Initial Major encounter window begins at game time " + NextMajorEligibleGameTime)
    EndIf
EndFunction

Bool Function IsCurrentMajorEncounter()
    Return CurrentEncounterMajor
EndFunction

Actor Function GetCurrentPredator()
    Return CurrentPredator
EndFunction

Bool Function IsPredatorCombatActive()
    Return PredatorCombatActive && CurrentPredator != None
EndFunction

Function BeginCooldown()
    JM_ResolveRuntimeForms()
    If ReadyGlobal == None
        Debug.Trace("[JM SSS] ERROR: ReadyGlobal is not wired/resolvable")
        Return
    EndIf

    Float now = Utility.GetCurrentGameTime()

    ; A second branch of the same encounter must not extend the cooldown.
    If NextEligibleGameTime > now
        JM_SetReady(False)
        Return
    EndIf

    NextEligibleGameTime = now + (CooldownHours / 24.0)
    JM_SetReady(False)

    UnregisterForUpdateGameTime()
    RegisterForSingleUpdateGameTime(CooldownHours)
    Debug.Trace("[JM SSS][COOLDOWN] started; next eligible game time=" + NextEligibleGameTime)
EndFunction

Event OnUpdateGameTime()
    JM_ReconcileCooldown()
    JM_ScheduleAcquisitionIfReady(0.25)
EndEvent

Function JM_ReconcileCooldown()
    JM_ResolveRuntimeForms()
    If ReadyGlobal == None
        Debug.Trace("[JM SSS] ERROR: ReadyGlobal is not wired/resolvable")
        Return
    EndIf

    Float now = Utility.GetCurrentGameTime()
    If NextEligibleGameTime > now
        JM_SetReady(False)
        Float remainingHours = (NextEligibleGameTime - now) * 24.0
        If remainingHours < 0.1
            remainingHours = 0.1
        EndIf
        UnregisterForUpdateGameTime()
        RegisterForSingleUpdateGameTime(remainingHours)
        If AcquisitionDiagnostics
            Debug.Trace("[JM SSS][COOLDOWN] reconciled active; remainingHours=" + remainingHours)
        EndIf
    Else
        NextEligibleGameTime = 0.0
        JM_ClearFailedActors()
        If !AcquisitionPending && !PredatorCombatActive
            JM_SetReady(True)
        EndIf
        UnregisterForUpdateGameTime()
        Debug.Trace("[JM SSS][COOLDOWN] expired/ready")
    EndIf
EndFunction

Event OnUpdate()
    If PredatorCombatActive
        JM_UpdatePredatorCombat()
        Return
    EndIf

    If AcquisitionPending
        JM_UpdatePendingAcquisition()
    Else
        JM_RunAcquisitionScan()
    EndIf
EndEvent

Function StartPredatorCombat(Actor akPredator)
    If akPredator == None
        Debug.Trace("[JM SSS] ERROR: StartPredatorCombat called with None")
        Return
    EndIf

    Actor PlayerRef = Game.GetPlayer()

    If PredatorCombatActive
        If CurrentPredator == akPredator
            Return
        EndIf
        JM_CleanupPredatorCombat(False, False, "replaced by new predator")
    EndIf

    CurrentEncounterMajor = True
    StorageUtil.SetIntValue(PlayerRef, "JM_SSS_MajorEncounter", 1)

    CurrentPredator = akPredator
    CurrentEncounterActor = akPredator
    StorageUtil.SetFormValue(PlayerRef, "JM_SSS_CurrentPredator", akPredator)

    CurrentPredatorBase = akPredator.GetActorBase()
    If CurrentPredatorBase
        OriginalEssential = CurrentPredatorBase.IsEssential()
        If !OriginalEssential
            CurrentPredatorBase.SetEssential(True)
        EndIf
    EndIf

    OriginalRelationshipRank = akPredator.GetRelationshipRank(PlayerRef)
    OriginalGhost = akPredator.IsGhost()
    OriginalNoBleedoutRecovery = akPredator.GetNoBleedoutRecovery()

    ; Keep the Predator down once the player wins so the victory can be detected reliably.
    akPredator.SetNoBleedoutRecovery(True)

    AppliedSpeedBoost = PredatorSpeedBoost
    akPredator.ModActorValue("SpeedMult", AppliedSpeedBoost)

    ; This is temporary and restored during cleanup. It makes normally peaceful actors
    ; such as Ysolda commit to the fight instead of instantly dropping hostility.
    akPredator.SetRelationshipRank(PlayerRef, -4)

    PredatorCombatActive = True
    CombatQuietTicks = 0
    PlayerDefeatObserved = False

    If PredatorHitListenerSpell
        PredatorHitListenerSpell.Cast(PlayerRef, PlayerRef)
    Else
        Debug.Trace("[JM SSS] ERROR: PredatorHitListenerSpell is not wired")
    EndIf

    akPredator.EvaluatePackage()
    akPredator.StartCombat(PlayerRef)

    Debug.Notification("She lunges after you with terrifying speed.")
    Debug.Trace("[JM SSS] Predator combat START: " + akPredator)

    UnregisterForUpdate()
    RegisterForSingleUpdate(0.5)
EndFunction

Function JM_UpdatePredatorCombat()
    If !PredatorCombatActive
        Return
    EndIf

    Actor PlayerRef = Game.GetPlayer()
    Actor Predator = CurrentPredator

    If Predator == None
        JM_CleanupPredatorCombat(False, False, "predator reference lost")
        Return
    EndIf

    If Predator.IsBleedingOut()
        JM_PlayerWonPredatorFight()
        Return
    EndIf

    If PlayerRef.IsDead()
        JM_CleanupPredatorCombat(False, False, "player died")
        Return
    EndIf

    ; Simple Defeat makes its defeated actor ghost while it owns the transition.
    ; Do not interpret that temporary non-combat state as an escape.
    If PlayerRef.IsGhost()
        ; Simple Defeat uses a temporary player ghost state while it owns defeat.
        ; Remember that we observed a loss so a no-sex defeat path cannot later be
        ; mistaken for a successful escape.
        PlayerDefeatObserved = True
        CombatQuietTicks = 0
        RegisterForSingleUpdate(0.5)
        Return
    EndIf

    If PlayerRef.IsInCombat() || Predator.IsInCombat()
        CombatQuietTicks = 0
    Else
        CombatQuietTicks += 1
    EndIf

    ; A real escape is allowed, but it still humiliates the Predator and schedules retaliation.
    If !PlayerDefeatObserved && !PlayerRef.IsInCombat() && !Predator.IsInCombat() && Predator.GetDistance(PlayerRef) > 3000.0
        JM_PlayerEscapedPredator()
        Return
    EndIf

    ; Clean up stale combat if both actors remain out of combat for ~5 seconds.
    If CombatQuietTicks >= 10
        If PlayerDefeatObserved
            JM_CleanupPredatorCombat(False, False, "Simple Defeat observed without SexLab end")
        Else
            JM_PlayerEscapedPredator()
        EndIf
        Return
    EndIf

    RegisterForSingleUpdate(0.5)
EndFunction

Function ApplyPredatorHit(Actor akPlayer)
    If !PredatorCombatActive || CurrentPredator == None || akPlayer == None
        Return
    EndIf

    Float staminaNow = akPlayer.GetActorValue("Stamina")
    Float magickaNow = akPlayer.GetActorValue("Magicka")

    Float staminaTaken = PredatorStaminaDrain
    If staminaTaken > staminaNow
        staminaTaken = staminaNow
    EndIf
    If staminaTaken < 0.0
        staminaTaken = 0.0
    EndIf

    Float magickaTaken = PredatorMagickaDrain
    If magickaTaken > magickaNow
        magickaTaken = magickaNow
    EndIf
    If magickaTaken < 0.0
        magickaTaken = 0.0
    EndIf

    If staminaTaken > 0.0
        akPlayer.DamageActorValue("Stamina", staminaTaken)
    EndIf
    If magickaTaken > 0.0
        akPlayer.DamageActorValue("Magicka", magickaTaken)
    EndIf

    Float healAmount = (staminaTaken + magickaTaken) * PredatorHealFraction
    If healAmount > 0.0
        CurrentPredator.RestoreActorValue("Health", healAmount)
    EndIf

    Bool exhausted = akPlayer.GetActorValue("Stamina") <= 0.5
    If exhausted
        JM_UnequipPlayerWeapons(akPlayer, True)
        Debug.Notification("Your strength gives out and your weapon slips from your hands.")
    ElseIf Utility.RandomInt(1, 100) <= PredatorDisarmChance
        JM_UnequipPlayerWeapons(akPlayer, False)
        Debug.Notification("She knocks your weapon aside!")
    EndIf

    Debug.Trace("[JM SSS] Predator hit: Stamina -" + staminaTaken + ", Magicka -" + magickaTaken + ", Predator heal +" + healAmount)
EndFunction

Function JM_UnequipPlayerWeapons(Actor akPlayer, Bool abBothHands)
    If akPlayer == None
        Return
    EndIf

    Weapon rightWeapon = akPlayer.GetEquippedWeapon(False)
    Weapon leftWeapon = akPlayer.GetEquippedWeapon(True)

    If rightWeapon
        akPlayer.UnequipItem(rightWeapon, False, True)
    EndIf

    If abBothHands
        If leftWeapon && leftWeapon != rightWeapon
            akPlayer.UnequipItem(leftWeapon, False, True)
        EndIf
    ElseIf !rightWeapon && leftWeapon
        akPlayer.UnequipItem(leftWeapon, False, True)
    EndIf
EndFunction

Function JM_PlayerWonPredatorFight()
    Debug.Trace("[JM SSS] Player forced Predator into bleedout")
    Debug.Notification("She finally crumples, but the look she gives you promises this is not over.")
    JM_ScheduleRetaliation()
    JM_CleanupPredatorCombat(True, True, "predator bleedout")
EndFunction

Function JM_PlayerEscapedPredator()
    Debug.Trace("[JM SSS] Player escaped active Predator combat")
    Debug.Notification("You get away, but you doubt she will forget the humiliation.")
    JM_ScheduleRetaliation()
    JM_CleanupPredatorCombat(True, False, "player escaped")
EndFunction

Function JM_ScheduleRetaliation()
    RetaliationPending = True
    Float hours = Utility.RandomFloat(RetaliationMinHours, RetaliationMaxHours)
    NextMajorEligibleGameTime = Utility.GetCurrentGameTime() + (hours / 24.0)
    Debug.Trace("[JM SSS] Retaliation pending; eligible at game time " + NextMajorEligibleGameTime)
EndFunction

Function JM_CleanupPredatorCombat(Bool abPlayerWon, Bool abPredatorBleedingOut, String asReason)
    Actor PlayerRef = Game.GetPlayer()
    Actor Predator = CurrentPredator

    UnregisterForUpdate()

    If PredatorHitListenerSpell
        PlayerRef.DispelSpell(PredatorHitListenerSpell)
    EndIf

    StorageUtil.SetFormValue(PlayerRef, "JM_SSS_CurrentPredator", None)

    If Predator
        Predator.StopCombat()
        Predator.StopCombatAlarm()

        ; A bleedout victory gets a short ghost/recovery window so lingering poison/fire
        ; cannot turn a successful fight-off into a delayed kill.
        If abPredatorBleedingOut
            Predator.SetGhost(True)
            Utility.Wait(6.0)
            Predator.RestoreActorValue("Health", Predator.GetBaseActorValue("Health"))
        EndIf

        If AppliedSpeedBoost != 0.0
            Predator.ModActorValue("SpeedMult", -AppliedSpeedBoost)
        EndIf

        Predator.SetNoBleedoutRecovery(OriginalNoBleedoutRecovery)
        Predator.SetRelationshipRank(PlayerRef, OriginalRelationshipRank)

        If abPredatorBleedingOut
            Predator.SetGhost(OriginalGhost)
        EndIf

        Predator.EvaluatePackage()
    EndIf

    If CurrentPredatorBase && !OriginalEssential
        CurrentPredatorBase.SetEssential(False)
    EndIf

    PredatorCombatActive = False
    CurrentPredator = None
    CurrentPredatorBase = None
    AppliedSpeedBoost = 0.0
    CombatQuietTicks = 0
    PlayerDefeatObserved = False

    JM_ClearCurrentMajorEncounter()
    Debug.Trace("[JM SSS] Predator combat END (" + asReason + ")")
EndFunction

Function JM_ClearCurrentMajorEncounter()
    CurrentEncounterMajor = False
    CurrentEncounterActor = None
    StorageUtil.SetIntValue(Game.GetPlayer(), "JM_SSS_MajorEncounter", 0)
EndFunction

Event JM_OnAnimationEnd(Int tid, Bool HasPlayer)
    If !HasPlayer || !CurrentEncounterMajor
        Return
    EndIf

    If PredatorCombatActive
        ; Simple Defeat (or another defeat path) has finished the Major scene.
        JM_CleanupPredatorCombat(False, False, "major defeat scene ended")
    Else
        ; Major compliance completed normally.
        JM_ClearCurrentMajorEncounter()
    EndIf
EndEvent