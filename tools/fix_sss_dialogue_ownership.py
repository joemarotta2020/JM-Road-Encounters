from pathlib import Path
import sys

MARKER = "JM_SSS_DIALOGUE_OWNERSHIP_V2"

OLD_OWNERSHIP = '''            const bool jmReOwnsDialogue =
                jmReForceGreetQuest && jmReForceGreetQuest->IsRunning();
'''

NEW_OWNERSHIP = '''            // JM_SSS_DIALOGUE_OWNERSHIP_V2
            // JM_RE_ForceGreetQuest can remain running while the original
            // SSS_Whoring alias/package is legitimately driving the selected
            // actor.  Treat JM RE as foreign dialogue ownership only when the
            // reserved actor is NOT currently running one of the authoritative
            // SSS approach packages.  This preserves the Sacred Band / unrelated
            // JM RE veto without blocking legitimate SSS force-greets.
            const bool jmReForceGreetRunning =
                jmReForceGreetQuest && jmReForceGreetQuest->IsRunning();
            const bool sssApproachPackageActive =
                IsSSSWhoringPackageActiveImpl(a_actor, 0) ||
                IsSSSWhoringPackageActiveImpl(a_actor, 2) ||
                IsSSSWhoringPackageActiveImpl(a_actor, 3) ||
                IsSSSWhoringPackageActiveImpl(a_actor, 5);
            const bool jmReOwnsDialogue =
                jmReForceGreetRunning && !sssApproachPackageActive;
'''

OLD_REJECT = '''            if (jmReOwnsDialogue && speakerMatchesReservedActor && g_sssLogger) {
                g_sssLogger->info(
                    "rejected SSS dialogue commit: JM RE owns force-greet "
                    "speaker={} form=0x{:08X}",
                    a_actor->GetName(),
                    a_actor->GetFormID());
            }
'''

NEW_REJECT = '''            if (jmReOwnsDialogue && speakerMatchesReservedActor && g_sssLogger) {
                g_sssLogger->info(
                    "rejected SSS dialogue commit: foreign JM RE force-greet "
                    "speaker={} form=0x{:08X}",
                    a_actor->GetName(),
                    a_actor->GetFormID());
            }

            if (active && jmReForceGreetRunning && sssApproachPackageActive && g_sssLogger) {
                g_sssLogger->info(
                    "accepted SSS dialogue while JM RE force-greet quest is running: "
                    "authoritative SSS package owns speaker={} form=0x{:08X}",
                    a_actor->GetName(),
                    a_actor->GetFormID());
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

    if MARKER in text:
        print("SSS dialogue ownership V2 already applied")
        return 0

    text = replace_once(text, OLD_OWNERSHIP, NEW_OWNERSHIP, "ownership block")
    text = replace_once(text, OLD_REJECT, NEW_REJECT, "rejection log block")

    path.write_text(text, encoding="utf-8")
    print("Applied SSS dialogue ownership V2")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
