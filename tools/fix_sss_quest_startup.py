from pathlib import Path
import sys

MARKER = "JM_SSS_QUEST_STARTUP_V1"

ANCHOR = '''            if (!sssQuest) {
                if (g_sssLogger) {
                    g_sssLogger->info("SSS_Whoring not installed; native SSS wake skipped");
                }
                return;
            }

            const auto sssHandle = handlePolicy->GetHandleForObject(
'''

REPLACEMENT = '''            if (!sssQuest) {
                if (g_sssLogger) {
                    g_sssLogger->info("SSS_Whoring not installed; native SSS wake skipped");
                }
                return;
            }

            // JM_SSS_QUEST_STARTUP_V1
            // The native acquisition controller is useless if the original
            // SSS_Whoring quest is Enabled/Stopped: its aliases/packages and
            // dialogue remain dormant even though a bound controller script may
            // still be dispatchable.  Reconcile that lifecycle invariant before
            // waking acquisition.  Preserve intentional terminal completion by
            // never restarting stage 200+.
            if (!sssQuest->IsRunning()) {
                const auto stage = sssQuest->GetCurrentStageID();
                if (stage >= 200) {
                    if (g_sssLogger) {
                        g_sssLogger->info(
                            "SSS_Whoring is stopped at terminal stage {}; native SSS wake skipped",
                            stage);
                    }
                    return;
                }

                const bool started = sssQuest->Start();
                if (g_sssLogger) {
                    g_sssLogger->info(
                        "SSS_Whoring startup reconciliation: wasRunning=false stage={} "
                        "Start()={} nowRunning={}",
                        stage,
                        started,
                        sssQuest->IsRunning());
                }
                if (!sssQuest->IsRunning()) {
                    if (g_sssLogger) {
                        g_sssLogger->error(
                            "SSS_Whoring startup reconciliation failed; acquisition wake skipped");
                    }
                    return;
                }
            }

            const auto sssHandle = handlePolicy->GetHandleForObject(
'''


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: fix_sss_quest_startup.py <src/main.cpp>", file=sys.stderr)
        return 2

    path = Path(sys.argv[1])
    text = path.read_text(encoding="utf-8")

    if MARKER in text:
        print("SSS quest startup reconciliation already applied")
        return 0

    count = text.count(ANCHOR)
    if count != 1:
        raise RuntimeError(f"startup anchor: expected exactly one match, found {count}")

    path.write_text(text.replace(ANCHOR, REPLACEMENT, 1), encoding="utf-8")
    print("Applied SSS quest startup reconciliation")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
