from pathlib import Path

path = Path("papyrus/JM_SSS_WhoringController.psc")
text = path.read_text(encoding="utf-8")

if "ORIGINAL IDLE CLAIM actor=" in text:
    print("Original-idle controller patch already applied")
    raise SystemExit(0)

old_schedule = '''Function JM_ScheduleAcquisitionIfReady(Float afDelay = 0.0)
    If PredatorCombatActive || AcquisitionPending || !NativeScannerAvailable || !JM_IsReady()
        Return
    EndIf

    If afDelay < 0.1
        afDelay = AcquisitionScanSeconds
    EndIf

    UnregisterForUpdate()
    RegisterForSingleUpdate(afDelay)
EndFunction
'''
new_schedule = '''Function JM_ScheduleAcquisitionIfReady(Float afDelay = 0.0)
    ; Recovery architecture: original SSS_WhoringIdle INFOs choose the actor.
    ; Native scanning no longer force-fills aliases or initiates approaches.
    ; Pending original-idle approaches register their own watchdog update.
    Return
EndFunction
'''
if text.count(old_schedule) != 1:
    raise SystemExit(f"scheduler anchor count {text.count(old_schedule)}, expected 1")
text = text.replace(old_schedule, new_schedule, 1)

scan_anchor = '''Function JM_RunAcquisitionScan()
'''
claim = '''Bool Function TryClaimOriginalIdle(Actor akSpeaker, Int aiAliasIndex)
    If akSpeaker == None
        Return False
    EndIf

    JM_ResolveRuntimeForms()
    JM_RefreshNativeAvailability()

    ; Permanent exclusions are checked before any SSS approach alias is filled.
    If NativeScannerAvailable && JM_RE_Native.IsSSSWhoringExcluded(akSpeaker)
        Debug.Trace("[JM SSS][ACQ] original idle rejected by permanent exclusion actor=" + akSpeaker + " alias=" + aiAliasIndex)
        Return False
    EndIf

    Float now = Utility.GetCurrentGameTime()
    If NextEligibleGameTime > now || PredatorCombatActive
        Return False
    EndIf

    ; The original SSS idle INFO is the acquisition authority. Its first actor
    ; atomically owns the pending approach; later idle INFOs cannot overwrite an
    ; alias while this one is in flight. Cooldown is NOT consumed yet.
    If AcquisitionPending
        Return AcquisitionActor == akSpeaker
    EndIf

    JM_ClearStaleApproachAliases("original idle claim")
    AcquisitionPending = True
    AcquisitionActor = akSpeaker
    AcquisitionAliasIndex = aiAliasIndex
    AcquisitionWaitTicks = 0
    AcquisitionDialogueObserved = False
    JM_SetReady(False)

    Debug.Trace("[JM SSS][ACQ] ORIGINAL IDLE CLAIM actor=" + akSpeaker + " alias=" + aiAliasIndex)
    UnregisterForUpdate()
    RegisterForSingleUpdate(AcquisitionPendingPollSeconds)
    Return True
EndFunction

'''
if text.count(scan_anchor) != 1:
    raise SystemExit(f"scan anchor count {text.count(scan_anchor)}, expected 1")
text = text.replace(scan_anchor, claim + scan_anchor, 1)

old_gate = '''    If JM_RE_Native.IsSSSWhoringDialogueActive(candidate)
        Debug.Trace("[JM SSS][ACQ] live SSS dialogue verified for actor=" + candidate + " alias=" + aliasIndex)
        BeginEncounter(candidate)
'''
new_gate = '''    If dialogueMenuOpen && JM_RE_Native.IsSSSWhoringDialogueActive(candidate)
        Debug.Trace("[JM SSS][ACQ] live SSS dialogue verified for actor=" + candidate + " alias=" + aliasIndex)
        BeginEncounter(candidate)
'''
if text.count(old_gate) != 1:
    raise SystemExit(f"strict dialogue gate anchor count {text.count(old_gate)}, expected 1")
text = text.replace(old_gate, new_gate, 1)

old_update = '''    If AcquisitionPending
        JM_UpdatePendingAcquisition()
    Else
        JM_RunAcquisitionScan()
    EndIf
EndEvent
'''
new_update = '''    If AcquisitionPending
        JM_UpdatePendingAcquisition()
    EndIf
EndEvent
'''
if text.count(old_update) != 1:
    raise SystemExit(f"OnUpdate scan anchor count {text.count(old_update)}, expected 1")
text = text.replace(old_update, new_update, 1)

# Existing-save compatibility guard: this patch changes behavior/functions only.
# It must retain the serialized fields already present in the deployed modern PEX.
for required in (
    "Int Property AcquisitionTimeoutTicks = 60 Auto Hidden",
    "Int Property AcquisitionPostDialogueGraceTicks = 60 Auto Hidden",
    "Bool AcquisitionDialogueObserved = False",
    "Bool JM_SOSReassertPending = False",
    "Actor JM_SOSReassertActor = None",
    "Float JM_SOSReassertDeadlineReal = -9999.0",
):
    if required not in text:
        raise SystemExit(f"existing-save field missing after patch: {required}")

if "waiting for original SSS acceptance fragment" in text:
    raise SystemExit("broken wait-for-fragment behavior remains")

path.write_text(text, encoding="utf-8", newline="\n")
print("Restored original SSS idle acquisition authority in save-compatible controller")
