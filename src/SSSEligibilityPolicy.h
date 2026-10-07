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

    // Compile-time regression coverage for the policy that prevents talking
    // creature races (for example Skaven using the Riekling race) from ever
    // entering the SSS_Whoring acquisition path.
    static_assert(IsHumanoidSSSCandidateRace(true, false, false));
    static_assert(!IsHumanoidSSSCandidateRace(false, true, false));
    static_assert(!IsHumanoidSSSCandidateRace(false, false, true));
    static_assert(!IsHumanoidSSSCandidateRace(true, true, false));
    static_assert(!IsHumanoidSSSCandidateRace(true, false, true));
    static_assert(!IsHumanoidSSSCandidateRace(false, false, false));
}
