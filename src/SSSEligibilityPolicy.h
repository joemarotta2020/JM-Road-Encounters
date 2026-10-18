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
        bool a_topicOwnedBySSS,
        bool a_authoritativeSSSPackageActive) noexcept
    {
        return !a_jmReOwnsDialogue &&
               a_speakerMatchesReservedActor &&
               (a_topicOwnedBySSS || a_authoritativeSSSPackageActive);
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

    // Dialogue ownership invariants. A foreign JM RE force-greet always vetoes
    // SSS cooldown commitment. Otherwise the exact reserved speaker may commit
    // either through an SSS-owned INFO or through the authoritative original SSS
    // approach package. The latter covers Skyrim frames where currentTopicInfo
    // is absent or reports a non-SSS owner while the real SSS force-greet is live.
    static_assert(!ShouldAcceptSSSDialogueCommit(true, true, true, true));
    static_assert(ShouldAcceptSSSDialogueCommit(false, true, true, false));
    static_assert(ShouldAcceptSSSDialogueCommit(false, true, false, true));
    static_assert(!ShouldAcceptSSSDialogueCommit(false, false, true, true));
    static_assert(!ShouldAcceptSSSDialogueCommit(false, true, false, false));
}
