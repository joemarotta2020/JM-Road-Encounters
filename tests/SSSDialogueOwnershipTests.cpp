#include "../src/SSSEligibilityPolicy.h"

using JM::RoadEncounters::Eligibility::ShouldAcceptSSSDialogueCommit;

static_assert(ShouldAcceptSSSDialogueCommit(false, true, true),
    "SSS-owned INFO from the reserved speaker must commit.");

// Regression: the original SSS force-greet can open a dialogue where Skyrim's
// MenuTopicManager does not expose an SSS-owned currentTopicInfo at the instant
// JM polls it.  A reserved speaker already running an authoritative SSS approach
// package is sufficient encounter ownership and must commit even when the INFO
// pointer/owner is unavailable.
static_assert(ShouldAcceptSSSDialogueCommit(false, true, false),
    "Reserved speaker with authoritative SSS package ownership must commit even without SSS topic ownership.");

static_assert(!ShouldAcceptSSSDialogueCommit(true, true, true),
    "Foreign JM RE ownership must still veto the commit.");
static_assert(!ShouldAcceptSSSDialogueCommit(false, false, true),
    "A different dialogue speaker must never commit the reserved SSS encounter.");

int main()
{
    return 0;
}
