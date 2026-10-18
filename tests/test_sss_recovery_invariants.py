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

# The pre-feature SSS controller behavior is locked. Do not carry forward the
# later watchdog/dialogue-state experiments into the recovery build.
assert "Int Property AcquisitionTimeoutTicks = 16 Auto Hidden" in controller
assert "AcquisitionDialogueObserved" not in controller
assert "live SSS dialogue verified for actor=" in controller
assert "BeginEncounter(candidate)" in controller
assert "waiting for original SSS acceptance fragment" not in controller

print("SSS recovery source invariants PASS")
