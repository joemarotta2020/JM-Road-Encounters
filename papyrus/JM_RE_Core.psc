Scriptname JM_RE_Core extends Quest
{JM Road Encounters native-search encounter core.

Current build:
- normal encounter acquisition uses JM_RoadEncounters.dll, not dialogue idles
- DLL deterministically enumerates nearby high-process actors and returns nearest first
- Papyrus retains all PLRP/Hydra classification, cadence, cooldown, and encounter content
- scan cadence is performance-conscious and stops doing actor searches during the quiet window
- LIVE: Adventurer Rogue theft
- LIVE: Pilgrim alms
- LIVE: Refugee aid request
- LIVE: travelling Merchant barter
- LIVE: Wandering Magician healing service
- LIVE: Bounty Hunter shakedown
- LIVE: Vigilant inspection
- LIVE: Hydra caravan leader shakedown
- Sacred Band of Dibella remains observation-only

No NPC spawning or teleporting is used.
The failed Hello/idle records remain inert for existing-save safety but no longer acquire encounters.
}

; ===========================================================================
; NATIVE SEARCH SETTINGS
; ===========================================================================

Bool DebugMode = True
Bool DebugNotifications = False

; One native high-process actor enumeration per active scan.
Float ScanRadius = 3500.0
Int NativeScanMaxActors = 32

; No actor search occurs during the quiet window after a successful encounter.
Float QuietHours = 8.0
Float MediumPressureHours = 24.0
Float HighPressureHours = 48.0
Float GuaranteedEncounterHours = 60.0

; Scan frequency increases only as cadence pressure rises.
Float NormalScanIntervalSeconds = 12.0
Float MediumScanIntervalSeconds = 10.0
Float HighScanIntervalSeconds = 7.0
Float GuaranteedScanIntervalSeconds = 5.0
Float IneligibleStateRetrySeconds = 15.0

; Emergency fallback only if the native DLL did not register.
; This is deliberately much lighter than the old 24-sample/6-second scanner.
Float FallbackScanRadius = 2500.0
Int FallbackScanSamples = 8
Float FallbackScanIntervalSeconds = 15.0

; Legacy observer helpers below remain callable for diagnostics only.
Float BroadcastRadius = 2200.0
Float BroadcastCooldownHours = 1.0
Int ScanSamples = 24 ; dormant observer diagnostic only

; ===========================================================================
; ENCOUNTER GOVERNOR
; ===========================================================================

Bool GovernorEnabled = True

Bool LiveRogueEnabled = True
Bool LiveRefugeeEnabled = True
Bool LivePilgrimEnabled = True
Bool LiveVigilantEnabled = True
Bool LiveMerchantEnabled = True
Bool LiveMagicianEnabled = True
Bool LiveBountyHunterEnabled = True
Bool LiveHydraCaravanEnabled = True

Message Property PilgrimRequestMessage Auto
Message Property RefugeeRequestMessage Auto
Message Property MagicianServiceMessage Auto
Message Property BountyHunterMessage Auto
Message Property VigilantInspectionMessage Auto
Message Property HydraCaravanMessage Auto

Int PilgrimAlmsAmount = 25
Int RefugeeAidAmount = 20
Int MagicianServiceCost = 50
Int BountyHunterDemand = 75
Int HydraRoadFee = 100

; Observer eligibility stays in logs only.
Float EligibilityRadius = 1000.0
Float EligibilityCooldownHours = 1.0

; Validation build: the global governor is now the main anti-spam mechanism.
Float GlobalEncounterCooldownHours = 2.0
Float FailedOpportunityCooldownHours = 1.0

; Same category cannot repeatedly fire on every pass.
Float RogueEncounterCooldownHours = 12.0
Float RefugeeEncounterCooldownHours = 8.0
Float PilgrimEncounterCooldownHours = 8.0
Float VigilantEncounterCooldownHours = 12.0
Float MerchantEncounterCooldownHours = 6.0
Float MagicianEncounterCooldownHours = 8.0
Float BountyHunterEncounterCooldownHours = 12.0
Float HydraEncounterCooldownHours = 12.0

; Natural-contact distances. Actor must actually be nearby.
Float RogueOpportunityRadius = 650.0
Float RefugeeOpportunityRadius = 700.0
Float PilgrimOpportunityRadius = 550.0
Float VigilantOpportunityRadius = 550.0
Float MerchantOpportunityRadius = 500.0
Float MagicianOpportunityRadius = 650.0
Float BountyHunterOpportunityRadius = 450.0
Float HydraOpportunityRadius = 500.0

; ===========================================================================
; ROLE CODES
; ===========================================================================

Int ROLE_NONE = 0
Int ROLE_MERCHANT = 1
Int ROLE_MERCHANT_BODYGUARD = 2
Int ROLE_ASSASSIN = 3
Int ROLE_BOUNTY_HUNTER = 4
Int ROLE_WANDERING_MAGICIAN = 5
Int ROLE_WANDERING_KNIGHT = 6
Int ROLE_MERCENARY_WIZARD = 7
Int ROLE_MERCENARY_WARRIOR = 8
Int ROLE_MERCENARY_MISSILE = 9
Int ROLE_KNIGHT_OF_FAITH = 10
Int ROLE_PILGRIM = 11
Int ROLE_REFUGEE = 12
Int ROLE_ADVENTURER = 13
Int ROLE_VIGILANT = 14

Int CATEGORY_NONE = 0
Int CATEGORY_ROGUE = 1
Int CATEGORY_REFUGEE = 2
Int CATEGORY_PILGRIM = 3
Int CATEGORY_VIGILANT = 4
Int CATEGORY_MERCHANT = 5
Int CATEGORY_MAGICIAN = 6
Int CATEGORY_BOUNTY_HUNTER = 7
Int CATEGORY_HYDRA_CARAVAN = 8

; ===========================================================================
; RUNTIME
; ===========================================================================

Actor PlayerRef

Faction MerchantFaction
Faction MerchantBodyguardFaction
Faction AssassinFaction
Faction BountyHunterFaction
Faction WanderingMagicianFaction
Faction WanderingKnightFaction
Faction MercenaryWizardFaction
Faction MercenaryWarriorFaction
Faction MercenaryMissileFaction
Faction KnightOfFaithFaction
Faction PilgrimFaction
Faction RefugeeFaction
Faction AdventurerFaction

Bool ProviderLoaded = False

; Broadcast cooldowns are individual scalar fields deliberately.
; The previous Float[] field remained None when the script was replaced
; mid-game because OnInit does not rerun. Scalars safely default to 0.0.
Float LastMerchantBroadcastDay = 0.0
Float LastBodyguardBroadcastDay = 0.0
Float LastAssassinBroadcastDay = 0.0
Float LastBountyBroadcastDay = 0.0
Float LastMagicianBroadcastDay = 0.0
Float LastKnightBroadcastDay = 0.0
Float LastMercWizardBroadcastDay = 0.0
Float LastMercWarriorBroadcastDay = 0.0
Float LastMercMissileBroadcastDay = 0.0
Float LastFaithKnightBroadcastDay = 0.0
Float LastPilgrimBroadcastDay = 0.0
Float LastRefugeeBroadcastDay = 0.0
Float LastAdventurerBroadcastDay = 0.0
Float LastVigilantBroadcastDay = 0.0

; Governor state.
Float GlobalNextEncounterDay = 0.0
Float NextRogueRollDay = 0.0
Float NextRefugeeRollDay = 0.0
Float NextPilgrimRollDay = 0.0
Float NextVigilantRollDay = 0.0
Float NextMerchantRollDay = 0.0
Float NextMagicianRollDay = 0.0
Float NextBountyHunterRollDay = 0.0
Float NextHydraCaravanRollDay = 0.0

Bool HydraProviderLoaded = False

; Native scanner state. New scalars default safely on an existing save.
; HelloReadyGlobal is retained only to force the failed idle-dialog path OFF.
GlobalVariable HelloReadyGlobal
Bool NativeScannerInitialized = False
Bool NativeDetectorAvailable = False
Bool NativeDetectorChecked = False
; Cadence invariant:
; - HasSuccessfulEncounter remains False until CommitEncounter() succeeds.
; - LastSuccessfulEncounterDay is written only by CommitEncounter().
; - No initialization/load/migration path may manufacture a successful encounter time.
Float LastSuccessfulEncounterDay = 0.0
Bool HasSuccessfulEncounter = False
; Independent pressure anchor for the first encounter. This is NOT a success
; timestamp and may be initialized/migrated without violating the success-clock invariant.
Float PressureStartDay = 0.0
Int CadenceStateVersion = 0
Int NativeScanCounter = 0
Int SearchPulseCounter = 0
; Dedicated native cache slot for Road Encounters.
Int NativeScanClientId = 1

; ELIGIBLE-notice cooldowns. Scalars are safe for mid-game script upgrades.
Float LastEligibleMerchantDay = 0.0
Float LastEligibleAssassinDay = 0.0
Float LastEligibleBountyDay = 0.0
Float LastEligibleMagicianDay = 0.0
Float LastEligibleKnightDay = 0.0
Float LastEligibleMercenaryDay = 0.0
Float LastEligibleFaithDay = 0.0
Float LastEligibleRefugeeDay = 0.0
Float LastEligibleAdventurerDay = 0.0
Float LastEligibleVigilantDay = 0.0
Float LastEligibleHydraCaravanDay = 0.0
Float LastEligibleHydraSacredBandDay = 0.0
Float LastEligibleHydraSlaverDay = 0.0

Event OnInit()
	InitializeController()
EndEvent

Function InitializeController()
	InitializeNativeScanner(False)
EndFunction

Function EnsureRuntimeState()
	If PlayerRef == None
		PlayerRef = Game.GetPlayer()
	EndIf

	If !ProviderLoaded
		LoadPLRPProvider()
	EndIf

	If !HydraProviderLoaded
		HydraProviderLoaded = JM_RE_HydraProvider.IsInstalled()
	EndIf
EndFunction

Function LoadPLRPProvider()
	ProviderLoaded = JM_RE_PLRPProvider.IsInstalled()

	If !ProviderLoaded
		MerchantFaction = None
		MerchantBodyguardFaction = None
		AssassinFaction = None
		BountyHunterFaction = None
		WanderingMagicianFaction = None
		WanderingKnightFaction = None
		MercenaryWizardFaction = None
		MercenaryWarriorFaction = None
		MercenaryMissileFaction = None
		KnightOfFaithFaction = None
		PilgrimFaction = None
		RefugeeFaction = None
		AdventurerFaction = None
		Return
	EndIf

	MerchantFaction = JM_RE_PLRPProvider.GetMerchantFaction()
	MerchantBodyguardFaction = JM_RE_PLRPProvider.GetMerchantBodyguardFaction()
	AssassinFaction = JM_RE_PLRPProvider.GetAssassinFaction()
	BountyHunterFaction = JM_RE_PLRPProvider.GetBountyHunterFaction()
	WanderingMagicianFaction = JM_RE_PLRPProvider.GetWanderingMagicianFaction()
	WanderingKnightFaction = JM_RE_PLRPProvider.GetWanderingKnightFaction()
	MercenaryWizardFaction = JM_RE_PLRPProvider.GetMercenaryWizardFaction()
	MercenaryWarriorFaction = JM_RE_PLRPProvider.GetMercenaryWarriorFaction()
	MercenaryMissileFaction = JM_RE_PLRPProvider.GetMercenaryMissileFaction()
	KnightOfFaithFaction = JM_RE_PLRPProvider.GetKnightOfTheFaithFaction()
	PilgrimFaction = JM_RE_PLRPProvider.GetPilgrimFaction()
	RefugeeFaction = JM_RE_PLRPProvider.GetRefugeeFaction()
	AdventurerFaction = JM_RE_PLRPProvider.GetAdventurerFaction()
EndFunction

Function InitializeNativeScanner(Bool abExistingSaveMigration = False)
	; Retire any persisted scheduler registrations from earlier architectures.
	UnregisterForUpdate()
	UnregisterForUpdateGameTime()

	EnsureRuntimeState()
	ResolveHelloReadyGlobal()
	SetHelloReady(False)

	; Reconcile save state without ever fabricating a successful encounter timestamp.
	MigrateCadenceState()

	If abExistingSaveMigration && DebugMode
		Debug.Trace("[JM_RE][CADENCE] existing-save scanner migration completed without touching success clock.")
	EndIf

	NativeDetectorAvailable = JM_RE_Native.IsAvailable()
	NativeDetectorChecked = True
	NativeScannerInitialized = True

	If DebugMode
		Debug.Trace("[JM_RE][SCAN] native scanner initialized. dllAvailable=" + NativeDetectorAvailable + " migration=" + abExistingSaveMigration)
		If ProviderLoaded
			Debug.Trace("[JM_RE][SCAN] PLRP v3.2 provider loaded.")
		Else
			Debug.Trace("[JM_RE][SCAN] PLRP provider not available.")
		EndIf
		If !NativeDetectorAvailable
			Debug.Trace("[JM_RE][SCAN] WARNING: JM_RoadEncounters.dll native API unavailable; emergency Papyrus fallback enabled.")
		EndIf
	EndIf

	RegisterForSingleUpdate(1.0)
EndFunction

Function MigrateCadenceState()
	; v2 repaired the original fake-success timestamp deadlock.
	If CadenceStateVersion < 2
		Float legacyTimestamp = LastSuccessfulEncounterDay
		; IMPORTANT: do not write LastSuccessfulEncounterDay here.
		HasSuccessfulEncounter = False
		GlobalNextEncounterDay = 0.0
		NextRogueRollDay = 0.0
		NextRefugeeRollDay = 0.0
		NextPilgrimRollDay = 0.0
		NextVigilantRollDay = 0.0
		NextMerchantRollDay = 0.0
		NextMagicianRollDay = 0.0
		NextBountyHunterRollDay = 0.0
		NextHydraCaravanRollDay = 0.0
		CadenceStateVersion = 2
		If DebugMode
			LogCadenceDiagnostic("[JM_RE][CADENCE] MIGRATE v2 repaired legacy cadence. hasSuccess=False legacyTimestampIgnored=" + legacyTimestamp + " scannerEligible=TRUE")
		EndIf
	EndIf

	; v3 separates first-encounter pressure from the successful-encounter clock.
	If CadenceStateVersion < 3
		Float nowDay = Utility.GetCurrentGameTime()
		If !HasSuccessfulEncounter
			PressureStartDay = nowDay - (QuietHours / 24.0)
			GlobalNextEncounterDay = 0.0
			NextRogueRollDay = 0.0
			NextRefugeeRollDay = 0.0
			NextPilgrimRollDay = 0.0
			NextVigilantRollDay = 0.0
			NextMerchantRollDay = 0.0
			NextMagicianRollDay = 0.0
			NextBountyHunterRollDay = 0.0
			NextHydraCaravanRollDay = 0.0
		EndIf
		CadenceStateVersion = 3
		If DebugMode
			LogCadenceDiagnostic("[JM_RE][CADENCE] MIGRATE v3 pressureStartDay=" + PressureStartDay + " hasSuccess=" + HasSuccessfulEncounter + " pressureHours=" + GetHoursSinceSuccessfulEncounter())
		EndIf
	EndIf
EndFunction

Function NativeWakeScanner()
	; Called by JM_RoadEncounters.dll after a save finishes loading.
	; This makes scanner maintenance immediate on existing saves without a new alias.
	; Always run the versioned cadence repair, even when the scanner was already
	; initialized in the saved VM state.
	MigrateCadenceState()

	If !NativeScannerInitialized
		InitializeNativeScanner(True)
		Return
	EndIf

	UnregisterForUpdate()
	UnregisterForUpdateGameTime()
	EnsureRuntimeState()
	SetHelloReady(False)
	NativeDetectorAvailable = JM_RE_Native.IsAvailable()
	NativeDetectorChecked = True

	If DebugMode
		LogCadenceDiagnostic("[JM_RE][SCAN] post-load native wake. dllAvailable=" + NativeDetectorAvailable + " cadenceVersion=" + CadenceStateVersion + " hasSuccess=" + HasSuccessfulEncounter + " lastSuccessDay=" + LastSuccessfulEncounterDay + " pressureStartDay=" + PressureStartDay + " elapsedHours=" + GetHoursSinceSuccessfulEncounter())
	EndIf

	RegisterForSingleUpdate(1.0)
EndFunction

Function ResolveHelloReadyGlobal()
	If HelloReadyGlobal == None
		HelloReadyGlobal = Game.GetFormFromFile(0x00000807, "JM_RoadEncounters.esp") as GlobalVariable
	EndIf
EndFunction

Function SetHelloReady(Bool abReady)
	ResolveHelloReadyGlobal()
	If HelloReadyGlobal == None
		Return
	EndIf

	If abReady
		HelloReadyGlobal.SetValue(1.0)
	Else
		HelloReadyGlobal.SetValue(0.0)
	EndIf
EndFunction

Function LogCadenceDiagnostic(String asMessage)
	Debug.Trace(asMessage)
	If NativeDetectorAvailable
		JM_RE_Native.LogDiagnostic(asMessage)
	EndIf
EndFunction

Float Function GetHoursSinceSuccessfulEncounter()
	Float nowDay = Utility.GetCurrentGameTime()

	If !HasSuccessfulEncounter
		If PressureStartDay <= 0.0 || PressureStartDay > nowDay
			Return QuietHours
		EndIf
		Float pressureDays = nowDay - PressureStartDay
		If pressureDays < 0.0
			Return QuietHours
		EndIf
		Return pressureDays * 24.0
	EndIf

	If LastSuccessfulEncounterDay <= 0.0
		If DebugMode
			Debug.Trace("[JM_RE][CADENCE] ERROR hasSuccess=True but lastSuccessDay invalid; bypassing quiet window without rewriting clock.")
		EndIf
		Return QuietHours
	EndIf

	Float elapsedDays = nowDay - LastSuccessfulEncounterDay
	If elapsedDays < 0.0
		If DebugMode
			Debug.Trace("[JM_RE][CADENCE] WARNING current game time precedes last success; bypassing quiet window without rewriting clock.")
		EndIf
		Return QuietHours
	EndIf
	Return elapsedDays * 24.0
EndFunction

Event OnUpdateGameTime()
	; One legacy registration from the failed Hello build may still fire on an
	; existing save. Use it only as a migration wake-up; do not reschedule it.
	If !NativeScannerInitialized
		InitializeNativeScanner(True)
	EndIf
EndEvent

Event OnUpdate()
	; Existing saves may also arrive here through an old watchdog registration.
	If !NativeScannerInitialized
		InitializeNativeScanner(True)
		Return
	EndIf

	RunSearchPulse()
EndEvent

Function RunSearchPulse()
	EnsureRuntimeState()
	SetHelloReady(False)
	SearchPulseCounter += 1

	If !GovernorEnabled
		If DebugMode && (SearchPulseCounter % 20) == 0
			Debug.Trace("[JM_RE][SCAN] pulse #" + SearchPulseCounter + " skipped=governor-disabled dllAvailable=" + NativeDetectorAvailable)
		EndIf
		RegisterForSingleUpdate(IneligibleStateRetrySeconds)
		Return
	EndIf

	If !CanObserve()
		If DebugMode && (SearchPulseCounter % 20) == 0
			If PlayerRef != None
				Debug.Trace("[JM_RE][SCAN] pulse #" + SearchPulseCounter + " skipped=ineligible provider=" + ProviderLoaded + " dead=" + PlayerRef.IsDead() + " interior=" + PlayerRef.IsInInterior() + " combat=" + PlayerRef.IsInCombat() + " sleepState=" + PlayerRef.GetSleepState() + " dllAvailable=" + NativeDetectorAvailable)
			Else
				Debug.Trace("[JM_RE][SCAN] pulse #" + SearchPulseCounter + " skipped=ineligible reason=no-player-ref provider=" + ProviderLoaded + " dllAvailable=" + NativeDetectorAvailable)
			EndIf
		EndIf
		RegisterForSingleUpdate(IneligibleStateRetrySeconds)
		Return
	EndIf

	Float elapsedHours = GetHoursSinceSuccessfulEncounter()
	Float nextInterval = GetScanIntervalSeconds(elapsedHours)

	; Quiet suppression exists only after a real committed encounter.
	If HasSuccessfulEncounter && elapsedHours < QuietHours
		If DebugMode && (SearchPulseCounter % 20) == 0
			LogCadenceDiagnostic("[JM_RE][SCAN] pulse #" + SearchPulseCounter + " skipped=quiet-window hasSuccess=TRUE elapsedHours=" + elapsedHours + " quietHours=" + QuietHours + " lastSuccessDay=" + LastSuccessfulEncounterDay + " dllAvailable=" + NativeDetectorAvailable)
		EndIf
		RegisterForSingleUpdate(nextInterval)
		Return
	EndIf

	If DebugMode && !HasSuccessfulEncounter && (SearchPulseCounter % 20) == 0
		LogCadenceDiagnostic("[JM_RE][CADENCE] pulse #" + SearchPulseCounter + " history=NONE scannerEligible=TRUE elapsedHours=" + elapsedHours + " dllAvailable=" + NativeDetectorAvailable)
	EndIf

	If NativeDetectorAvailable
		; Never move a native-returned Actor[] through Papyrus.
		Int nearbyCount = JM_RE_Native.ScanNearbyActors(PlayerRef, ScanRadius, NativeScanMaxActors, NativeScanClientId)
		EvaluateNativeCandidateCache(nearbyCount, elapsedHours)
	Else
		RunFallbackSearch(elapsedHours)
		nextInterval = FallbackScanIntervalSeconds
	EndIf

	RegisterForSingleUpdate(nextInterval)
EndFunction

Float Function GetScanIntervalSeconds(Float afElapsedHours)
	If afElapsedHours >= GuaranteedEncounterHours
		Return GuaranteedScanIntervalSeconds
	ElseIf afElapsedHours >= HighPressureHours
		Return HighScanIntervalSeconds
	ElseIf afElapsedHours >= MediumPressureHours
		Return MediumScanIntervalSeconds
	EndIf

	Return NormalScanIntervalSeconds
EndFunction

Float Function GetCadenceOpportunityChance(Float afElapsedHours)
	If afElapsedHours >= GuaranteedEncounterHours
		Return 100.0
	ElseIf afElapsedHours >= HighPressureHours
		Return 50.0
	ElseIf afElapsedHours >= MediumPressureHours
		Return 25.0
	ElseIf afElapsedHours >= QuietHours
		Return 10.0
	EndIf

	Return 0.0
EndFunction

Float Function GetOpportunityRadiusForCategory(Int aiCategory)
	If aiCategory == CATEGORY_ROGUE
		Return RogueOpportunityRadius
	ElseIf aiCategory == CATEGORY_REFUGEE
		Return RefugeeOpportunityRadius
	ElseIf aiCategory == CATEGORY_PILGRIM
		Return PilgrimOpportunityRadius
	ElseIf aiCategory == CATEGORY_VIGILANT
		Return VigilantOpportunityRadius
	ElseIf aiCategory == CATEGORY_MERCHANT
		Return MerchantOpportunityRadius
	ElseIf aiCategory == CATEGORY_MAGICIAN
		Return MagicianOpportunityRadius
	ElseIf aiCategory == CATEGORY_BOUNTY_HUNTER
		Return BountyHunterOpportunityRadius
	ElseIf aiCategory == CATEGORY_HYDRA_CARAVAN
		Return HydraOpportunityRadius
	EndIf

	Return 0.0
EndFunction

Function EvaluateNativeCandidateCache(Int aiNearbyCount, Float afElapsedHours)
	NativeScanCounter += 1
	If aiNearbyCount <= 0
		If DebugMode && (NativeScanCounter % 10) == 0
			LogCadenceDiagnostic("[JM_RE][SCAN] cache scan: actors=0 elapsedHours=" + (afElapsedHours as Int))
		EndIf
		Return
	EndIf

	Float nowDay = Utility.GetCurrentGameTime()
	Int i = 0
	While i < aiNearbyCount
		Actor candidate = JM_RE_Native.GetScannedActor(NativeScanClientId, i)
		If IsUsableCandidate(candidate) && !candidate.IsInCombat()
			Int role = GetRoleCode(candidate)
			Int category = GetEncounterCategory(candidate)
			Float distance = candidate.GetDistance(PlayerRef)
			If category != CATEGORY_NONE
				Float allowedRadius = GetOpportunityRadiusForCategory(category)
				String gate = GetCategoryGateReason(category, nowDay)
				If gate == "eligible"
					If allowedRadius > 0.0 && distance > 0.0 && distance <= allowedRadius
						If DebugMode
							LogCadenceDiagnostic("[JM_RE][CANDIDATE] category=" + GetCategoryLabel(category) + " actor=" + candidate + " distance=" + (distance as Int) + " pressureHours=" + (afElapsedHours as Int) + " result=ROLL")
						EndIf
						RollCadenceOpportunity(category, candidate, distance, afElapsedHours, nowDay, "native-cache")
						Return
					ElseIf DebugMode && (NativeScanCounter % 10) == 0
						LogCadenceDiagnostic("[JM_RE][CANDIDATE] category=" + GetCategoryLabel(category) + " actor=" + candidate + " distance=" + (distance as Int) + " allowedRadius=" + (allowedRadius as Int) + " result=OUTSIDE-CONTACT")
					EndIf
				ElseIf DebugMode && (NativeScanCounter % 10) == 0
					LogCadenceDiagnostic("[JM_RE][CANDIDATE] category=" + GetCategoryLabel(category) + " actor=" + candidate + " distance=" + (distance as Int) + " result=BLOCKED reason=" + gate)
				EndIf
			ElseIf DebugMode && (NativeScanCounter % 10) == 0
				If role == ROLE_ADVENTURER
					Int advRole = JM_RE_PLRPProvider.GetAdventurerRole(candidate)
					LogCadenceDiagnostic("[JM_RE][OBSERVE] actor=" + candidate + " population=ADVENTURER subtype=" + advRole + " live=" + (advRole == 4))
				ElseIf HydraProviderLoaded && JM_RE_HydraProvider.IsSacredBand(candidate)
					LogCadenceDiagnostic("[JM_RE][OBSERVE] actor=" + candidate + " population=SACRED_BAND live=FALSE reason=observation-only")
				EndIf
			EndIf
		EndIf
		i += 1
	EndWhile

	If DebugMode && (NativeScanCounter % 10) == 0
		LogCadenceDiagnostic("[JM_RE][SCAN] cache scan: actors=" + aiNearbyCount + " result=no-live-opportunity pressureHours=" + (afElapsedHours as Int))
	EndIf
EndFunction

String Function GetCategoryGateReason(Int aiCategory, Float afNowDay)
	If !GovernorEnabled
		Return "governor-disabled"
	EndIf
	If aiCategory == CATEGORY_NONE
		Return "not-live-category"
	EndIf
	If afNowDay < GlobalNextEncounterDay
		Return "global-cooldown"
	EndIf
	If aiCategory == CATEGORY_ROGUE
		If !LiveRogueEnabled
			Return "category-disabled"
		ElseIf afNowDay < NextRogueRollDay
			Return "category-cooldown"
		EndIf
	ElseIf aiCategory == CATEGORY_REFUGEE
		If !LiveRefugeeEnabled
			Return "category-disabled"
		ElseIf RefugeeRequestMessage == None
			Return "message-missing"
		ElseIf afNowDay < NextRefugeeRollDay
			Return "category-cooldown"
		EndIf
	ElseIf aiCategory == CATEGORY_PILGRIM
		If !LivePilgrimEnabled
			Return "category-disabled"
		ElseIf PilgrimRequestMessage == None
			Return "message-missing"
		ElseIf afNowDay < NextPilgrimRollDay
			Return "category-cooldown"
		EndIf
	ElseIf aiCategory == CATEGORY_VIGILANT
		If !LiveVigilantEnabled
			Return "category-disabled"
		ElseIf VigilantInspectionMessage == None
			Return "message-missing"
		ElseIf afNowDay < NextVigilantRollDay
			Return "category-cooldown"
		EndIf
	ElseIf aiCategory == CATEGORY_MERCHANT
		If !LiveMerchantEnabled
			Return "category-disabled"
		ElseIf afNowDay < NextMerchantRollDay
			Return "category-cooldown"
		EndIf
	ElseIf aiCategory == CATEGORY_MAGICIAN
		If !LiveMagicianEnabled
			Return "category-disabled"
		ElseIf MagicianServiceMessage == None
			Return "message-missing"
		ElseIf afNowDay < NextMagicianRollDay
			Return "category-cooldown"
		EndIf
	ElseIf aiCategory == CATEGORY_BOUNTY_HUNTER
		If !LiveBountyHunterEnabled
			Return "category-disabled"
		ElseIf BountyHunterMessage == None
			Return "message-missing"
		ElseIf afNowDay < NextBountyHunterRollDay
			Return "category-cooldown"
		EndIf
	ElseIf aiCategory == CATEGORY_HYDRA_CARAVAN
		If !LiveHydraCaravanEnabled
			Return "category-disabled"
		ElseIf HydraCaravanMessage == None
			Return "message-missing"
		ElseIf afNowDay < NextHydraCaravanRollDay
			Return "category-cooldown"
		EndIf
	Else
		Return "unknown-category"
	EndIf
	Return "eligible"
EndFunction

Function RunFallbackSearch(Float afElapsedHours)
	Float nowDay = Utility.GetCurrentGameTime()
	Actor bestActor
	Int bestCategory = CATEGORY_NONE
	Float bestDistance = 0.0
	Int i = 0

	While i < FallbackScanSamples
		Actor candidate = Game.FindRandomActorFromRef(PlayerRef, FallbackScanRadius)
		If IsUsableCandidate(candidate) && !candidate.IsInCombat()
			Int category = GetEncounterCategory(candidate)
			If CanCommitCategory(category, nowDay)
				Float distance = candidate.GetDistance(PlayerRef)
				Float allowedRadius = GetOpportunityRadiusForCategory(category)
				If allowedRadius > 0.0 && distance > 0.0 && distance <= allowedRadius
					If bestActor == None || distance < bestDistance
						bestActor = candidate
						bestCategory = category
						bestDistance = distance
					EndIf
				EndIf
			EndIf
		EndIf
		i += 1
	EndWhile

	If bestActor != None
		RollCadenceOpportunity(bestCategory, bestActor, bestDistance, afElapsedHours, nowDay, "fallback")
	ElseIf DebugMode
		Debug.Trace("[JM_RE][SCAN] fallback scan found no eligible actor.")
	EndIf
EndFunction

Function RollCadenceOpportunity(Int aiCategory, Actor akActor, Float afDistance, Float afElapsedHours, Float afNowDay, String asSource)
	Float chance = GetCadenceOpportunityChance(afElapsedHours)
	If chance <= 0.0
		Return
	EndIf

	Float roll = Utility.RandomFloat(0.0, 100.0)
	If roll <= chance
		If DebugMode
			Debug.Trace("[JM_RE][SCAN] TRIGGER source=" + asSource + " category=" + GetCategoryLabel(aiCategory) + " distance=" + (afDistance as Int) + " elapsedHours=" + (afElapsedHours as Int) + " chance=" + (chance as Int) + " roll=" + (roll as Int))
		EndIf
		CommitEncounter(aiCategory, akActor, afDistance, afNowDay, asSource)
	Else
		SetFailedRollCooldown(aiCategory, afNowDay)
		If DebugMode
			Debug.Trace("[JM_RE][SCAN] roll failed source=" + asSource + " category=" + GetCategoryLabel(aiCategory) + " distance=" + (afDistance as Int) + " elapsedHours=" + (afElapsedHours as Int) + " chance=" + (chance as Int) + " roll=" + (roll as Int) + " retryHours=" + (FailedOpportunityCooldownHours as Int))
		EndIf
	EndIf
EndFunction

Function HandleHelloCandidate(Actor akSpeaker)
	; Retained only because existing INFO fragments may still call it on an
	; existing save. The Hello/idle path is intentionally retired.
	SetHelloReady(False)
	If DebugMode
		Debug.Trace("[JM_RE][HELLO] retired Hello fragment ignored actor=" + akSpeaker)
	EndIf
EndFunction

Int Function GetEncounterCategory(Actor akActor)
	If akActor == None
		Return CATEGORY_NONE
	EndIf

	Int role = GetRoleCode(akActor)

	If role == ROLE_BOUNTY_HUNTER
		Return CATEGORY_BOUNTY_HUNTER
	ElseIf role == ROLE_WANDERING_MAGICIAN
		Return CATEGORY_MAGICIAN
	ElseIf role == ROLE_PILGRIM
		Return CATEGORY_PILGRIM
	ElseIf role == ROLE_REFUGEE
		Return CATEGORY_REFUGEE
	ElseIf role == ROLE_MERCHANT
		Return CATEGORY_MERCHANT
	ElseIf role == ROLE_VIGILANT
		Return CATEGORY_VIGILANT
	ElseIf role == ROLE_ADVENTURER
		If JM_RE_PLRPProvider.GetAdventurerRole(akActor) == 4
			Return CATEGORY_ROGUE
		EndIf
	EndIf

	If HydraProviderLoaded
		If JM_RE_HydraProvider.GetCaravanRole(akActor) == 1
			Return CATEGORY_HYDRA_CARAVAN
		EndIf
	EndIf

	Return CATEGORY_NONE
EndFunction

Bool Function CanCommitCategory(Int aiCategory, Float afNowDay)
	Return GetCategoryGateReason(aiCategory, afNowDay) == "eligible"
EndFunction

Bool Function CommitEncounter(Int aiCategory, Actor akActor, Float afDistance, Float afNowDay, String asSource)
	If akActor == None || aiCategory == CATEGORY_NONE
		Return False
	EndIf

	Bool started = False
	If aiCategory == CATEGORY_ROGUE
		started = ResolveRogueEncounter(akActor, afDistance)
	ElseIf aiCategory == CATEGORY_REFUGEE
		started = ResolveRefugeeEncounter(akActor, afDistance)
	ElseIf aiCategory == CATEGORY_PILGRIM
		started = ResolvePilgrimEncounter(akActor, afDistance)
	ElseIf aiCategory == CATEGORY_VIGILANT
		started = ResolveVigilantEncounter(akActor, afDistance)
	ElseIf aiCategory == CATEGORY_MERCHANT
		started = ResolveMerchantEncounter(akActor, afDistance)
	ElseIf aiCategory == CATEGORY_MAGICIAN
		started = ResolveMagicianEncounter(akActor, afDistance)
	ElseIf aiCategory == CATEGORY_BOUNTY_HUNTER
		started = ResolveBountyHunterEncounter(akActor, afDistance)
	ElseIf aiCategory == CATEGORY_HYDRA_CARAVAN
		started = ResolveHydraCaravanEncounter(akActor, afDistance)
	EndIf

	If !started
		SetFailedRollCooldown(aiCategory, afNowDay)
		If DebugMode
			LogCadenceDiagnostic("[JM_RE][DIRECTOR] ABORT source=" + asSource + " category=" + GetCategoryLabel(aiCategory) + " actor=" + akActor + " reason=resolver-did-not-start")
		EndIf
		Return False
	EndIf

	Float oldSuccessDay = LastSuccessfulEncounterDay
	LastSuccessfulEncounterDay = afNowDay
	HasSuccessfulEncounter = True
	GlobalNextEncounterDay = afNowDay + (GlobalEncounterCooldownHours / 24.0)
	SetCategorySuccessCooldown(aiCategory, afNowDay, GetCategorySuccessCooldownHours(aiCategory))
	If DebugMode
		LogCadenceDiagnostic("[JM_RE][CLOCK] LastSuccessfulEncounterDay old=" + oldSuccessDay + " new=" + LastSuccessfulEncounterDay + " reason=SUCCESSFUL_COMMIT category=" + GetCategoryLabel(aiCategory) + " actor=" + akActor)
		LogCadenceDiagnostic("[JM_RE][DIRECTOR] COMMIT source=" + asSource + " category=" + GetCategoryLabel(aiCategory) + " actor=" + akActor + " distance=" + (afDistance as Int))
	EndIf
	Return True
EndFunction

Bool Function CanObserve()
	If PlayerRef == None
		Return False
	EndIf

	If !ProviderLoaded
		Return False
	EndIf

	If PlayerRef.IsDead()
		Return False
	EndIf

	If PlayerRef.IsInInterior()
		Return False
	EndIf

	If PlayerRef.IsInCombat()
		Return False
	EndIf

	If PlayerRef.GetSleepState() != 0
		Return False
	EndIf

	Return True
EndFunction

Function ObserveNearbyPopulation()
	Int merchantCount = 0
	Int bodyguardCount = 0
	Int assassinCount = 0
	Int bountyHunterCount = 0
	Int magicianCount = 0
	Int knightCount = 0
	Int mercWizardCount = 0
	Int mercWarriorCount = 0
	Int mercMissileCount = 0
	Int faithKnightCount = 0
	Int pilgrimCount = 0
	Int refugeeCount = 0
	Int adventurerCount = 0
	Int vigilantCount = 0

	Int hydraLeaderCount = 0
	Int hydraGuardCount = 0
	Int hydraSlaveCount = 0
	Int hydraSacredBandCount = 0
	Int hydraOtherSlaverCount = 0
	Float hydraCaravanNearest = 0.0
	Float hydraSacredBandNearest = 0.0
	Float hydraSlaverNearest = 0.0

	Int advLeaderCount = 0
	Int advWarriorCount = 0
	Int advArcherCount = 0
	Int advRogueCount = 0
	Int advWizardCount = 0
	Int advSoloCount = 0
	Int advUnknownCount = 0

	Float merchantNearest = 0.0
	Float faithNearest = 0.0
	Float refugeeNearest = 0.0
	Float adventurerNearest = 0.0
	Float vigilantNearest = 0.0
	Float mercNearest = 0.0
	Float assassinNearest = 0.0
	Float bountyNearest = 0.0
	Float knightNearest = 0.0
	Float magicianNearest = 0.0

	Actor nearestRogue
	Float nearestRogueDistance = 0.0
	Actor nearestRefugee
	Float nearestRefugeeDistance = 0.0
	Actor nearestPilgrim
	Float nearestPilgrimDistance = 0.0
	Actor nearestVigilant
	Float nearestVigilantDistance = 0.0
	Actor nearestMerchant
	Float nearestMerchantDistance = 0.0
	Actor nearestMagician
	Float nearestMagicianDistance = 0.0
	Actor nearestBountyHunter
	Float nearestBountyHunterDistance = 0.0
	Actor nearestHydraLeader
	Float nearestHydraLeaderDistance = 0.0

	Actor[] seen = New Actor[32]
	Int seenCount = 0
	Int i = 0
	Actor candidate
	Int role
	Int advRole
	Int hydraRole
	Float distance

	While i < ScanSamples
		candidate = Game.FindRandomActorFromRef(PlayerRef, ScanRadius)

		If IsUsableCandidate(candidate)
			If !ActorAlreadySeen(candidate, seen, seenCount)
				If seenCount < seen.Length
					seen[seenCount] = candidate
					seenCount += 1
				EndIf

				role = GetRoleCode(candidate)
				distance = candidate.GetDistance(PlayerRef)

				If role == ROLE_MERCHANT
					merchantCount += 1
					merchantNearest = MinDistance(merchantNearest, distance)

					If nearestMerchant == None || distance < nearestMerchantDistance
						nearestMerchant = candidate
						nearestMerchantDistance = distance
					EndIf

				ElseIf role == ROLE_MERCHANT_BODYGUARD
					bodyguardCount += 1
					merchantNearest = MinDistance(merchantNearest, distance)

				ElseIf role == ROLE_ASSASSIN
					assassinCount += 1
					assassinNearest = MinDistance(assassinNearest, distance)

				ElseIf role == ROLE_BOUNTY_HUNTER
					bountyHunterCount += 1
					bountyNearest = MinDistance(bountyNearest, distance)

					If nearestBountyHunter == None || distance < nearestBountyHunterDistance
						nearestBountyHunter = candidate
						nearestBountyHunterDistance = distance
					EndIf

				ElseIf role == ROLE_WANDERING_MAGICIAN
					magicianCount += 1
					magicianNearest = MinDistance(magicianNearest, distance)

					If nearestMagician == None || distance < nearestMagicianDistance
						nearestMagician = candidate
						nearestMagicianDistance = distance
					EndIf

				ElseIf role == ROLE_WANDERING_KNIGHT
					knightCount += 1
					knightNearest = MinDistance(knightNearest, distance)

				ElseIf role == ROLE_MERCENARY_WIZARD
					mercWizardCount += 1
					mercNearest = MinDistance(mercNearest, distance)

				ElseIf role == ROLE_MERCENARY_WARRIOR
					mercWarriorCount += 1
					mercNearest = MinDistance(mercNearest, distance)

				ElseIf role == ROLE_MERCENARY_MISSILE
					mercMissileCount += 1
					mercNearest = MinDistance(mercNearest, distance)

				ElseIf role == ROLE_KNIGHT_OF_FAITH
					faithKnightCount += 1
					faithNearest = MinDistance(faithNearest, distance)

				ElseIf role == ROLE_PILGRIM
					pilgrimCount += 1
					faithNearest = MinDistance(faithNearest, distance)

					If nearestPilgrim == None || distance < nearestPilgrimDistance
						nearestPilgrim = candidate
						nearestPilgrimDistance = distance
					EndIf

				ElseIf role == ROLE_REFUGEE
					refugeeCount += 1
					refugeeNearest = MinDistance(refugeeNearest, distance)

					If nearestRefugee == None || distance < nearestRefugeeDistance
						nearestRefugee = candidate
						nearestRefugeeDistance = distance
					EndIf

				ElseIf role == ROLE_ADVENTURER
					adventurerCount += 1
					adventurerNearest = MinDistance(adventurerNearest, distance)
					advRole = JM_RE_PLRPProvider.GetAdventurerRole(candidate)

					If advRole == 1
						advLeaderCount += 1

					ElseIf advRole == 2
						advWarriorCount += 1

					ElseIf advRole == 3
						advArcherCount += 1

					ElseIf advRole == 4
						advRogueCount += 1

						If nearestRogue == None || distance < nearestRogueDistance
							nearestRogue = candidate
							nearestRogueDistance = distance
						EndIf

					ElseIf advRole == 5
						advWizardCount += 1

					ElseIf advRole == 6
						advSoloCount += 1

					Else
						advUnknownCount += 1
					EndIf

				ElseIf role == ROLE_VIGILANT
					vigilantCount += 1
					vigilantNearest = MinDistance(vigilantNearest, distance)

					If nearestVigilant == None || distance < nearestVigilantDistance
						nearestVigilant = candidate
						nearestVigilantDistance = distance
					EndIf
				EndIf

				If HydraProviderLoaded
					hydraRole = JM_RE_HydraProvider.GetCaravanRole(candidate)

					If hydraRole == 1
						hydraLeaderCount += 1
						hydraCaravanNearest = MinDistance(hydraCaravanNearest, distance)

						If nearestHydraLeader == None || distance < nearestHydraLeaderDistance
							nearestHydraLeader = candidate
							nearestHydraLeaderDistance = distance
						EndIf

					ElseIf hydraRole == 2
						hydraGuardCount += 1
						hydraCaravanNearest = MinDistance(hydraCaravanNearest, distance)

					ElseIf hydraRole == 3
						hydraSlaveCount += 1
						hydraCaravanNearest = MinDistance(hydraCaravanNearest, distance)

					ElseIf JM_RE_HydraProvider.IsSacredBand(candidate)
						hydraSacredBandCount += 1
						hydraSacredBandNearest = MinDistance(hydraSacredBandNearest, distance)

					ElseIf JM_RE_HydraProvider.IsOtherSlaver(candidate)
						hydraOtherSlaverCount += 1
						hydraSlaverNearest = MinDistance(hydraSlaverNearest, distance)
					EndIf
				EndIf
			EndIf
		EndIf
		i += 1
	EndWhile

	ReportObservations(merchantCount, bodyguardCount, merchantNearest, faithKnightCount, pilgrimCount, faithNearest, refugeeCount, refugeeNearest, adventurerCount, adventurerNearest, advLeaderCount, advWarriorCount, advArcherCount, advRogueCount, advWizardCount, advSoloCount, advUnknownCount, vigilantCount, vigilantNearest, mercWarriorCount, mercMissileCount, mercWizardCount, mercNearest, assassinCount, assassinNearest, bountyHunterCount, bountyNearest, knightCount, knightNearest, magicianCount, magicianNearest)

	ReportHydraObservations(hydraLeaderCount, hydraGuardCount, hydraSlaveCount, hydraCaravanNearest, hydraSacredBandCount, hydraSacredBandNearest, hydraOtherSlaverCount, hydraSlaverNearest)

	ReportEligiblePopulations(merchantCount, merchantNearest, assassinCount, assassinNearest, bountyHunterCount, bountyNearest, magicianCount, magicianNearest, knightCount, knightNearest, mercWarriorCount + mercMissileCount + mercWizardCount, mercNearest, faithKnightCount + pilgrimCount, faithNearest, refugeeCount, refugeeNearest, adventurerCount, adventurerNearest, vigilantCount, vigilantNearest, hydraLeaderCount + hydraGuardCount + hydraSlaveCount, hydraCaravanNearest, hydraSacredBandCount, hydraSacredBandNearest, hydraOtherSlaverCount, hydraSlaverNearest)

	EvaluateEncounterGovernor(nearestRogue, nearestRogueDistance, nearestRefugee, nearestRefugeeDistance, nearestPilgrim, nearestPilgrimDistance, nearestVigilant, nearestVigilantDistance, nearestMerchant, nearestMerchantDistance, nearestMagician, nearestMagicianDistance, nearestBountyHunter, nearestBountyHunterDistance, nearestHydraLeader, nearestHydraLeaderDistance)
EndFunction

Float Function MinDistance(Float afCurrent, Float afCandidate)
	If afCurrent <= 0.0
		Return afCandidate
	EndIf

	If afCandidate < afCurrent
		Return afCandidate
	EndIf

	Return afCurrent
EndFunction

Bool Function IsUsableCandidate(Actor akActor)
	If akActor == None
		Return False
	EndIf

	If akActor == PlayerRef
		Return False
	EndIf

	If akActor.IsDead()
		Return False
	EndIf

	If !akActor.Is3DLoaded()
		Return False
	EndIf

	Return True
EndFunction

Bool Function ActorAlreadySeen(Actor akActor, Actor[] akSeen, Int aiSeenCount)
	Int i = 0

	While i < aiSeenCount
		If akSeen[i] == akActor
			Return True
		EndIf

		i += 1
	EndWhile

	Return False
EndFunction

Int Function GetRoleCode(Actor akActor)
	If akActor == None
		Return ROLE_NONE
	EndIf

	If MerchantFaction && akActor.IsInFaction(MerchantFaction)
		Return ROLE_MERCHANT
	EndIf

	If MerchantBodyguardFaction && akActor.IsInFaction(MerchantBodyguardFaction)
		Return ROLE_MERCHANT_BODYGUARD
	EndIf

	If AssassinFaction && akActor.IsInFaction(AssassinFaction)
		Return ROLE_ASSASSIN
	EndIf

	If BountyHunterFaction && akActor.IsInFaction(BountyHunterFaction)
		Return ROLE_BOUNTY_HUNTER
	EndIf

	If WanderingMagicianFaction && akActor.IsInFaction(WanderingMagicianFaction)
		Return ROLE_WANDERING_MAGICIAN
	EndIf

	If WanderingKnightFaction && akActor.IsInFaction(WanderingKnightFaction)
		Return ROLE_WANDERING_KNIGHT
	EndIf

	If MercenaryWizardFaction && akActor.IsInFaction(MercenaryWizardFaction)
		Return ROLE_MERCENARY_WIZARD
	EndIf

	If MercenaryWarriorFaction && akActor.IsInFaction(MercenaryWarriorFaction)
		Return ROLE_MERCENARY_WARRIOR
	EndIf

	If MercenaryMissileFaction && akActor.IsInFaction(MercenaryMissileFaction)
		Return ROLE_MERCENARY_MISSILE
	EndIf

	If KnightOfFaithFaction && akActor.IsInFaction(KnightOfFaithFaction)
		Return ROLE_KNIGHT_OF_FAITH
	EndIf

	If PilgrimFaction && akActor.IsInFaction(PilgrimFaction)
		Return ROLE_PILGRIM
	EndIf

	If RefugeeFaction && akActor.IsInFaction(RefugeeFaction)
		Return ROLE_REFUGEE
	EndIf

	If AdventurerFaction && akActor.IsInFaction(AdventurerFaction)
		Return ROLE_ADVENTURER
	EndIf

	If JM_RE_PLRPProvider.IsVigilant(akActor)
		Return ROLE_VIGILANT
	EndIf

	Return ROLE_NONE
EndFunction

; ===========================================================================
; BROADCAST COOLDOWN - SCALAR VERSION
; ===========================================================================

Float Function GetLastBroadcastDay(Int aiRole)
	If aiRole == ROLE_MERCHANT
		Return LastMerchantBroadcastDay
	ElseIf aiRole == ROLE_MERCHANT_BODYGUARD
		Return LastBodyguardBroadcastDay
	ElseIf aiRole == ROLE_ASSASSIN
		Return LastAssassinBroadcastDay
	ElseIf aiRole == ROLE_BOUNTY_HUNTER
		Return LastBountyBroadcastDay
	ElseIf aiRole == ROLE_WANDERING_MAGICIAN
		Return LastMagicianBroadcastDay
	ElseIf aiRole == ROLE_WANDERING_KNIGHT
		Return LastKnightBroadcastDay
	ElseIf aiRole == ROLE_MERCENARY_WIZARD
		Return LastMercWizardBroadcastDay
	ElseIf aiRole == ROLE_MERCENARY_WARRIOR
		Return LastMercWarriorBroadcastDay
	ElseIf aiRole == ROLE_MERCENARY_MISSILE
		Return LastMercMissileBroadcastDay
	ElseIf aiRole == ROLE_KNIGHT_OF_FAITH
		Return LastFaithKnightBroadcastDay
	ElseIf aiRole == ROLE_PILGRIM
		Return LastPilgrimBroadcastDay
	ElseIf aiRole == ROLE_REFUGEE
		Return LastRefugeeBroadcastDay
	ElseIf aiRole == ROLE_ADVENTURER
		Return LastAdventurerBroadcastDay
	ElseIf aiRole == ROLE_VIGILANT
		Return LastVigilantBroadcastDay
	EndIf

	Return 0.0
EndFunction

Bool Function CanBroadcast(Int aiRole)
	Float lastDay = GetLastBroadcastDay(aiRole)

	If lastDay <= 0.0
		Return True
	EndIf

	Return Utility.GetCurrentGameTime() >= (lastDay + (BroadcastCooldownHours / 24.0))
EndFunction

Function MarkBroadcast(Int aiRole)
	Float nowDay = Utility.GetCurrentGameTime()

	If aiRole == ROLE_MERCHANT
		LastMerchantBroadcastDay = nowDay
	ElseIf aiRole == ROLE_MERCHANT_BODYGUARD
		LastBodyguardBroadcastDay = nowDay
	ElseIf aiRole == ROLE_ASSASSIN
		LastAssassinBroadcastDay = nowDay
	ElseIf aiRole == ROLE_BOUNTY_HUNTER
		LastBountyBroadcastDay = nowDay
	ElseIf aiRole == ROLE_WANDERING_MAGICIAN
		LastMagicianBroadcastDay = nowDay
	ElseIf aiRole == ROLE_WANDERING_KNIGHT
		LastKnightBroadcastDay = nowDay
	ElseIf aiRole == ROLE_MERCENARY_WIZARD
		LastMercWizardBroadcastDay = nowDay
	ElseIf aiRole == ROLE_MERCENARY_WARRIOR
		LastMercWarriorBroadcastDay = nowDay
	ElseIf aiRole == ROLE_MERCENARY_MISSILE
		LastMercMissileBroadcastDay = nowDay
	ElseIf aiRole == ROLE_KNIGHT_OF_FAITH
		LastFaithKnightBroadcastDay = nowDay
	ElseIf aiRole == ROLE_PILGRIM
		LastPilgrimBroadcastDay = nowDay
	ElseIf aiRole == ROLE_REFUGEE
		LastRefugeeBroadcastDay = nowDay
	ElseIf aiRole == ROLE_ADVENTURER
		LastAdventurerBroadcastDay = nowDay
	ElseIf aiRole == ROLE_VIGILANT
		LastVigilantBroadcastDay = nowDay
	EndIf
EndFunction

; ===========================================================================
; ENCOUNTER GOVERNOR
; ===========================================================================

Function EvaluateEncounterGovernor(Actor akRogue, Float afRogueDistance, Actor akRefugee, Float afRefugeeDistance, Actor akPilgrim, Float afPilgrimDistance, Actor akVigilant, Float afVigilantDistance, Actor akMerchant, Float afMerchantDistance, Actor akMagician, Float afMagicianDistance, Actor akBountyHunter, Float afBountyHunterDistance, Actor akHydraLeader, Float afHydraDistance)
	Float nowDay
	Int category

	If !GovernorEnabled
		Return
	EndIf

	If PlayerRef == None
		Return
	EndIf

	nowDay = Utility.GetCurrentGameTime()

	If nowDay < GlobalNextEncounterDay
		Return
	EndIf

	category = ChooseClosestEligibleOpportunity(akRogue, afRogueDistance, akRefugee, afRefugeeDistance, akPilgrim, afPilgrimDistance, akVigilant, afVigilantDistance, akMerchant, afMerchantDistance, akMagician, afMagicianDistance, akBountyHunter, afBountyHunterDistance, akHydraLeader, afHydraDistance, nowDay)

	If category == CATEGORY_ROGUE
		RollOpportunity(CATEGORY_ROGUE, akRogue, afRogueDistance, nowDay)
	ElseIf category == CATEGORY_REFUGEE
		RollOpportunity(CATEGORY_REFUGEE, akRefugee, afRefugeeDistance, nowDay)
	ElseIf category == CATEGORY_PILGRIM
		RollOpportunity(CATEGORY_PILGRIM, akPilgrim, afPilgrimDistance, nowDay)
	ElseIf category == CATEGORY_VIGILANT
		RollOpportunity(CATEGORY_VIGILANT, akVigilant, afVigilantDistance, nowDay)
	ElseIf category == CATEGORY_MERCHANT
		RollOpportunity(CATEGORY_MERCHANT, akMerchant, afMerchantDistance, nowDay)
	ElseIf category == CATEGORY_MAGICIAN
		RollOpportunity(CATEGORY_MAGICIAN, akMagician, afMagicianDistance, nowDay)
	ElseIf category == CATEGORY_BOUNTY_HUNTER
		RollOpportunity(CATEGORY_BOUNTY_HUNTER, akBountyHunter, afBountyHunterDistance, nowDay)
	ElseIf category == CATEGORY_HYDRA_CARAVAN
		RollOpportunity(CATEGORY_HYDRA_CARAVAN, akHydraLeader, afHydraDistance, nowDay)
	EndIf
EndFunction

Int Function ChooseClosestEligibleOpportunity(Actor akRogue, Float afRogueDistance, Actor akRefugee, Float afRefugeeDistance, Actor akPilgrim, Float afPilgrimDistance, Actor akVigilant, Float afVigilantDistance, Actor akMerchant, Float afMerchantDistance, Actor akMagician, Float afMagicianDistance, Actor akBountyHunter, Float afBountyHunterDistance, Actor akHydraLeader, Float afHydraDistance, Float afNowDay)
	Int chosenCategory = CATEGORY_NONE
	Float chosenDistance = 0.0

	If IsOpportunityEligible(akRogue, afRogueDistance, RogueOpportunityRadius, afNowDay, NextRogueRollDay)
		chosenCategory = CATEGORY_ROGUE
		chosenDistance = afRogueDistance
	EndIf

	If IsOpportunityEligible(akRefugee, afRefugeeDistance, RefugeeOpportunityRadius, afNowDay, NextRefugeeRollDay)
		If chosenCategory == CATEGORY_NONE || afRefugeeDistance < chosenDistance
			chosenCategory = CATEGORY_REFUGEE
			chosenDistance = afRefugeeDistance
		EndIf
	EndIf

	If IsOpportunityEligible(akPilgrim, afPilgrimDistance, PilgrimOpportunityRadius, afNowDay, NextPilgrimRollDay)
		If chosenCategory == CATEGORY_NONE || afPilgrimDistance < chosenDistance
			chosenCategory = CATEGORY_PILGRIM
			chosenDistance = afPilgrimDistance
		EndIf
	EndIf

	If IsOpportunityEligible(akVigilant, afVigilantDistance, VigilantOpportunityRadius, afNowDay, NextVigilantRollDay)
		If chosenCategory == CATEGORY_NONE || afVigilantDistance < chosenDistance
			chosenCategory = CATEGORY_VIGILANT
			chosenDistance = afVigilantDistance
		EndIf
	EndIf

	If IsOpportunityEligible(akMerchant, afMerchantDistance, MerchantOpportunityRadius, afNowDay, NextMerchantRollDay)
		If chosenCategory == CATEGORY_NONE || afMerchantDistance < chosenDistance
			chosenCategory = CATEGORY_MERCHANT
			chosenDistance = afMerchantDistance
		EndIf
	EndIf

	If IsOpportunityEligible(akMagician, afMagicianDistance, MagicianOpportunityRadius, afNowDay, NextMagicianRollDay)
		If chosenCategory == CATEGORY_NONE || afMagicianDistance < chosenDistance
			chosenCategory = CATEGORY_MAGICIAN
			chosenDistance = afMagicianDistance
		EndIf
	EndIf

	If IsOpportunityEligible(akBountyHunter, afBountyHunterDistance, BountyHunterOpportunityRadius, afNowDay, NextBountyHunterRollDay)
		If chosenCategory == CATEGORY_NONE || afBountyHunterDistance < chosenDistance
			chosenCategory = CATEGORY_BOUNTY_HUNTER
			chosenDistance = afBountyHunterDistance
		EndIf
	EndIf

	If IsOpportunityEligible(akHydraLeader, afHydraDistance, HydraOpportunityRadius, afNowDay, NextHydraCaravanRollDay)
		If chosenCategory == CATEGORY_NONE || afHydraDistance < chosenDistance
			chosenCategory = CATEGORY_HYDRA_CARAVAN
			chosenDistance = afHydraDistance
		EndIf
	EndIf

	Return chosenCategory
EndFunction

Bool Function IsOpportunityEligible(Actor akActor, Float afDistance, Float afRadius, Float afNowDay, Float afNextDay)
	If akActor == None
		Return False
	EndIf

	If afDistance <= 0.0 || afDistance > afRadius
		Return False
	EndIf

	If afNowDay < afNextDay
		Return False
	EndIf

	Return True
EndFunction

Function RollOpportunity(Int aiCategory, Actor akActor, Float afDistance, Float afNowDay)
	Float chance = GetOpportunityChance(aiCategory, afDistance)
	Float roll = Utility.RandomFloat(0.0, 100.0)

	If roll <= chance
		HandleTriggeredOpportunity(aiCategory, akActor, afDistance, roll, chance, afNowDay)
	Else
		SetFailedRollCooldown(aiCategory, afNowDay)

		If DebugMode
			Debug.Trace("[JM_RE][GOVERNOR] roll failed category=" + GetCategoryLabel(aiCategory) + " distance=" + (afDistance as Int) + " roll=" + (roll as Int) + " chance=" + (chance as Int))
		EndIf
	EndIf
EndFunction

Float Function GetOpportunityChance(Int aiCategory, Float afDistance)
	; Legacy governor compatibility. Active scanning uses GetCadenceOpportunityChance.
	Return GetCadenceOpportunityChance(GetHoursSinceSuccessfulEncounter())
EndFunction

Function SetFailedRollCooldown(Int aiCategory, Float afNowDay)
	Float nextDay = afNowDay + (FailedOpportunityCooldownHours / 24.0)

	If aiCategory == CATEGORY_ROGUE
		NextRogueRollDay = nextDay
	ElseIf aiCategory == CATEGORY_REFUGEE
		NextRefugeeRollDay = nextDay
	ElseIf aiCategory == CATEGORY_PILGRIM
		NextPilgrimRollDay = nextDay
	ElseIf aiCategory == CATEGORY_VIGILANT
		NextVigilantRollDay = nextDay
	ElseIf aiCategory == CATEGORY_MERCHANT
		NextMerchantRollDay = nextDay
	ElseIf aiCategory == CATEGORY_MAGICIAN
		NextMagicianRollDay = nextDay
	ElseIf aiCategory == CATEGORY_BOUNTY_HUNTER
		NextBountyHunterRollDay = nextDay
	ElseIf aiCategory == CATEGORY_HYDRA_CARAVAN
		NextHydraCaravanRollDay = nextDay
	EndIf
EndFunction

Function HandleTriggeredOpportunity(Int aiCategory, Actor akActor, Float afDistance, Float afRoll, Float afChance, Float afNowDay)
	Bool committed = CommitEncounter(aiCategory, akActor, afDistance, afNowDay, "legacy-governor")
	If DebugMode
		Debug.Trace("[JM_RE][GOVERNOR] TRIGGER category=" + GetCategoryLabel(aiCategory) + " distance=" + (afDistance as Int) + " roll=" + (afRoll as Int) + " chance=" + (afChance as Int) + " committed=" + committed)
	EndIf
EndFunction

Function SetCategorySuccessCooldown(Int aiCategory, Float afNowDay, Float afHours)
	Float nextDay = afNowDay + (afHours / 24.0)

	If aiCategory == CATEGORY_ROGUE
		NextRogueRollDay = nextDay
	ElseIf aiCategory == CATEGORY_REFUGEE
		NextRefugeeRollDay = nextDay
	ElseIf aiCategory == CATEGORY_PILGRIM
		NextPilgrimRollDay = nextDay
	ElseIf aiCategory == CATEGORY_VIGILANT
		NextVigilantRollDay = nextDay
	ElseIf aiCategory == CATEGORY_MERCHANT
		NextMerchantRollDay = nextDay
	ElseIf aiCategory == CATEGORY_MAGICIAN
		NextMagicianRollDay = nextDay
	ElseIf aiCategory == CATEGORY_BOUNTY_HUNTER
		NextBountyHunterRollDay = nextDay
	ElseIf aiCategory == CATEGORY_HYDRA_CARAVAN
		NextHydraCaravanRollDay = nextDay
	EndIf
EndFunction

Bool Function ResolvePilgrimEncounter(Actor akPilgrim, Float afDistance)
	If PilgrimRequestMessage == None
		Debug.Trace("[JM_RE][PILGRIM] ERROR: PilgrimRequestMessage property is None.")
		Return False
	EndIf

	Int choice = PilgrimRequestMessage.Show()
	MiscObject goldForm = Game.GetForm(0x0000000F) as MiscObject
	Int playerGold = PlayerRef.GetItemCount(goldForm)

	If choice == 0
		If playerGold >= PilgrimAlmsAmount
			PlayerRef.RemoveItem(goldForm, PilgrimAlmsAmount, True)
			Debug.Notification("You give the pilgrim " + PilgrimAlmsAmount + " gold.")
			Debug.Trace("[JM_RE][PILGRIM] DONATED gold=" + PilgrimAlmsAmount + " distance=" + (afDistance as Int))
		Else
			Debug.Notification("You do not have enough gold.")
			Debug.Trace("[JM_RE][PILGRIM] COULD_NOT_PAY")
		EndIf
	Else
		Debug.Notification("You decline the pilgrim's request.")
		Debug.Trace("[JM_RE][PILGRIM] DECLINED")
	EndIf
	Return True
EndFunction

Bool Function ResolveRefugeeEncounter(Actor akRefugee, Float afDistance)
	If RefugeeRequestMessage == None
		Debug.Trace("[JM_RE][REFUGEE] ERROR: RefugeeRequestMessage property is None.")
		Return False
	EndIf

	Int choice = RefugeeRequestMessage.Show()
	MiscObject goldForm = Game.GetForm(0x0000000F) as MiscObject
	Int playerGold = PlayerRef.GetItemCount(goldForm)

	If choice == 0
		If playerGold >= RefugeeAidAmount
			PlayerRef.RemoveItem(goldForm, RefugeeAidAmount, True)
			Debug.Notification("You give the refugee " + RefugeeAidAmount + " gold.")
			Debug.Trace("[JM_RE][REFUGEE] AIDED gold=" + RefugeeAidAmount + " distance=" + (afDistance as Int))
		Else
			Debug.Notification("You do not have enough gold.")
			Debug.Trace("[JM_RE][REFUGEE] COULD_NOT_PAY")
		EndIf
	Else
		Debug.Notification("You leave the refugee to continue alone.")
		Debug.Trace("[JM_RE][REFUGEE] DECLINED")
	EndIf
	Return True
EndFunction

Bool Function ResolveMerchantEncounter(Actor akMerchant, Float afDistance)
	If akMerchant == None
		Return False
	EndIf

	Debug.Notification("A travelling merchant offers to trade.")
	Debug.Trace("[JM_RE][MERCHANT] BARTER distance=" + (afDistance as Int))
	akMerchant.ShowBarterMenu()
	Return True
EndFunction

Bool Function ResolveMagicianEncounter(Actor akMagician, Float afDistance)
	If MagicianServiceMessage == None
		Debug.Trace("[JM_RE][MAGICIAN] ERROR: MagicianServiceMessage property is None.")
		Return False
	EndIf

	Int choice = MagicianServiceMessage.Show()
	MiscObject goldForm = Game.GetForm(0x0000000F) as MiscObject
	Int playerGold = PlayerRef.GetItemCount(goldForm)

	If choice == 0
		If playerGold >= MagicianServiceCost
			PlayerRef.RemoveItem(goldForm, MagicianServiceCost, True)
			PlayerRef.RestoreActorValue("Health", 150.0)
			PlayerRef.RestoreActorValue("Stamina", 100.0)
			PlayerRef.RestoreActorValue("Magicka", 100.0)
			Debug.Notification("The magician restores your strength.")
			Debug.Trace("[JM_RE][MAGICIAN] SERVICE_PAID gold=" + MagicianServiceCost + " distance=" + (afDistance as Int))
		Else
			Debug.Notification("You cannot afford the magician's fee.")
			Debug.Trace("[JM_RE][MAGICIAN] COULD_NOT_PAY")
		EndIf
	Else
		Debug.Notification("You decline the magician's offer.")
		Debug.Trace("[JM_RE][MAGICIAN] DECLINED")
	EndIf
	Return True
EndFunction

Bool Function ResolveBountyHunterEncounter(Actor akHunter, Float afDistance)
	If akHunter == None || BountyHunterMessage == None
		Return False
	EndIf

	Int choice = BountyHunterMessage.Show()
	MiscObject goldForm = Game.GetForm(0x0000000F) as MiscObject
	Int playerGold = PlayerRef.GetItemCount(goldForm)

	If choice == 0
		If playerGold >= BountyHunterDemand
			PlayerRef.RemoveItem(goldForm, BountyHunterDemand, True)
			Debug.Notification("The bounty hunter pockets the gold and lets you pass.")
			Debug.Trace("[JM_RE][BOUNTY] PAID gold=" + BountyHunterDemand + " distance=" + (afDistance as Int))
		Else
			Debug.Notification("You cannot meet the bounty hunter's demand.")
			Debug.Trace("[JM_RE][BOUNTY] CANNOT_PAY_COMBAT")
			akHunter.StartCombat(PlayerRef)
		EndIf
	Else
		Debug.Notification("The bounty hunter reaches for a weapon.")
		Debug.Trace("[JM_RE][BOUNTY] REFUSED_COMBAT distance=" + (afDistance as Int))
		akHunter.StartCombat(PlayerRef)
	EndIf
	Return True
EndFunction

Bool Function ResolveVigilantEncounter(Actor akVigilant, Float afDistance)
	If akVigilant == None || VigilantInspectionMessage == None
		Return False
	EndIf

	Int choice = VigilantInspectionMessage.Show()

	If choice == 0
		Form skoomaForm = Game.GetForm(0x00057A7A)
		Int skoomaCount = PlayerRef.GetItemCount(skoomaForm)

		If skoomaCount > 0
			PlayerRef.RemoveItem(skoomaForm, skoomaCount, True)
			Debug.Notification("The Vigilant confiscates your skooma.")
			Debug.Trace("[JM_RE][VIGILANT] CONFISCATED_SKOOMA count=" + skoomaCount + " distance=" + (afDistance as Int))
		Else
			Debug.Notification("The Vigilant finds nothing of immediate concern.")
			Debug.Trace("[JM_RE][VIGILANT] INSPECTION_CLEAR distance=" + (afDistance as Int))
		EndIf
	Else
		Debug.Notification("The Vigilant takes your refusal as a challenge.")
		Debug.Trace("[JM_RE][VIGILANT] REFUSED_COMBAT distance=" + (afDistance as Int))
		akVigilant.StartCombat(PlayerRef)
	EndIf
	Return True
EndFunction

Bool Function ResolveHydraCaravanEncounter(Actor akLeader, Float afDistance)
	If akLeader == None || HydraCaravanMessage == None
		Return False
	EndIf

	Int choice = HydraCaravanMessage.Show()
	MiscObject goldForm = Game.GetForm(0x0000000F) as MiscObject
	Int playerGold = PlayerRef.GetItemCount(goldForm)

	If choice == 0
		If playerGold >= HydraRoadFee
			PlayerRef.RemoveItem(goldForm, HydraRoadFee, True)
			Debug.Notification("The slaver takes the road fee and waves you on.")
			Debug.Trace("[JM_RE][HYDRA] ROAD_FEE_PAID gold=" + HydraRoadFee + " distance=" + (afDistance as Int))
		Else
			Debug.Notification("You cannot pay the slaver's demand.")
			Debug.Trace("[JM_RE][HYDRA] CANNOT_PAY_COMBAT")
			akLeader.StartCombat(PlayerRef)
		EndIf
	Else
		Debug.Notification("The slaver decides to take payment by force.")
		Debug.Trace("[JM_RE][HYDRA] REFUSED_COMBAT distance=" + (afDistance as Int))
		akLeader.StartCombat(PlayerRef)
	EndIf
	Return True
EndFunction

Bool Function ResolveRogueEncounter(Actor akRogue, Float afDistance)
	If akRogue == None
		Return False
	EndIf

	MiscObject goldForm = Game.GetForm(0x0000000F) as MiscObject
	If goldForm == None
		Return False
	EndIf

	Int playerGold = PlayerRef.GetItemCount(goldForm)
	If playerGold <= 0
		Debug.Notification("An adventurer rogue checks your empty coin purse and moves on.")
		Debug.Trace("[JM_RE][ROGUE] NO_GOLD distance=" + (afDistance as Int))
		Return True
	EndIf

	Float rogueSkill = akRogue.GetActorValue("Pickpocket")
	Float playerSkill = PlayerRef.GetActorValue("Pickpocket")
	Float successChance = 58.0 + ((rogueSkill - playerSkill) * 0.25)

	If PlayerRef.HasLOS(akRogue)
		successChance -= 18.0
	EndIf

	If PlayerRef.IsSneaking()
		successChance -= 10.0
	EndIf

	If afDistance <= 175.0
		successChance += 8.0
	ElseIf afDistance >= 450.0
		successChance -= 8.0
	EndIf

	If successChance < 20.0
		successChance = 20.0
	ElseIf successChance > 85.0
		successChance = 85.0
	EndIf

	Float theftRoll = Utility.RandomFloat(0.0, 100.0)

	If theftRoll <= successChance
		Int amount = playerGold / 10

		If amount < 10
			amount = 10
		ElseIf amount > 75
			amount = 75
		EndIf

		If amount > playerGold
			amount = playerGold
		EndIf

		PlayerRef.RemoveItem(goldForm, amount, True)
		Debug.Notification("Your coin purse feels lighter. (-" + amount + " gold)")
		Debug.Trace("[JM_RE][ROGUE] THEFT_SUCCESS amount=" + amount + " distance=" + (afDistance as Int) + " chance=" + (successChance as Int) + " roll=" + (theftRoll as Int))
	Else
		Debug.Notification("You catch the adventurer rogue reaching for your coin purse.")
		Debug.Trace("[JM_RE][ROGUE] THEFT_CAUGHT distance=" + (afDistance as Int) + " chance=" + (successChance as Int) + " roll=" + (theftRoll as Int))
	EndIf
	Return True
EndFunction

Float Function GetCategorySuccessCooldownHours(Int aiCategory)
	If aiCategory == CATEGORY_ROGUE
		Return RogueEncounterCooldownHours
	ElseIf aiCategory == CATEGORY_REFUGEE
		Return RefugeeEncounterCooldownHours
	ElseIf aiCategory == CATEGORY_PILGRIM
		Return PilgrimEncounterCooldownHours
	ElseIf aiCategory == CATEGORY_VIGILANT
		Return VigilantEncounterCooldownHours
	ElseIf aiCategory == CATEGORY_MERCHANT
		Return MerchantEncounterCooldownHours
	ElseIf aiCategory == CATEGORY_MAGICIAN
		Return MagicianEncounterCooldownHours
	ElseIf aiCategory == CATEGORY_BOUNTY_HUNTER
		Return BountyHunterEncounterCooldownHours
	ElseIf aiCategory == CATEGORY_HYDRA_CARAVAN
		Return HydraEncounterCooldownHours
	EndIf

	Return 12.0
EndFunction

String Function GetCategoryLabel(Int aiCategory)
	If aiCategory == CATEGORY_ROGUE
		Return "Adventurer Rogue"
	ElseIf aiCategory == CATEGORY_REFUGEE
		Return "Refugee"
	ElseIf aiCategory == CATEGORY_PILGRIM
		Return "Pilgrim"
	ElseIf aiCategory == CATEGORY_VIGILANT
		Return "Vigilant"
	ElseIf aiCategory == CATEGORY_MERCHANT
		Return "Merchant"
	ElseIf aiCategory == CATEGORY_MAGICIAN
		Return "Wandering Magician"
	ElseIf aiCategory == CATEGORY_BOUNTY_HUNTER
		Return "Bounty Hunter"
	ElseIf aiCategory == CATEGORY_HYDRA_CARAVAN
		Return "Hydra Caravan"
	EndIf

	Return "Unknown"
EndFunction

; ===========================================================================
; FULL ELIGIBILITY OBSERVATION
; ===========================================================================

Bool Function EligibleCooldownReady(Float afLastDay)
	If afLastDay <= 0.0
		Return True
	EndIf

	Return Utility.GetCurrentGameTime() >= (afLastDay + (EligibilityCooldownHours / 24.0))
EndFunction

Bool Function EligibleContact(Int aiCount, Float afNearest)
	Return aiCount > 0 && afNearest > 0.0 && afNearest <= EligibilityRadius
EndFunction

Function TraceEligible(String asLabel, Int aiCount, Float afNearest)
	Debug.Trace("[JM_RE][ELIGIBLE] " + asLabel + " count=" + aiCount + " nearest=" + (afNearest as Int))

	If DebugNotifications
		Debug.Notification("JM RE TEST: ELIGIBLE - " + asLabel + " (" + (afNearest as Int) + ")")
	EndIf
EndFunction

Function ReportEligiblePopulations(Int aiMerchant, Float afMerchantNearest, Int aiAssassin, Float afAssassinNearest, Int aiBounty, Float afBountyNearest, Int aiMagician, Float afMagicianNearest, Int aiKnight, Float afKnightNearest, Int aiMercenary, Float afMercNearest, Int aiFaith, Float afFaithNearest, Int aiRefugee, Float afRefugeeNearest, Int aiAdventurer, Float afAdventurerNearest, Int aiVigilant, Float afVigilantNearest, Int aiHydraCaravan, Float afHydraCaravanNearest, Int aiHydraSacredBand, Float afHydraSacredBandNearest, Int aiHydraSlaver, Float afHydraSlaverNearest)
	Float nowDay = Utility.GetCurrentGameTime()

	; One HUD eligibility message per scan. The category is then suppressed for
	; one game hour so subsequent scans can expose other nearby populations.

	If EligibleContact(aiHydraCaravan, afHydraCaravanNearest) && EligibleCooldownReady(LastEligibleHydraCaravanDay)
		TraceEligible("Hydra caravan", aiHydraCaravan, afHydraCaravanNearest)
		LastEligibleHydraCaravanDay = nowDay
		Return
	EndIf

	If EligibleContact(aiHydraSacredBand, afHydraSacredBandNearest) && EligibleCooldownReady(LastEligibleHydraSacredBandDay)
		TraceEligible("Hydra Sacred Band", aiHydraSacredBand, afHydraSacredBandNearest)
		LastEligibleHydraSacredBandDay = nowDay
		Return
	EndIf

	If EligibleContact(aiHydraSlaver, afHydraSlaverNearest) && EligibleCooldownReady(LastEligibleHydraSlaverDay)
		TraceEligible("Hydra slaver", aiHydraSlaver, afHydraSlaverNearest)
		LastEligibleHydraSlaverDay = nowDay
		Return
	EndIf

	If EligibleContact(aiAdventurer, afAdventurerNearest) && EligibleCooldownReady(LastEligibleAdventurerDay)
		TraceEligible("Adventurer", aiAdventurer, afAdventurerNearest)
		LastEligibleAdventurerDay = nowDay
		Return
	EndIf

	If EligibleContact(aiRefugee, afRefugeeNearest) && EligibleCooldownReady(LastEligibleRefugeeDay)
		TraceEligible("Refugee", aiRefugee, afRefugeeNearest)
		LastEligibleRefugeeDay = nowDay
		Return
	EndIf

	If EligibleContact(aiFaith, afFaithNearest) && EligibleCooldownReady(LastEligibleFaithDay)
		TraceEligible("Pilgrim / faith group", aiFaith, afFaithNearest)
		LastEligibleFaithDay = nowDay
		Return
	EndIf

	If EligibleContact(aiVigilant, afVigilantNearest) && EligibleCooldownReady(LastEligibleVigilantDay)
		TraceEligible("Vigilant", aiVigilant, afVigilantNearest)
		LastEligibleVigilantDay = nowDay
		Return
	EndIf

	If EligibleContact(aiMerchant, afMerchantNearest) && EligibleCooldownReady(LastEligibleMerchantDay)
		TraceEligible("Merchant group", aiMerchant, afMerchantNearest)
		LastEligibleMerchantDay = nowDay
		Return
	EndIf

	If EligibleContact(aiMercenary, afMercNearest) && EligibleCooldownReady(LastEligibleMercenaryDay)
		TraceEligible("Mercenary", aiMercenary, afMercNearest)
		LastEligibleMercenaryDay = nowDay
		Return
	EndIf

	If EligibleContact(aiKnight, afKnightNearest) && EligibleCooldownReady(LastEligibleKnightDay)
		TraceEligible("Wandering knight", aiKnight, afKnightNearest)
		LastEligibleKnightDay = nowDay
		Return
	EndIf

	If EligibleContact(aiMagician, afMagicianNearest) && EligibleCooldownReady(LastEligibleMagicianDay)
		TraceEligible("Wandering magician", aiMagician, afMagicianNearest)
		LastEligibleMagicianDay = nowDay
		Return
	EndIf

	If EligibleContact(aiAssassin, afAssassinNearest) && EligibleCooldownReady(LastEligibleAssassinDay)
		TraceEligible("Assassin", aiAssassin, afAssassinNearest)
		LastEligibleAssassinDay = nowDay
		Return
	EndIf

	If EligibleContact(aiBounty, afBountyNearest) && EligibleCooldownReady(LastEligibleBountyDay)
		TraceEligible("Bounty hunter", aiBounty, afBountyNearest)
		LastEligibleBountyDay = nowDay
	EndIf
EndFunction

Function ReportHydraObservations(Int aiLeader, Int aiGuard, Int aiSlave, Float afCaravanNearest, Int aiSacredBand, Float afSacredBandNearest, Int aiOtherSlaver, Float afSlaverNearest)
	If !HydraProviderLoaded
		Return
	EndIf

	If DebugMode
		If aiLeader > 0 || aiGuard > 0 || aiSlave > 0
			Debug.Trace("[JM_RE][OBSERVE][HYDRA] Caravan leader=" + aiLeader + " guard=" + aiGuard + " slave=" + aiSlave + " nearest=" + (afCaravanNearest as Int))
		EndIf

		If aiSacredBand > 0
			Debug.Trace("[JM_RE][OBSERVE][HYDRA] Sacred Band=" + aiSacredBand + " nearest=" + (afSacredBandNearest as Int))
		EndIf

		If aiOtherSlaver > 0
			Debug.Trace("[JM_RE][OBSERVE][HYDRA] Other slavers=" + aiOtherSlaver + " nearest=" + (afSlaverNearest as Int))
		EndIf
	EndIf
EndFunction

; ===========================================================================
; OBSERVER REPORTING
; ===========================================================================

Function ReportObservations(Int aiMerchant, Int aiBodyguard, Float afMerchantNearest, Int aiFaithKnight, Int aiPilgrim, Float afFaithNearest, Int aiRefugee, Float afRefugeeNearest, Int aiAdventurer, Float afAdventurerNearest, Int aiAdvLeader, Int aiAdvWarrior, Int aiAdvArcher, Int aiAdvRogue, Int aiAdvWizard, Int aiAdvSolo, Int aiAdvUnknown, Int aiVigilant, Float afVigilantNearest, Int aiMercWarrior, Int aiMercMissile, Int aiMercWizard, Float afMercNearest, Int aiAssassin, Float afAssassinNearest, Int aiBounty, Float afBountyNearest, Int aiKnight, Float afKnightNearest, Int aiMagician, Float afMagicianNearest)
	If DebugMode
		If aiAdventurer > 0
			Debug.Trace("[JM_RE][OBSERVE] Adventurers=" + aiAdventurer + " leader=" + aiAdvLeader + " warrior=" + aiAdvWarrior + " archer=" + aiAdvArcher + " rogue=" + aiAdvRogue + " wizard=" + aiAdvWizard + " solo=" + aiAdvSolo + " unknown=" + aiAdvUnknown + " nearest=" + (afAdventurerNearest as Int))
		EndIf

		If aiMerchant > 0 || aiBodyguard > 0
			Debug.Trace("[JM_RE][OBSERVE] Merchant group merchant=" + aiMerchant + " bodyguard=" + aiBodyguard + " nearest=" + (afMerchantNearest as Int))
		EndIf

		If aiFaithKnight > 0 || aiPilgrim > 0
			Debug.Trace("[JM_RE][OBSERVE] Faith group knight=" + aiFaithKnight + " pilgrim=" + aiPilgrim + " nearest=" + (afFaithNearest as Int))
		EndIf

		If aiRefugee > 0
			Debug.Trace("[JM_RE][OBSERVE] Refugees=" + aiRefugee + " nearest=" + (afRefugeeNearest as Int))
		EndIf

		If aiVigilant > 0
			Debug.Trace("[JM_RE][OBSERVE] Vigilants=" + aiVigilant + " nearest=" + (afVigilantNearest as Int))
		EndIf

		If aiMercWarrior > 0 || aiMercMissile > 0 || aiMercWizard > 0
			Debug.Trace("[JM_RE][OBSERVE] Mercenaries warrior=" + aiMercWarrior + " missile=" + aiMercMissile + " wizard=" + aiMercWizard + " nearest=" + (afMercNearest as Int))
		EndIf

		If aiAssassin > 0
			Debug.Trace("[JM_RE][OBSERVE] Assassins=" + aiAssassin + " nearest=" + (afAssassinNearest as Int))
		EndIf

		If aiBounty > 0
			Debug.Trace("[JM_RE][OBSERVE] Bounty hunters=" + aiBounty + " nearest=" + (afBountyNearest as Int))
		EndIf

		If aiKnight > 0
			Debug.Trace("[JM_RE][OBSERVE] Wandering knights=" + aiKnight + " nearest=" + (afKnightNearest as Int))
		EndIf

		If aiMagician > 0
			Debug.Trace("[JM_RE][OBSERVE] Wandering magicians=" + aiMagician + " nearest=" + (afMagicianNearest as Int))
		EndIf
	EndIf

	If !DebugNotifications
		Return
	EndIf

	If aiAdventurer > 0 && afAdventurerNearest <= BroadcastRadius && CanBroadcast(ROLE_ADVENTURER)
		Debug.Notification("JM RE OBS: Adventurers " + aiAdventurer + " | L" + aiAdvLeader + " W" + aiAdvWarrior + " A" + aiAdvArcher + " R" + aiAdvRogue + " M" + aiAdvWizard)
		MarkBroadcast(ROLE_ADVENTURER)
		Return
	EndIf

	If aiRefugee > 0 && afRefugeeNearest <= BroadcastRadius && CanBroadcast(ROLE_REFUGEE)
		Debug.Notification("JM RE OBS: Refugees " + aiRefugee + " nearby")
		MarkBroadcast(ROLE_REFUGEE)
		Return
	EndIf

	If aiVigilant > 0 && afVigilantNearest <= BroadcastRadius && CanBroadcast(ROLE_VIGILANT)
		Debug.Notification("JM RE OBS: Vigilants " + aiVigilant + " nearby")
		MarkBroadcast(ROLE_VIGILANT)
		Return
	EndIf

	If (aiMerchant > 0 || aiBodyguard > 0) && afMerchantNearest <= BroadcastRadius && CanBroadcast(ROLE_MERCHANT)
		Debug.Notification("JM RE OBS: Merchant sample M" + aiMerchant + " G" + aiBodyguard)
		MarkBroadcast(ROLE_MERCHANT)
		MarkBroadcast(ROLE_MERCHANT_BODYGUARD)
		Return
	EndIf

	If (aiFaithKnight > 0 || aiPilgrim > 0) && afFaithNearest <= BroadcastRadius && CanBroadcast(ROLE_PILGRIM)
		Debug.Notification("JM RE OBS: Faith group K" + aiFaithKnight + " P" + aiPilgrim)
		MarkBroadcast(ROLE_PILGRIM)
		MarkBroadcast(ROLE_KNIGHT_OF_FAITH)
		Return
	EndIf

	If (aiMercWarrior > 0 || aiMercMissile > 0 || aiMercWizard > 0) && afMercNearest <= BroadcastRadius && CanBroadcast(ROLE_MERCENARY_WARRIOR)
		Debug.Notification("JM RE OBS: Mercenaries W" + aiMercWarrior + " A" + aiMercMissile + " M" + aiMercWizard)
		MarkBroadcast(ROLE_MERCENARY_WARRIOR)
		MarkBroadcast(ROLE_MERCENARY_MISSILE)
		MarkBroadcast(ROLE_MERCENARY_WIZARD)
		Return
	EndIf

	If aiKnight > 0 && afKnightNearest <= BroadcastRadius && CanBroadcast(ROLE_WANDERING_KNIGHT)
		Debug.Notification("JM RE OBS: Wandering knight nearby")
		MarkBroadcast(ROLE_WANDERING_KNIGHT)
		Return
	EndIf

	If aiMagician > 0 && afMagicianNearest <= BroadcastRadius && CanBroadcast(ROLE_WANDERING_MAGICIAN)
		Debug.Notification("JM RE OBS: Wandering magician nearby")
		MarkBroadcast(ROLE_WANDERING_MAGICIAN)
		Return
	EndIf

	If aiAssassin > 0 && afAssassinNearest <= BroadcastRadius && CanBroadcast(ROLE_ASSASSIN)
		Debug.Notification("JM RE OBS: Assassin population detected")
		MarkBroadcast(ROLE_ASSASSIN)
		Return
	EndIf

	If aiBounty > 0 && afBountyNearest <= BroadcastRadius && CanBroadcast(ROLE_BOUNTY_HUNTER)
		Debug.Notification("JM RE OBS: Bounty hunter population detected")
		MarkBroadcast(ROLE_BOUNTY_HUNTER)
	EndIf
EndFunction