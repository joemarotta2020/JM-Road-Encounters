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

    // Dialogue ownership invariant: an active JM RE force-greet always vetoes
    // SSS cooldown commitment, even when the visible dialogue INFO belongs to
    // SSS_Whoring. Normal SSS dialogue still requires the reserved speaker and
    // an INFO owned by the SSS_Whoring quest.
    static_assert(!ShouldAcceptSSSDialogueCommit(true, true, true));
    static_assert(ShouldAcceptSSSDialogueCommit(false, true, true));
    static_assert(!ShouldAcceptSSSDialogueCommit(false, false, true));
    static_assert(!ShouldAcceptSSSDialogueCommit(false, true, false));
}
