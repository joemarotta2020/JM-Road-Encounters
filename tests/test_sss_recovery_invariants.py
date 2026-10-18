from pathlib import Path


main = Path("src/main.cpp").read_text(encoding="utf-8")
controller = Path("papyrus/JM_SSS_WhoringController.psc").read_text(encoding="utf-8")

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

# Existing-save compatibility is locked: retain the modern controller's persisted
# fields and post-dialogue/SOS state, but restore the proven dialogue commit gate.
for required in (
    "Int Property AcquisitionTimeoutTicks = 60 Auto Hidden",
    "Int Property AcquisitionPostDialogueGraceTicks = 60 Auto Hidden",
    "Bool AcquisitionDialogueObserved = False",
    "Bool JM_SOSReassertPending = False",
    "Actor JM_SOSReassertActor = None",
    "Float JM_SOSReassertDeadlineReal = -9999.0",
    "live SSS dialogue verified for actor=",
    "BeginEncounter(candidate)",
    "JM_TryCommitPendingFromActivePlayerThread()",
):
    assert required in controller, f"missing save-compatible controller invariant: {required}"

assert "waiting for original SSS acceptance fragment" not in controller

print("SSS recovery source invariants PASS")
