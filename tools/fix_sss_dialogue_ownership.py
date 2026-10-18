from pathlib import Path
import sys

MARKER_V2 = "JM_SSS_DIALOGUE_OWNERSHIP_V2"
MARKER_V3 = "JM_SSS_DIALOGUE_OWNERSHIP_V3"

OLD_ACTIVE = '''            const bool active = Eligibility::ShouldAcceptSSSDialogueCommit(
                jmReOwnsDialogue,
                speakerMatchesReservedActor,
                topicOwnedBySSS);
'''

NEW_ACTIVE = '''            // JM_SSS_DIALOGUE_OWNERSHIP_V3
            // The authoritative original SSS approach package is a valid
            // ownership signal when Skyrim's MenuTopicManager does not expose
            // an SSS-owned currentTopicInfo during the polling frame.  Exact
            // reserved-speaker matching and the foreign-JM-RE veto still apply.
            const bool active = Eligibility::ShouldAcceptSSSDialogueCommit(
                jmReOwnsDialogue,
                speakerMatchesReservedActor,
                topicOwnedBySSS,
                sssApproachPackageActive);

            if (active && !topicOwnedBySSS && sssApproachPackageActive && g_sssLogger) {
                g_sssLogger->info(
                    "accepted SSS dialogue by authoritative package fallback: "
                    "speaker={} form=0x{:08X}",
                    a_actor->GetName(),
                    a_actor->GetFormID());
            }
'''

OLD_VERIFIED = '''            if (active && g_sssLogger) {
                g_sssLogger->info(
                    "verified live SSS dialogue speaker={} form=0x{:08X} "
                    "topicInfo=0x{:08X}",
                    a_actor->GetName(),
                    a_actor->GetFormID(),
                    info->GetFormID());
            }
'''

NEW_VERIFIED = '''            if (active && g_sssLogger) {
                const auto topicInfoFormID = info ? info->GetFormID() : 0;
                g_sssLogger->info(
                    "verified live SSS dialogue speaker={} form=0x{:08X} "
                    "topicInfo=0x{:08X}",
                    a_actor->GetName(),
                    a_actor->GetFormID(),
                    topicInfoFormID);
            }
'''


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected exactly one match, found {count}")
    return text.replace(old, new, 1)


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: fix_sss_dialogue_ownership.py <src/main.cpp>", file=sys.stderr)
        return 2

    path = Path(sys.argv[1])
    text = path.read_text(encoding="utf-8")

    if MARKER_V3 in text:
        print("SSS dialogue ownership V3 already applied")
        return 0

    if MARKER_V2 not in text:
        raise RuntimeError("SSS dialogue ownership V2 baseline marker not found")

    text = replace_once(text, OLD_ACTIVE, NEW_ACTIVE, "dialogue commit policy call")
    text = replace_once(text, OLD_VERIFIED, NEW_VERIFIED, "verified dialogue log")

    path.write_text(text, encoding="utf-8")
    print("Applied SSS dialogue ownership V3")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
