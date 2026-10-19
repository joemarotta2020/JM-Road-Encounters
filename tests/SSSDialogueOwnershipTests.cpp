#include "../src/SSSEligibilityPolicy.h"

using JM::RoadEncounters::Eligibility::ShouldAcceptSSSDialogueCommit;

static_assert(ShouldAcceptSSSDialogueCommit(false, true, true),
    "Exact reserved speaker on SSS-owned INFO must commit.");
static_assert(!ShouldAcceptSSSDialogueCommit(false, true, false),
    "Package/approach state without an SSS-owned INFO must never commit.");
static_assert(!ShouldAcceptSSSDialogueCommit(true, true, true),
    "Foreign JM RE ownership must veto the commit.");
static_assert(!ShouldAcceptSSSDialogueCommit(false, false, true),
    "A different dialogue speaker must never commit the reserved SSS encounter.");

int main()
{
    return 0;
}
