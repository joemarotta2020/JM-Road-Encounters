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
- LIVE: Hydra Sacred Band direct road contact
- LIVE: Immersive Wenches Maid Wench direct road contact

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
Bool LiveHydraSacredBandEnabled = True
Bool LiveImmersiveWenchEnabled = True

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
Float RogueCooldownHours = 12.0
Float RefugeeCooldownHours = 12.0
Float PilgrimCooldownHours = 12.0
Float VigilantCooldownHours = 12.0
Float MerchantCooldownHours = 12.0
Float MagicianCooldownHours = 12.0
Float BountyHunterCooldownHours = 12.0
Float HydraCaravanCooldownHours = 12.0
Float HydraSacredBandCooldownHours = 12.0
Float ImmersiveWenchCooldownHours = 12.0

Float RogueOpportunityRadius = 350.0
Float RefugeeOpportunityRadius = 350.0
Float PilgrimOpportunityRadius = 350.0
Float VigilantOpportunityRadius = 350.0
Float MerchantOpportunityRadius = 350.0
Float MagicianOpportunityRadius = 350.0
Float BountyHunterOpportunityRadius = 350.0
Float HydraOpportunityRadius = 350.0
Float HydraSacredBandOpportunityRadius = 350.0
Float ImmersiveWenchOpportunityRadius = 350.0

Float RogueOpportunityChance = 100.0
Float RefugeeOpportunityChance = 100.0
Float PilgrimOpportunityChance = 100.0
Float VigilantOpportunityChance = 100.0
Float MerchantOpportunityChance = 100.0
Float MagicianOpportunityChance = 100.0
Float BountyHunterOpportunityChance = 100.0
Float HydraOpportunityChance = 100.0
Float HydraSacredBandOpportunityChance = 100.0
Float ImmersiveWenchOpportunityChance = 100.0

; ===========================================================================
; ROLE / CATEGORY CONSTANTS
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
Int CATEGORY_HYDRA_SACRED_BAND = 9
Int CATEGORY_IMMERSIVE_WENCH = 10

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
Float NextHydraSacredBandRollDay = 0.0
Float NextImmersiveWenchRollDay = 0.0

Bool HydraProviderLoaded = False

; Native scanner state. New scalars default safely on an existing save.
; HelloReadyGlobal is retained only to force the failed idle-dialog path OFF.
GlobalVariable HelloReadyGlobal
Bool NativeScannerInitialized = False
Bool NativeDetectorAvailable = False
Bool NativeDetectorChecked = False
; Cadence invariant:
; - HasSuccessfulEncounter stays False until an actual player-facing encounter commits.
; - LastSuccessfulEncounterDay is written only by a real successful encounter.
; - Initialization/load/migration must never manufacture a success timestamp.
Float LastSuccessfulEncounterDay = 0.0
Bool HasSuccessfulEncounter = False
; Separate first-encounter pressure clock. Safe to initialize on an existing save.
Float PressureStartDay = 0.0
Int CadenceStateVersion = 0
Int NativeScanCounter = 0
Int SearchPulseCounter = 0

; Scanner-contact flavor is deliberately separate from DebugNotifications.
; It confirms that the native scanner found a valid live encounter group but the
; encounter was rejected by probability or cooldown. Scalars are safe mid-save.
Float ScannerFlavorCooldownHours = 1.0
Float LastRogueFlavorDay = 0.0
Float LastRefugeeFlavorDay = 0.0
Float LastPilgrimFlavorDay = 0.0
Float LastVigilantFlavorDay = 0.0
Float LastMerchantFlavorDay = 0.0
Float LastMagicianFlavorDay = 0.0
Float LastBountyFlavorDay = 0.0
Float LastHydraFlavorDay = 0.0
Float LastHydraSacredBandFlavorDay = 0.0
Float LastImmersiveWenchFlavorDay = 0.0

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

; Force-greet state for direct road-contact categories.  All scalars are safe on existing saves.
Bool JM_RE_ForceGreetPending = False
Bool JM_RE_ForceGreetOpened = False
Actor JM_RE_ForceGreetActor
Int JM_RE_ForceGreetCategory = CATEGORY_NONE
Float JM_RE_ForceGreetDistance = 0.0
Float JM_RE_ForceGreetStartedReal = 0.0
Float JM_RE_ForceGreetTimeoutSeconds = 12.0

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

	; Reconcile cadence state without fabricating a successful encounter timestamp.
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
	; v2 repairs the fake-success / zero-history deadlock from older scanner builds.
	If CadenceStateVersion < 2
		Float legacyTimestamp = LastSuccessfulEncounterDay

		; Old builds wrote this field during initialization/migration, so it cannot
		; be trusted as evidence of a real encounter.
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
		NextHydraSacredBandRollDay = 0.0
		NextImmersiveWenchRollDay = 0.0

		CadenceStateVersion = 2
		If DebugMode
			Debug.Trace("[JM_RE][CADENCE] MIGRATE v2 repaired legacy cadence. hasSuccess=False legacyTimestampIgnored=" + legacyTimestamp + " scannerEligible=TRUE")
		EndIf
	EndIf

	; v3 gives the first encounter its own pressure clock.  Starting at QuietHours
	; makes a no-history save immediately eligible for normal encounter rolls.
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
			NextHydraSacredBandRollDay = 0.0
			NextImmersiveWenchRollDay = 0.0
		EndIf

		CadenceStateVersion = 3
		If DebugMode
			Debug.Trace("[JM_RE][CADENCE] MIGRATE v3 pressureStartDay=" + PressureStartDay + " hasSuccess=" + HasSuccessfulEncounter + " pressureHours=" + GetHoursSinceSuccessfulEncounter())
		EndIf
	EndIf
EndFunction

Function NativeWakeScanner()
	; Called by JM_RoadEncounters.dll after a save finishes loading.
	; Always reconcile cadence even when NativeScannerInitialized was serialized True.
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
		Debug.Trace("[JM_RE][SCAN] post-load native wake. dllAvailable=" + NativeDetectorAvailable + " cadenceVersion=" + CadenceStateVersion + " hasSuccess=" + HasSuccessfulEncounter + " lastSuccessDay=" + LastSuccessfulEncounterDay + " pressureStartDay=" + PressureStartDay + " elapsedHours=" + GetHoursSinceSuccessfulEncounter())
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

	If JM_RE_ForceGreetPending
		UpdateJM_RE_ForceGreet()
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
			Debug.Trace("[JM_RE][SCAN] pulse #" + SearchPulseCounter + " skipped=quiet-window hasSuccess=TRUE elapsedHours=" + elapsedHours + " quietHours=" + QuietHours + " lastSuccessDay=" + LastSuccessfulEncounterDay + " dllAvailable=" + NativeDetectorAvailable)
		EndIf
		RegisterForSingleUpdate(nextInterval)
		Return
	EndIf

	If DebugMode && !HasSuccessfulEncounter && (SearchPulseCounter % 20) == 0
		Debug.Trace("[JM_RE][CADENCE] pulse #" + SearchPulseCounter + " history=NONE scannerEligible=TRUE elapsedHours=" + elapsedHours + " dllAvailable=" + NativeDetectorAvailable)
	EndIf

	If NativeDetectorAvailable
		Actor[] nearby = JM_RE_Native.GetNearbyActors(PlayerRef, ScanRadius, NativeScanMaxActors)
		EvaluateNativeCandidates(nearby, elapsedHours)
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
	ElseIf aiCategory == CATEGORY_HYDRA_SACRED_BAND
		Return HydraSacredBandOpportunityRadius
	ElseIf aiCategory == CATEGORY_IMMERSIVE_WENCH
		Return ImmersiveWenchOpportunityRadius
	EndIf

	Return 0.0
EndFunction

Function EvaluateNativeCandidates(Actor[] akNearby, Float afElapsedHours)
	NativeScanCounter += 1

	If akNearby == None || akNearby.Length <= 0
		If DebugMode && (NativeScanCounter % 10) == 0
			Debug.Trace("[JM_RE][SCAN] native scan: no nearby high-process actors. elapsedHours=" + (afElapsedHours as Int))
		EndIf
		Return
	EndIf

	Float nowDay = Utility.GetCurrentGameTime()
	Int cooldownCategory = CATEGORY_NONE
	Int i = 0
	While i < akNearby.Length
		Actor candidate = akNearby[i]
		If IsUsableCandidate(candidate) && !candidate.IsInCombat()
			Int category = GetEncounterCategory(candidate)
			If category != CATEGORY_NONE
				Float distance = candidate.GetDistance(PlayerRef)
				Float allowedRadius = GetOpportunityRadiusForCategory(category)
				If allowedRadius > 0.0 && distance > 0.0 && distance <= allowedRadius
					If CanCommitCategory(category, nowDay)
						RollCadenceOpportunity(category, candidate, distance, afElapsedHours, nowDay, "native")
						Return
					ElseIf cooldownCategory == CATEGORY_NONE && IsCategoryCooldownBlocked(category, nowDay)
						cooldownCategory = category
					EndIf
				EndIf
			EndIf
		EndIf
		i += 1
	EndWhile

	; Do not let a cooldown-blocked contact hide another eligible encounter.
	; We only speak after the full nearest-first array has been considered.
	If cooldownCategory != CATEGORY_NONE
		NotifyScannerRejection(cooldownCategory, True)
	EndIf

	If DebugMode && (NativeScanCounter % 10) == 0
		Debug.Trace("[JM_RE][SCAN] native scan: actors=" + akNearby.Length + " but no eligible encounter actor. elapsedHours=" + (afElapsedHours as Int))
	EndIf
EndFunction

Function RunFallbackSearch(Float afElapsedHours)
	Float nowDay = Utility.GetCurrentGameTime()
	Actor bestActor
	Int bestCategory = CATEGORY_NONE
	Float bestDistance = 0.0
	Int cooldownCategory = CATEGORY_NONE
	Float cooldownDistance = 0.0
	Int i = 0

	While i < FallbackScanSamples
		Actor candidate = Game.FindRandomActorFromRef(PlayerRef, FallbackScanRadius)
		If IsUsableCandidate(candidate) && !candidate.IsInCombat()
			Int category = GetEncounterCategory(candidate)
			If category != CATEGORY_NONE
				Float distance = candidate.GetDistance(PlayerRef)
				Float allowedRadius = GetOpportunityRadiusForCategory(category)
				If allowedRadius > 0.0 && distance > 0.0 && distance <= allowedRadius
					If CanCommitCategory(category, nowDay)
						If bestActor == None || distance < bestDistance
							bestActor = candidate
							bestCategory = category
							bestDistance = distance
						EndIf
					ElseIf IsCategoryCooldownBlocked(category, nowDay)
						If cooldownCategory == CATEGORY_NONE || distance < cooldownDistance
							cooldownCategory = category
							cooldownDistance = distance
						EndIf
					EndIf
				EndIf
			EndIf
		EndIf
		i += 1
	EndWhile

	If bestActor != None
		RollCadenceOpportunity(bestCategory, bestActor, bestDistance, afElapsedHours, nowDay, "fallback")
	ElseIf cooldownCategory != CATEGORY_NONE
		NotifyScannerRejection(cooldownCategory, True)
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
		NotifyScannerRejection(aiCategory, False)
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

	; Soft dependency: only IW-owned actors explicitly named as Maid Wenches qualify.
	If JM_RE_ImmersiveWenchesProvider.IsMaidWench(akActor)
		Return CATEGORY_IMMERSIVE_WENCH
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
		ElseIf JM_RE_HydraProvider.IsSacredBand(akActor)
			Return CATEGORY_HYDRA_SACRED_BAND
		EndIf
	EndIf

	Return CATEGORY_NONE
EndFunction

Bool Function IsLiveCategoryConfigured(Int aiCategory)
	If !GovernorEnabled || aiCategory == CATEGORY_NONE
		Return False
	EndIf

	If aiCategory == CATEGORY_ROGUE
		Return LiveRogueEnabled
	ElseIf aiCategory == CATEGORY_REFUGEE
		Return LiveRefugeeEnabled && RefugeeRequestMessage != None
	ElseIf aiCategory == CATEGORY_PILGRIM
		Return LivePilgrimEnabled && PilgrimRequestMessage != None
	ElseIf aiCategory == CATEGORY_VIGILANT
		Return LiveVigilantEnabled && VigilantInspectionMessage != None
	ElseIf aiCategory == CATEGORY_MERCHANT
		Return LiveMerchantEnabled
	ElseIf aiCategory == CATEGORY_MAGICIAN
		Return LiveMagicianEnabled && MagicianServiceMessage != None
	ElseIf aiCategory == CATEGORY_BOUNTY_HUNTER
		Return LiveBountyHunterEnabled && BountyHunterMessage != None
	ElseIf aiCategory == CATEGORY_HYDRA_CARAVAN
		Return LiveHydraCaravanEnabled && HydraCaravanMessage != None
	ElseIf aiCategory == CATEGORY_HYDRA_SACRED_BAND
		Return LiveHydraSacredBandEnabled
	ElseIf aiCategory == CATEGORY_IMMERSIVE_WENCH
		Return LiveImmersiveWenchEnabled && JM_RE_ImmersiveWenchesProvider.IsInstalled()
	EndIf

	Return False
EndFunction

Float Function GetCategoryNextRollDay(Int aiCategory)
	If aiCategory == CATEGORY_ROGUE
		Return NextRogueRollDay
	ElseIf aiCategory == CATEGORY_REFUGEE
		Return NextRefugeeRollDay
	ElseIf aiCategory == CATEGORY_PILGRIM
		Return NextPilgrimRollDay
	ElseIf aiCategory == CATEGORY_VIGILANT
		Return NextVigilantRollDay
	ElseIf aiCategory == CATEGORY_MERCHANT
		Return NextMerchantRollDay
	ElseIf aiCategory == CATEGORY_MAGICIAN
		Return NextMagicianRollDay
	ElseIf aiCategory == CATEGORY_BOUNTY_HUNTER
		Return NextBountyHunterRollDay
	ElseIf aiCategory == CATEGORY_HYDRA_CARAVAN
		Return NextHydraCaravanRollDay
	ElseIf aiCategory == CATEGORY_HYDRA_SACRED_BAND
		Return NextHydraSacredBandRollDay
	ElseIf aiCategory == CATEGORY_IMMERSIVE_WENCH
		Return NextImmersiveWenchRollDay
	EndIf

	Return 0.0
EndFunction

Bool Function IsCategoryCooldownBlocked(Int aiCategory, Float afNowDay)
	If !IsLiveCategoryConfigured(aiCategory)
		Return False
	EndIf

	If afNowDay < GlobalNextEncounterDay
		Return True
	EndIf

	Return afNowDay < GetCategoryNextRollDay(aiCategory)
EndFunction

Float Function GetLastScannerFlavorDay(Int aiCategory)
	If aiCategory == CATEGORY_ROGUE
		Return LastRogueFlavorDay
	ElseIf aiCategory == CATEGORY_REFUGEE
		Return LastRefugeeFlavorDay
	ElseIf aiCategory == CATEGORY_PILGRIM
		Return LastPilgrimFlavorDay
	ElseIf aiCategory == CATEGORY_VIGILANT
		Return LastVigilantFlavorDay
	ElseIf aiCategory == CATEGORY_MERCHANT
		Return LastMerchantFlavorDay
	ElseIf aiCategory == CATEGORY_MAGICIAN
		Return LastMagicianFlavorDay
	ElseIf aiCategory == CATEGORY_BOUNTY_HUNTER
		Return LastBountyFlavorDay
	ElseIf aiCategory == CATEGORY_HYDRA_CARAVAN
		Return LastHydraFlavorDay
	ElseIf aiCategory == CATEGORY_HYDRA_SACRED_BAND
		Return LastHydraSacredBandFlavorDay
	ElseIf aiCategory == CATEGORY_IMMERSIVE_WENCH
		Return LastImmersiveWenchFlavorDay
	EndIf

	Return 0.0
EndFunction

Function MarkScannerFlavorDay(Int aiCategory, Float afNowDay)
	If aiCategory == CATEGORY_ROGUE
		LastRogueFlavorDay = afNowDay
	ElseIf aiCategory == CATEGORY_REFUGEE
		LastRefugeeFlavorDay = afNowDay
	ElseIf aiCategory == CATEGORY_PILGRIM
		LastPilgrimFlavorDay = afNowDay
	ElseIf aiCategory == CATEGORY_VIGILANT
		LastVigilantFlavorDay = afNowDay
	ElseIf aiCategory == CATEGORY_MERCHANT
		LastMerchantFlavorDay = afNowDay
	ElseIf aiCategory == CATEGORY_MAGICIAN
		LastMagicianFlavorDay = afNowDay
	ElseIf aiCategory == CATEGORY_BOUNTY_HUNTER
		LastBountyFlavorDay = afNowDay
	ElseIf aiCategory == CATEGORY_HYDRA_CARAVAN
		LastHydraFlavorDay = afNowDay
	ElseIf aiCategory == CATEGORY_HYDRA_SACRED_BAND
		LastHydraSacredBandFlavorDay = afNowDay
	ElseIf aiCategory == CATEGORY_IMMERSIVE_WENCH
		LastImmersiveWenchFlavorDay = afNowDay
	EndIf
EndFunction

Bool Function ScannerFlavorReady(Int aiCategory, Float afNowDay)
	Float lastDay = GetLastScannerFlavorDay(aiCategory)
	If lastDay <= 0.0
		Return True
	EndIf

	Return afNowDay >= (lastDay + (ScannerFlavorCooldownHours / 24.0))
EndFunction

String Function GetScannerRejectionFlavor(Int aiCategory, Bool abCooldown)
	If aiCategory == CATEGORY_ROGUE
		If abCooldown
			Return "The adventurer watches you pass, but makes no move this time."
		EndIf
		Return "An adventurer studies you for a moment, then decides against trying anything."
	ElseIf aiCategory == CATEGORY_REFUGEE
		If abCooldown
			Return "The refugees notice you, but let you pass without another request."
		EndIf
		Return "A refugee seems ready to approach, then thinks better of it."
	ElseIf aiCategory == CATEGORY_PILGRIM
		If abCooldown
			Return "The pilgrims acknowledge you but continue on their way."
		EndIf
		Return "A pilgrim considers approaching you, then continues along the road."
	ElseIf aiCategory == CATEGORY_VIGILANT
		If abCooldown
			Return "The Vigilant gives you a hard look but does not stop you again."
		EndIf
		Return "A Vigilant watches you closely, then lets you pass."
	ElseIf aiCategory == CATEGORY_MERCHANT
		If abCooldown
			Return "The travelling merchant recognizes you and continues along the road."
		EndIf
		Return "A travelling merchant glances your way but does not call out."
	ElseIf aiCategory == CATEGORY_MAGICIAN
		If abCooldown
			Return "The wandering magician notices you but offers nothing further."
		EndIf
		Return "A wandering magician considers you briefly, then moves on."
	ElseIf aiCategory == CATEGORY_BOUNTY_HUNTER
		If abCooldown
			Return "The bounty hunter recognizes you but leaves you alone this time."
		EndIf
		Return "A bounty hunter sizes you up, then decides not to press the issue."
	ElseIf aiCategory == CATEGORY_HYDRA_CARAVAN
		If abCooldown
			Return "The slaver caravan recognizes you and lets you pass without another demand."
		EndIf
		Return "The slaver caravan watches you pass, but no one steps forward."
	ElseIf aiCategory == CATEGORY_HYDRA_SACRED_BAND
		If abCooldown
			Return "The Sacred Band recognizes you and lets you pass this time."
		EndIf
		Return "A Sacred Band slaver notices you, but does not step into your path."
	ElseIf aiCategory == CATEGORY_IMMERSIVE_WENCH
		If abCooldown
			Return "The Maid Wench recognizes you and keeps walking this time."
		EndIf
		Return "A Maid Wench catches your eye, but continues along the road."
	EndIf

	Return ""
EndFunction

Function NotifyScannerRejection(Int aiCategory, Bool abCooldown)
	Float nowDay = Utility.GetCurrentGameTime()
	If !ScannerFlavorReady(aiCategory, nowDay)
		Return
	EndIf

	String flavor = GetScannerRejectionFlavor(aiCategory, abCooldown)
	If flavor == ""
		Return
	EndIf

	Debug.Notification(flavor)
	MarkScannerFlavorDay(aiCategory, nowDay)

	If DebugMode
		String reason = "roll"
		If abCooldown
			reason = "cooldown"
		EndIf
		Debug.Trace("[JM_RE][FLAVOR] reason=" + reason + " category=" + GetCategoryLabel(aiCategory))
	EndIf
EndFunction

Bool Function CanCommitCategory(Int aiCategory, Float afNowDay)
	Return IsLiveCategoryConfigured(aiCategory) && !IsCategoryCooldownBlocked(aiCategory, afNowDay)
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
	ElseIf aiCategory == CATEGORY_HYDRA_SACRED_BAND
		NextHydraSacredBandRollDay = nextDay
	ElseIf aiCategory == CATEGORY_IMMERSIVE_WENCH
		NextImmersiveWenchRollDay = nextDay
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
	ElseIf aiCategory == CATEGORY_HYDRA_SACRED_BAND
		NextHydraSacredBandRollDay = nextDay
	ElseIf aiCategory == CATEGORY_IMMERSIVE_WENCH
		NextImmersiveWenchRollDay = nextDay
	EndIf
EndFunction

Float Function GetOpportunityChance(Int aiCategory)
	If aiCategory == CATEGORY_ROGUE
		Return RogueOpportunityChance
	ElseIf aiCategory == CATEGORY_REFUGEE
		Return RefugeeOpportunityChance
	ElseIf aiCategory == CATEGORY_PILGRIM
		Return PilgrimOpportunityChance
	ElseIf aiCategory == CATEGORY_VIGILANT
		Return VigilantOpportunityChance
	ElseIf aiCategory == CATEGORY_MERCHANT
		Return MerchantOpportunityChance
	ElseIf aiCategory == CATEGORY_MAGICIAN
		Return MagicianOpportunityChance
	ElseIf aiCategory == CATEGORY_BOUNTY_HUNTER
		Return BountyHunterOpportunityChance
	ElseIf aiCategory == CATEGORY_HYDRA_CARAVAN
		Return HydraOpportunityChance
	ElseIf aiCategory == CATEGORY_HYDRA_SACRED_BAND
		Return HydraSacredBandOpportunityChance
	ElseIf aiCategory == CATEGORY_IMMERSIVE_WENCH
		Return ImmersiveWenchOpportunityChance
	EndIf

	Return 0.0
EndFunction

Function CommitEncounter(Int aiCategory, Actor akActor, Float afDistance, Float afNowDay, String asSource)
	If akActor == None || aiCategory == CATEGORY_NONE
		Return
	EndIf

	; Sacred Band / Maid Wench do not consume cadence or their category cooldown
	; until the actual force-greet dialogue opens.  A failed approach is free to retry.
	If aiCategory == CATEGORY_HYDRA_SACRED_BAND || aiCategory == CATEGORY_IMMERSIVE_WENCH
		If BeginJM_RE_ForceGreet(akActor, aiCategory, afDistance)
			If DebugMode
				Debug.Trace("[JM_RE][FORCEGREET] RESERVED source=" + asSource + " category=" + GetCategoryLabel(aiCategory) + " actor=" + akActor + " distance=" + (afDistance as Int))
			EndIf
		EndIf
		Return
	EndIf

	; Only a real player-facing encounter resets cadence.
	LastSuccessfulEncounterDay = afNowDay
	HasSuccessfulEncounter = True
	GlobalNextEncounterDay = afNowDay + (GlobalEncounterCooldownHours / 24.0)
	SetCategorySuccessCooldown(aiCategory, afNowDay, GetCategorySuccessCooldownHours(aiCategory))

	If DebugMode
		Debug.Trace("[JM_RE][DIRECTOR] COMMIT source=" + asSource + " category=" + GetCategoryLabel(aiCategory) + " actor=" + akActor + " distance=" + (afDistance as Int))
	EndIf

	If aiCategory == CATEGORY_ROGUE
		ResolveRogueEncounter(akActor, afDistance)
	ElseIf aiCategory == CATEGORY_REFUGEE
		ResolveRefugeeEncounter(akActor, afDistance)
	ElseIf aiCategory == CATEGORY_PILGRIM
		ResolvePilgrimEncounter(akActor, afDistance)
	ElseIf aiCategory == CATEGORY_VIGILANT
		ResolveVigilantEncounter(akActor, afDistance)
	ElseIf aiCategory == CATEGORY_MERCHANT
		ResolveMerchantEncounter(akActor, afDistance)
	ElseIf aiCategory == CATEGORY_MAGICIAN
		ResolveMagicianEncounter(akActor, afDistance)
	ElseIf aiCategory == CATEGORY_BOUNTY_HUNTER
		ResolveBountyHunterEncounter(akActor, afDistance)
	ElseIf aiCategory == CATEGORY_HYDRA_CARAVAN
		ResolveHydraCaravanEncounter(akActor, afDistance)
	ElseIf aiCategory == CATEGORY_HYDRA_SACRED_BAND
		ResolveHydraSacredBandEncounter(akActor, afDistance)
	ElseIf aiCategory == CATEGORY_IMMERSIVE_WENCH
		ResolveImmersiveWenchEncounter(akActor, afDistance)
	EndIf
EndFunction

Bool Function BeginJM_RE_ForceGreet(Actor akActor, Int aiCategory, Float afDistance)
	If akActor == None || JM_RE_ForceGreetPending
		Return False
	EndIf
	Quest q = Game.GetFormFromFile(0x00000815, "JM_RoadEncounters.esp") as Quest
	Package pkg = Game.GetFormFromFile(0x00000816, "JM_RoadEncounters.esp") as Package
	If q == None || pkg == None
		Debug.Trace("[JM_RE][FORCEGREET] missing quest/package category=" + aiCategory)
		Return False
	EndIf
	If q.IsRunning()
		q.Stop()
	EndIf
	q.Start()
	JM_RE_ForceGreetPending = True
	JM_RE_ForceGreetOpened = False
	JM_RE_ForceGreetActor = akActor
	JM_RE_ForceGreetCategory = aiCategory
	JM_RE_ForceGreetDistance = afDistance
	JM_RE_ForceGreetStartedReal = Utility.GetCurrentRealTime()
	RegisterForMenu("Dialogue Menu")
	akActor.StopCombat()
	akActor.SetLookAt(PlayerRef)
	ActorUtil.AddPackageOverride(akActor, pkg, 110, 1)
	akActor.EvaluatePackage()
	Debug.Trace("[JM_RE][FORCEGREET] package applied category=" + GetCategoryLabel(aiCategory) + " actor=" + akActor + " distance=" + (afDistance as Int))
	UnregisterForUpdate()
	RegisterForSingleUpdate(0.5)
	Return True
EndFunction

Function UpdateJM_RE_ForceGreet()
	If !JM_RE_ForceGreetPending
		Return
	EndIf
	If JM_RE_ForceGreetOpened
		RegisterForSingleUpdate(1.0)
		Return
	EndIf
	If JM_RE_ForceGreetActor == None || JM_RE_ForceGreetActor.IsDead() || !JM_RE_ForceGreetActor.Is3DLoaded()
		Debug.Trace("[JM_RE][FORCEGREET] aborted: actor unavailable; no success cooldown consumed")
		ClearJM_RE_ForceGreet(False)
		RegisterForSingleUpdate(5.0)
		Return
	EndIf
	If Utility.GetCurrentRealTime() - JM_RE_ForceGreetStartedReal >= JM_RE_ForceGreetTimeoutSeconds
		Debug.Trace("[JM_RE][FORCEGREET] approach/dialogue timeout; no success cooldown consumed")
		ClearJM_RE_ForceGreet(False)
		RegisterForSingleUpdate(5.0)
		Return
	EndIf
	JM_RE_ForceGreetActor.SetLookAt(PlayerRef)
	JM_RE_ForceGreetActor.EvaluatePackage()
	RegisterForSingleUpdate(0.5)
EndFunction

Function JM_RE_CommitForceGreetSuccess()
	Float nowDay = Utility.GetCurrentGameTime()
	LastSuccessfulEncounterDay = nowDay
	HasSuccessfulEncounter = True
	GlobalNextEncounterDay = nowDay + (GlobalEncounterCooldownHours / 24.0)
	SetCategorySuccessCooldown(JM_RE_ForceGreetCategory, nowDay, GetCategorySuccessCooldownHours(JM_RE_ForceGreetCategory))
	Debug.Trace("[JM_RE][FORCEGREET] DIALOGUE OPENED; cooldown committed category=" + GetCategoryLabel(JM_RE_ForceGreetCategory) + " actor=" + JM_RE_ForceGreetActor)
EndFunction

Event OnMenuOpen(String menuName)
	If menuName == "Dialogue Menu" && JM_RE_ForceGreetPending && !JM_RE_ForceGreetOpened
		JM_RE_ForceGreetOpened = True
		JM_RE_CommitForceGreetSuccess()
	EndIf
EndEvent

Event OnMenuClose(String menuName)
	If menuName != "Dialogue Menu" || !JM_RE_ForceGreetPending || !JM_RE_ForceGreetOpened
		Return
	EndIf
	Debug.Trace("[JM_RE][FORCEGREET] dialogue closed category=" + GetCategoryLabel(JM_RE_ForceGreetCategory))
	ClearJM_RE_ForceGreet(True)
	RegisterForSingleUpdate(2.0)
EndEvent

Function ClearJM_RE_ForceGreet(Bool abDialogueOpened)
	UnregisterForMenu("Dialogue Menu")
	If JM_RE_ForceGreetActor != None
		ActorUtil.RemovePackageOverride(JM_RE_ForceGreetActor, Game.GetFormFromFile(0x00000816, "JM_RoadEncounters.esp") as Package)
		JM_RE_ForceGreetActor.ClearLookAt()
		JM_RE_ForceGreetActor.EvaluatePackage()
	EndIf
	Quest q = Game.GetFormFromFile(0x00000815, "JM_RoadEncounters.esp") as Quest
	If q != None && q.IsRunning()
		q.Stop()
	EndIf
	JM_RE_ForceGreetPending = False
	JM_RE_ForceGreetOpened = False
	JM_RE_ForceGreetActor = None
	JM_RE_ForceGreetCategory = CATEGORY_NONE
	JM_RE_ForceGreetDistance = 0.0
	JM_RE_ForceGreetStartedReal = 0.0
EndFunction

Function ResolveHydraSacredBandEncounter(Actor akSacredBand, Float afDistance)
	If akSacredBand == None
		Return
	EndIf
	BeginJM_RE_ForceGreet(akSacredBand, CATEGORY_HYDRA_SACRED_BAND, afDistance)
EndFunction

Function ResolveImmersiveWenchEncounter(Actor akWench, Float afDistance)
	If akWench == None || !JM_RE_ImmersiveWenchesProvider.IsMaidWench(akWench)
		Return
	EndIf
	BeginJM_RE_ForceGreet(akWench, CATEGORY_IMMERSIVE_WENCH, afDistance)
EndFunction

Function ResolveRogueEncounter(Actor akRogue, Float afDistance)
	If akRogue == None
		Return
	EndIf

	MiscObject goldForm = Game.GetForm(0x0000000F) as MiscObject
	If goldForm == None
		Return
	EndIf

	Int playerGold = PlayerRef.GetItemCount(goldForm)
	If playerGold <= 0
		Debug.Trace("[JM_RE][ROGUE] No gold available to steal.")
		Return
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
	EndIf

	If successChance < 15.0
		successChance = 15.0
	ElseIf successChance > 90.0
		successChance = 90.0
	EndIf

	Float roll = Utility.RandomFloat(0.0, 100.0)
	If roll <= successChance
		Int maxSteal = playerGold / 5
		If maxSteal < 10
			maxSteal = 10
		ElseIf maxSteal > 150
			maxSteal = 150
		EndIf

		If maxSteal > playerGold
			maxSteal = playerGold
		EndIf

		Int minSteal = maxSteal / 3
		If minSteal < 5
			minSteal = 5
		EndIf
		If minSteal > maxSteal
			minSteal = maxSteal
		EndIf

		Int amount = Utility.RandomInt(minSteal, maxSteal)
		PlayerRef.RemoveItem(goldForm, amount, True, akRogue)
		Debug.Notification("An adventurer brushes past you. A moment later, you realize " + amount + " gold is missing.")
		Debug.Trace("[JM_RE][ROGUE] SUCCESS actor=" + akRogue + " amount=" + amount + " chance=" + (successChance as Int) + " roll=" + (roll as Int))
	Else
		Debug.Notification("You notice an adventurer's hand drifting toward your coin purse. They pull back when you catch them.")
		Debug.Trace("[JM_RE][ROGUE] CAUGHT actor=" + akRogue + " chance=" + (successChance as Int) + " roll=" + (roll as Int))
	EndIf
EndFunction

Function ResolveRefugeeEncounter(Actor akRefugee, Float afDistance)
	If akRefugee == None || RefugeeRequestMessage == None
		Return
	EndIf

	Int choice = RefugeeRequestMessage.Show()
	If choice == 0
		MiscObject goldForm = Game.GetForm(0x0000000F) as MiscObject
		If goldForm == None
			Return
		EndIf

		Int playerGold = PlayerRef.GetItemCount(goldForm)
		If playerGold >= RefugeeAidAmount
			PlayerRef.RemoveItem(goldForm, RefugeeAidAmount)
			Debug.Notification("You give the refugees " + RefugeeAidAmount + " gold for food and supplies.")
			Debug.Trace("[JM_RE][REFUGEE] DONATED actor=" + akRefugee + " amount=" + RefugeeAidAmount)
		Else
			Debug.Notification("You do not have enough gold to help them.")
			Debug.Trace("[JM_RE][REFUGEE] INSUFFICIENT GOLD actor=" + akRefugee)
		EndIf
	Else
		Debug.Notification("The refugees thank you for listening and continue down the road.")
		Debug.Trace("[JM_RE][REFUGEE] DECLINED actor=" + akRefugee)
	EndIf
EndFunction

Function ResolvePilgrimEncounter(Actor akPilgrim, Float afDistance)
	If akPilgrim == None || PilgrimRequestMessage == None
		Return
	EndIf

	Int choice = PilgrimRequestMessage.Show()
	If choice == 0
		MiscObject goldForm = Game.GetForm(0x0000000F) as MiscObject
		If goldForm == None
			Return
		EndIf

		Int playerGold = PlayerRef.GetItemCount(goldForm)
		If playerGold >= PilgrimAlmsAmount
			PlayerRef.RemoveItem(goldForm, PilgrimAlmsAmount)
			Debug.Notification("You give the pilgrim " + PilgrimAlmsAmount + " gold in alms.")
			Debug.Trace("[JM_RE][PILGRIM] GAVE ALMS actor=" + akPilgrim + " amount=" + PilgrimAlmsAmount)
		Else
			Debug.Notification("You do not have enough gold for the requested alms.")
			Debug.Trace("[JM_RE][PILGRIM] INSUFFICIENT GOLD actor=" + akPilgrim)
		EndIf
	Else
		Debug.Notification("The pilgrim bows politely and continues on the road.")
		Debug.Trace("[JM_RE][PILGRIM] DECLINED actor=" + akPilgrim)
	EndIf
EndFunction

Function ResolveVigilantEncounter(Actor akVigilant, Float afDistance)
	If akVigilant == None || VigilantInspectionMessage == None
		Return
	EndIf

	Int choice = VigilantInspectionMessage.Show()
	If choice == 0
		Debug.Notification("The Vigilant studies you carefully, then allows you to continue.")
		Debug.Trace("[JM_RE][VIGILANT] COOPERATED actor=" + akVigilant)
	Else
		Debug.Notification("The Vigilant warns you not to interfere with their work.")
		Debug.Trace("[JM_RE][VIGILANT] REFUSED actor=" + akVigilant)
	EndIf
EndFunction

Function ResolveMerchantEncounter(Actor akMerchant, Float afDistance)
	If akMerchant == None
		Return
	EndIf

	Debug.Notification("A travelling merchant calls out to you from the road.")
	akMerchant.ShowBarterMenu()
	Debug.Trace("[JM_RE][MERCHANT] OPENED BARTER actor=" + akMerchant)
EndFunction

Function ResolveMagicianEncounter(Actor akMagician, Float afDistance)
	If akMagician == None || MagicianServiceMessage == None
		Return
	EndIf

	Int choice = MagicianServiceMessage.Show()
	If choice == 0
		MiscObject goldForm = Game.GetForm(0x0000000F) as MiscObject
		If goldForm == None
			Return
		EndIf

		Int playerGold = PlayerRef.GetItemCount(goldForm)
		If playerGold < MagicianServiceCost
			Debug.Notification("You cannot afford the wandering magician's fee.")
			Debug.Trace("[JM_RE][MAGICIAN] INSUFFICIENT GOLD actor=" + akMagician)
			Return
		EndIf

		PlayerRef.RemoveItem(goldForm, MagicianServiceCost)
		Float maxHealth = PlayerRef.GetBaseActorValue("Health")
		If maxHealth < 1.0
			maxHealth = 100.0
		EndIf
		PlayerRef.RestoreActorValue("Health", maxHealth)
		Debug.Notification("The wandering magician restores your strength.")
		Debug.Trace("[JM_RE][MAGICIAN] HEALED actor=" + akMagician + " fee=" + MagicianServiceCost)
	Else
		Debug.Notification("The wandering magician shrugs and continues down the road.")
		Debug.Trace("[JM_RE][MAGICIAN] DECLINED actor=" + akMagician)
	EndIf
EndFunction

Function ResolveBountyHunterEncounter(Actor akHunter, Float afDistance)
	If akHunter == None || BountyHunterMessage == None
		Return
	EndIf

	Int choice = BountyHunterMessage.Show()
	MiscObject goldForm = Game.GetForm(0x0000000F) as MiscObject

	If choice == 0
		If goldForm == None
			Return
		EndIf

		Int playerGold = PlayerRef.GetItemCount(goldForm)
		If playerGold >= BountyHunterDemand
			PlayerRef.RemoveItem(goldForm, BountyHunterDemand)
			Debug.Notification("You pay the bounty hunter " + BountyHunterDemand + " gold to avoid trouble.")
			Debug.Trace("[JM_RE][BOUNTY] PAID actor=" + akHunter + " amount=" + BountyHunterDemand)
		Else
			Debug.Notification("The bounty hunter sees you cannot pay and lets the matter drop—for now.")
			Debug.Trace("[JM_RE][BOUNTY] INSUFFICIENT GOLD actor=" + akHunter)
		EndIf
	Else
		Debug.Notification("The bounty hunter backs off, but keeps a close eye on you.")
		Debug.Trace("[JM_RE][BOUNTY] REFUSED actor=" + akHunter)
	EndIf
EndFunction

Function ResolveHydraCaravanEncounter(Actor akLeader, Float afDistance)
	If akLeader == None || HydraCaravanMessage == None
		Return
	EndIf

	Int choice = HydraCaravanMessage.Show()
	MiscObject goldForm = Game.GetForm(0x0000000F) as MiscObject

	If choice == 0
		If goldForm == None
			Return
		EndIf

		Int playerGold = PlayerRef.GetItemCount(goldForm)
		If playerGold >= HydraRoadFee
			PlayerRef.RemoveItem(goldForm, HydraRoadFee)
			Debug.Notification("You pay the slaver caravan " + HydraRoadFee + " gold and are allowed to pass.")
			Debug.Trace("[JM_RE][HYDRA] PAID ROAD FEE actor=" + akLeader + " amount=" + HydraRoadFee)
		Else
			Debug.Notification("The slaver leader sees you cannot pay and waves you away with a warning.")
			Debug.Trace("[JM_RE][HYDRA] INSUFFICIENT GOLD actor=" + akLeader)
		EndIf
	Else
		Debug.Notification("The slaver leader lets you pass, but their guards watch you closely.")
		Debug.Trace("[JM_RE][HYDRA] REFUSED ROAD FEE actor=" + akLeader)
	EndIf
EndFunction

Bool Function CanObserve()
	If PlayerRef == None
		Return False
	EndIf

	If JM_RE_ForceGreetPending
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

	If akActor.IsDisabled()
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

Function ObserveActor(Actor akActor, String asSource = "event")
	EnsureRuntimeState()

	If !CanObserve()
		Return
	EndIf

	If !IsUsableCandidate(akActor)
		Return
	EndIf

	Int role = GetRoleCode(akActor)
	If role == ROLE_NONE
		Return
	EndIf

	Float nowDay = Utility.GetCurrentGameTime()
	Float distance = akActor.GetDistance(PlayerRef)

	If DebugMode
		Debug.Trace("[JM_RE][OBSERVE] " + asSource + " role=" + role + " actor=" + akActor + " distance=" + (distance as Int))
	EndIf

	If DebugNotifications && distance <= BroadcastRadius && CanBroadcast(role)
		Debug.Notification("JM RE OBS: " + asSource + " role " + role + " | " + (distance as Int))
		MarkBroadcast(role)
	EndIf
EndFunction

Function EvaluateEncounterGovernor(Actor akRogue, Float afRogueDistance, Actor akRefugee, Float afRefugeeDistance, Actor akPilgrim, Float afPilgrimDistance, Actor akVigilant, Float afVigilantDistance, Actor akMerchant, Float afMerchantDistance, Actor akMagician, Float afMagicianDistance, Actor akBountyHunter, Float afBountyHunterDistance, Actor akHydraLeader, Float afHydraDistance)
	If !GovernorEnabled
		Return
	EndIf

	If !CanObserve()
		Return
	EndIf

	Float nowDay = Utility.GetCurrentGameTime()
	If nowDay < GlobalNextEncounterDay
		Return
	EndIf

	Int category = ChooseClosestEligibleOpportunity(akRogue, afRogueDistance, akRefugee, afRefugeeDistance, akPilgrim, afPilgrimDistance, akVigilant, afVigilantDistance, akMerchant, afMerchantDistance, akMagician, afMagicianDistance, akBountyHunter, afBountyHunterDistance, akHydraLeader, afHydraDistance, nowDay)

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
	Float chance = GetOpportunityChance(aiCategory)
	Float roll = Utility.RandomFloat(0.0, 100.0)

	If DebugMode
		Debug.Trace("[JM_RE][DIRECTOR] category=" + GetCategoryLabel(aiCategory) + " actor=" + akActor + " distance=" + (afDistance as Int) + " chance=" + (chance as Int) + " roll=" + (roll as Int))
	EndIf

	If roll <= chance
		CommitEncounter(aiCategory, akActor, afDistance, afNowDay, "observer")
	Else
		SetFailedRollCooldown(aiCategory, afNowDay)
	EndIf
EndFunction

Float Function GetCategorySuccessCooldownHours(Int aiCategory)
	If aiCategory == CATEGORY_ROGUE
		Return RogueCooldownHours
	ElseIf aiCategory == CATEGORY_REFUGEE
		Return RefugeeCooldownHours
	ElseIf aiCategory == CATEGORY_PILGRIM
		Return PilgrimCooldownHours
	ElseIf aiCategory == CATEGORY_VIGILANT
		Return VigilantCooldownHours
	ElseIf aiCategory == CATEGORY_MERCHANT
		Return MerchantCooldownHours
	ElseIf aiCategory == CATEGORY_MAGICIAN
		Return MagicianCooldownHours
	ElseIf aiCategory == CATEGORY_BOUNTY_HUNTER
		Return BountyHunterCooldownHours
	ElseIf aiCategory == CATEGORY_HYDRA_CARAVAN
		Return HydraCaravanCooldownHours
	ElseIf aiCategory == CATEGORY_HYDRA_SACRED_BAND
		Return HydraSacredBandCooldownHours
	ElseIf aiCategory == CATEGORY_IMMERSIVE_WENCH
		Return ImmersiveWenchCooldownHours
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
	ElseIf aiCategory == CATEGORY_HYDRA_SACRED_BAND
		Return "Hydra Sacred Band"
	ElseIf aiCategory == CATEGORY_IMMERSIVE_WENCH
		Return "Immersive Wench"
	EndIf

	Return "None"
EndFunction

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
		TraceEligible("Merchant / bodyguard", aiMerchant, afMerchantNearest)
		LastEligibleMerchantDay = nowDay
		Return
	EndIf

	If EligibleContact(aiBounty, afBountyNearest) && EligibleCooldownReady(LastEligibleBountyDay)
		TraceEligible("Bounty hunter", aiBounty, afBountyNearest)
		LastEligibleBountyDay = nowDay
		Return
	EndIf

	If EligibleContact(aiMagician, afMagicianNearest) && EligibleCooldownReady(LastEligibleMagicianDay)
		TraceEligible("Wandering magician", aiMagician, afMagicianNearest)
		LastEligibleMagicianDay = nowDay
		Return
	EndIf

	If EligibleContact(aiKnight, afKnightNearest) && EligibleCooldownReady(LastEligibleKnightDay)
		TraceEligible("Wandering knight", aiKnight, afKnightNearest)
		LastEligibleKnightDay = nowDay
		Return
	EndIf

	If EligibleContact(aiMercenary, afMercNearest) && EligibleCooldownReady(LastEligibleMercenaryDay)
		TraceEligible("Mercenary", aiMercenary, afMercNearest)
		LastEligibleMercenaryDay = nowDay
		Return
	EndIf

	If EligibleContact(aiAssassin, afAssassinNearest) && EligibleCooldownReady(LastEligibleAssassinDay)
		TraceEligible("Assassin", aiAssassin, afAssassinNearest)
		LastEligibleAssassinDay = nowDay
	EndIf
EndFunction

Function ReportHydraObservations(Int aiLeader, Int aiGuard, Int aiSlave, Float afCaravanNearest, Int aiSacredBand, Float afSacredBandNearest, Int aiOtherSlaver, Float afSlaverNearest)
	If DebugMode
		If aiLeader > 0 || aiGuard > 0 || aiSlave > 0
			Debug.Trace("[JM_RE][OBSERVE] Hydra caravan leader=" + aiLeader + " guard=" + aiGuard + " slave=" + aiSlave + " nearest=" + (afCaravanNearest as Int))
		EndIf

		If aiSacredBand > 0
			Debug.Trace("[JM_RE][OBSERVE] Hydra Sacred Band=" + aiSacredBand + " nearest=" + (afSacredBandNearest as Int))
		EndIf

		If aiOtherSlaver > 0
			Debug.Trace("[JM_RE][OBSERVE] Hydra other slavers=" + aiOtherSlaver + " nearest=" + (afSlaverNearest as Int))
		EndIf
	EndIf
EndFunction

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
		Debug.Notification("JM RE OBS: Mercenary group nearby")
		MarkBroadcast(ROLE_MERCENARY_WARRIOR)
		MarkBroadcast(ROLE_MERCENARY_MISSILE)
		MarkBroadcast(ROLE_MERCENARY_WIZARD)
		Return
	EndIf

	If aiAssassin > 0 && afAssassinNearest <= BroadcastRadius && CanBroadcast(ROLE_ASSASSIN)
		Debug.Notification("JM RE OBS: Assassin nearby")
		MarkBroadcast(ROLE_ASSASSIN)
		Return
	EndIf

	If aiBounty > 0 && afBountyNearest <= BroadcastRadius && CanBroadcast(ROLE_BOUNTY_HUNTER)
		Debug.Notification("JM RE OBS: Bounty hunter nearby")
		MarkBroadcast(ROLE_BOUNTY_HUNTER)
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
	EndIf
EndFunction