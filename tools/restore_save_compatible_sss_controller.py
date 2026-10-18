from pathlib import Path
import base64

parts = [Path(f"recovery/controller.b64.{i:02d}").read_text(encoding="utf-8").strip() for i in range(5)]
data = base64.b64decode("".join(parts))
out = Path("papyrus/JM_SSS_WhoringController.psc")
out.write_bytes(data)
text = data.decode("utf-8")
required = (
    "Int Property AcquisitionTimeoutTicks = 60 Auto Hidden",
    "Bool AcquisitionDialogueObserved = False",
    "Bool JM_SOSReassertPending = False",
    "live SSS dialogue verified for actor=",
    "BeginEncounter(candidate)",
)
for marker in required:
    if marker not in text:
        raise SystemExit(f"save-compatible controller missing marker: {marker}")
if "waiting for original SSS acceptance fragment" in text:
    raise SystemExit("broken wait-for-fragment controller was reconstructed")
print("Restored save-compatible SSS controller source")
