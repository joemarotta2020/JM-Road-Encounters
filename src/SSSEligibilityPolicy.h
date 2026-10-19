#pragma once

namespace JM::RoadEncounters::Eligibility
{
    constexpr bool IsHumanoidSSSCandidateRace(
        bool a_hasActorTypeNPC,
        bool a_hasActorTypeCreature,
        bool a_hasActorTypeAnimal) noexcept
    {
        return a_hasActorTypeNPC &&
               !a_hasActorTypeCreature &&
               !a_hasActorTypeAnimal;
    }

    constexpr bool IsBiologicalFemaleSSSCandidate(
        bool a_hasActorBase,
        int a_baseSex) noexcept
    {
        return a_hasActorBase && a_baseSex == 1;
    }

    constexpr bool ShouldAcceptSSSDialogueCommit(
        bool a_jmReOwnsDialogue,
        bool a_speakerMatchesReservedActor,
        bool a_topicOwnedBySSS) noexcept
    {
        return !a_jmReOwnsDialogue &&
               a_speakerMatchesReservedActor &&
               a_topicOwnedBySSS;
    }

    // Compile-time regression coverage for the policy that prevents talking
    // creature races (for example Skaven using the Riekling race) from ever
    // entering the SSS_Whoring acquisition path.
    static_assert(IsHumanoidSSSCandidateRace(true, false, false));
    static_assert(!IsHumanoidSSSCandidateRace(false, true, false));
    static_assert(!IsHumanoidSSSCandidateRace(false, false, true));
    static_assert(!IsHumanoidSSSCandidateRace(true, true, false));
    static_assert(!IsHumanoidSSSCandidateRace(true, false, true));
    static_assert(!IsHumanoidSSSCandidateRace(false, false, false));

    // SSS_Whoring aggressors are biologically female ActorBases only.
    // SOS/SexLab role state must never turn a biological male into a candidate.
    static_assert(IsBiologicalFemaleSSSCandidate(true, 1));
    static_assert(!IsBiologicalFemaleSSSCandidate(true, 0));
    static_assert(!IsBiologicalFemaleSSSCandidate(false, 1));
    static_assert(!IsBiologicalFemaleSSSCandidate(true, -1));

    // Dialogue ownership invariants. Package state may establish that a stale or
    // parallel JM RE force-greet quest is not the owner, but package state alone
    // never commits SSS. The exact reserved speaker must be on a live SSS-owned INFO.
    static_assert(!ShouldAcceptSSSDialogueCommit(true, true, true));
    static_assert(ShouldAcceptSSSDialogueCommit(false, true, true));
    static_assert(!ShouldAcceptSSSDialogueCommit(false, true, false));
    static_assert(!ShouldAcceptSSSDialogueCommit(false, false, true));
}
