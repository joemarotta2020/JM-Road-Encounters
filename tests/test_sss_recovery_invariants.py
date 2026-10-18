from pathlib import Path


main = Path("src/main.cpp").read_text(encoding="utf-8")
controller = Path("papyrus/JM_SSS_WhoringController.psc").read_text(encoding="utf-8")
native_api = Path("papyrus/JM_RE_Native.psc").read_text(encoding="utf-8")

# Recovery architecture: exclusions are native-memory-only. The working SSS
# plugin/dialogue records are not part of exclusion storage or evaluation.
for required in (
    "JM_SSS_IN_MEMORY_EXCLUSIONS_V1",
    "g_sssWhoringExcludedBaseIDs",
    "ResolveSSSExclusionForm",
    "IsSSSWhoringExcluded",
    "g_sssWhoringExcludedBaseIDs.insert(npc->GetFormID())",
):
    assert required in main, f"missing recovery invariant: {required}"

for forbidden in (
    "kSSSWhoringExcludedActorsFormID",
    "g_sssWhoringExcludedActors",
    "accepted SSS dialogue by authoritative package fallback",
    "SSS_Whoring startup reconciliation",
):
    assert forbidden not in main, f"forbidden post-regression behavior remains: {forbidden}"

# The native exclusion set must be queryable by the ORIGINAL idle INFO fragment
# before that fragment fills its original SSS alias.
assert '"IsSSSWhoringExcluded"' in main, "native exclusion query is not registered"
assert "Bool Function IsSSSWhoringExcluded(Actor akActor) Global Native" in native_api

# Existing-save compatibility is locked: retain the modern controller's persisted
# fields and post-dialogue/SOS state. Acquisition authority, however, returns to
# the original SSS_WhoringIdle INFO fragments instead of proactive alias injection.
for required in (
    "Int Property AcquisitionTimeoutTicks = 60 Auto Hidden",
    "Int Property AcquisitionPostDialogueGraceTicks = 60 Auto Hidden",
    "Bool AcquisitionDialogueObserved = False",
    "Bool JM_SOSReassertPending = False",
    "Actor JM_SOSReassertActor = None",
    "Float JM_SOSReassertDeadlineReal = -9999.0",
    "Bool Function TryClaimOriginalIdle(Actor akSpeaker, Int aiAliasIndex)",
    "original idle rejected by permanent exclusion actor=",
    "ORIGINAL IDLE CLAIM actor=",
    "If dialogueMenuOpen && JM_RE_Native.IsSSSWhoringDialogueActive(candidate)",
    "BeginEncounter(candidate)",
    "JM_TryCommitPendingFromActivePlayerThread()",
):
    assert required in controller, f"missing original-idle recovery invariant: {required}"

assert "waiting for original SSS acceptance fragment" not in controller

schedule_start = controller.index("Function JM_ScheduleAcquisitionIfReady")
schedule_end = controller.index("EndFunction", schedule_start)
schedule = controller[schedule_start:schedule_end]
assert "RegisterForSingleUpdate" not in schedule, "scheduler still starts proactive native SSS acquisition"
assert "original SSS_WhoringIdle INFOs choose the actor" in schedule

update_start = controller.index("Event OnUpdate()")
update_end = controller.index("EndEvent", update_start)
update_block = controller[update_start:update_end]
assert "JM_RunAcquisitionScan()" not in update_block, "OnUpdate still proactively scans/force-fills SSS aliases"
assert "JM_UpdatePendingAcquisition()" in update_block

fragment_specs = {
    "SSS_SoliciteforSex.psc": ("akClient.ForceRefTo(akSpeaker)", 0),
    "SSS_SoldierWhore.psc": ("akSoldier.ForceRefTo(akSpeaker)", 2),
    "SSS_AmuletSex.psc": ("akClient.ForceRefTo(akSpeaker)", 3),
    "SSS_BanditApproach.psc": ("akClient.ForceRefTo(akSpeaker)", 5),
}
for name, (force_line, alias_index) in fragment_specs.items():
    path = Path("papyrus") / name
    assert path.exists(), f"missing original idle fragment source: {name}"
    text = path.read_text(encoding="utf-8")
    claim = f"JM_Cooldown.TryClaimOriginalIdle(akSpeaker, {alias_index})"
    assert claim in text, f"{name} does not claim original idle alias {alias_index}"
    assert "BeginEncounter(akSpeaker)" not in text, f"{name} still commits cooldown at idle fragment"
    assert text.index(claim) < text.index(force_line), f"{name} fills alias before exclusion/race claim"

print("SSS original-idle recovery source invariants PASS")
