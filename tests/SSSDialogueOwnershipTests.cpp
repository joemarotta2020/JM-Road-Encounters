#include "../src/SSSEligibilityPolicy.h"

using JM::RoadEncounters::Eligibility::ShouldAcceptSSSDialogueCommit;

static_assert(ShouldAcceptSSSDialogueCommit(false, true, true, false),
    "SSS-owned INFO from the reserved speaker must commit.");

// Regression: the original SSS force-greet can open dialogue where Skyrim's
// MenuTopicManager does not expose an SSS-owned currentTopicInfo at the instant
// JM polls it. The exact reserved speaker running an authoritative original SSS
// approach package is still sufficient encounter ownership.
static_assert(ShouldAcceptSSSDialogueCommit(false, true, false, true),
    "Reserved speaker with authoritative SSS package ownership must commit even without SSS topic ownership.");

static_assert(!ShouldAcceptSSSDialogueCommit(false, true, false, false),
    "No SSS INFO and no authoritative SSS package must not commit.");
static_assert(!ShouldAcceptSSSDialogueCommit(true, true, true, true),
    "Foreign JM RE ownership must still veto the commit.");
static_assert(!ShouldAcceptSSSDialogueCommit(false, false, true, true),
    "A different dialogue speaker must never commit the reserved SSS encounter.");

int main()
{
    return 0;
}
