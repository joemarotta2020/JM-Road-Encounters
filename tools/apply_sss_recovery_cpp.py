from pathlib import Path
import sys

MARKER = 'JM_SSS_RECOVERY_V1'

def replace_once(text, old, new, label):
    n=text.count(old)
    if n != 1:
        raise RuntimeError(f'{label}: expected exactly one match, found {n}')
    return text.replace(old,new,1)

def main():
    root=Path(sys.argv[1]) if len(sys.argv)>1 else Path('.')
    mainp=root/'src/main.cpp'
    policyp=root/'src/SSSEligibilityPolicy.h'
    testp=root/'tests/SSSDialogueOwnershipTests.cpp'
    cpp=mainp.read_text(encoding='utf-8')
    if MARKER not in cpp:
        cpp=replace_once(cpp,
            'return ClassifySSSWhoringActorDetailed(a_actor).aliasIndex;',
            'return ClassifySSSWhoringActorExactImpl(a_actor);  // JM_SSS_RECOVERY_V1',
            'Papyrus classifier wrapper')
        old='''                ++tested;\n                const auto classification =\n                    ClassifySSSWhoringActorDetailed(actor);\n\n                if (classification.aliasIndex >= 0) {\n                    // Prefer explicit force-greet archetypes (guards/bandits)\n                    // over generic clients, while preserving nearest-first\n                    // ordering within each tier.\n                    if ((classification.aliasIndex == 3 ||\n                         classification.aliasIndex == 5) &&\n                        !fallbackSpecial) {\n                        fallbackSpecial = actor;\n                        fallbackSpecialClass = classification;\n                    } else if (classification.aliasIndex == 0 &&\n                               !fallbackGeneral) {\n                        fallbackGeneral = actor;\n                        fallbackGeneralClass = classification;\n                    }\n                    continue;\n                }\n\n                const std::string_view reason = classification.reason;\n                if (reason == "invalid") {\n                    ++rejectedInvalid;\n                } else if (reason == "excluded") {\n                    ++rejectedExcluded;\n                } else if (reason == "non-humanoid-race") {\n                    ++rejectedSpecies;\n                } else if (reason == "biological-male-or-unknown") {\n                    ++rejectedBiologicalSex;\n                } else if (reason == "child") {\n                    ++rejectedChild;\n                } else if (reason == "teammate") {\n                    ++rejectedTeammate;\n                } else if (reason == "in-combat") {\n                    ++rejectedCombat;\n                } else if (reason == "hostile") {\n                    ++rejectedHostile;\n                } else if (reason == "cannot-talk") {\n                    ++rejectedCannotTalk;\n                }\n'''
        new='''                ++tested;\n                const auto exactAlias = ClassifySSSWhoringActorExactImpl(actor);\n\n                if (exactAlias >= 0) {\n                    const SSSClassificationResult classification{ exactAlias, "exact", "loaded-info" };\n                    // Preserve established preference only after Skyrim's loaded\n                    // SSS_WhoringIdle condition chain passes for this actor.\n                    if ((exactAlias == 3 || exactAlias == 5) &&\n                        !fallbackSpecial) {\n                        fallbackSpecial = actor;\n                        fallbackSpecialClass = classification;\n                    } else if ((exactAlias == 0 || exactAlias == 2) &&\n                               !fallbackGeneral) {\n                        fallbackGeneral = actor;\n                        fallbackGeneralClass = classification;\n                    }\n                    continue;\n                }\n\n                ++rejectedInvalid;\n'''
        cpp=replace_once(cpp,old,new,'candidate exact-condition selection')

        old='''            // JM_SSS_DIALOGUE_OWNERSHIP_V3\n            // The authoritative original SSS approach package is a valid\n            // ownership signal when Skyrim's MenuTopicManager does not expose\n            // an SSS-owned currentTopicInfo during the polling frame.  Exact\n            // reserved-speaker matching and the foreign-JM-RE veto still apply.\n            const bool active = Eligibility::ShouldAcceptSSSDialogueCommit(\n                jmReOwnsDialogue,\n                speakerMatchesReservedActor,\n                topicOwnedBySSS,\n                sssApproachPackageActive);\n\n            if (active && !topicOwnedBySSS && sssApproachPackageActive && g_sssLogger) {\n                g_sssLogger->info(\n                    "accepted SSS dialogue by authoritative package fallback: "\n                    "speaker={} form=0x{:08X}",\n                    a_actor->GetName(),\n                    a_actor->GetFormID());\n            }\n'''
        new='''            // JM_SSS_RECOVERY_V1: package state may disambiguate a stale/parallel\n            // JM RE quest, but it is never sufficient to commit SSS by itself.\n            // Commitment still requires the exact reserved speaker AND a live\n            // TopicInfo owned by SSS_Whoring.\n            const bool active = Eligibility::ShouldAcceptSSSDialogueCommit(\n                jmReOwnsDialogue,\n                speakerMatchesReservedActor,\n                topicOwnedBySSS);\n'''
        cpp=replace_once(cpp,old,new,'remove V3 package-only dialogue fallback')
        mainp.write_text(cpp,encoding='utf-8',newline='\n')
    else:
        print('main.cpp recovery marker already present')

    policy=policyp.read_text(encoding='utf-8')
    if 'a_authoritativeSSSPackageActive' in policy:
        start=policy.index('    constexpr bool ShouldAcceptSSSDialogueCommit(')
        end=policy.index('\n\n    // Compile-time regression coverage',start)
        fn='''    constexpr bool ShouldAcceptSSSDialogueCommit(\n        bool a_jmReOwnsDialogue,\n        bool a_speakerMatchesReservedActor,\n        bool a_topicOwnedBySSS) noexcept\n    {\n        return !a_jmReOwnsDialogue &&\n               a_speakerMatchesReservedActor &&\n               a_topicOwnedBySSS;\n    }'''
        policy=policy[:start]+fn+policy[end:]
        marker='    // Dialogue ownership invariants.'
        idx=policy.index(marker)
        section='''    // Dialogue ownership invariants. Package state may establish that a stale or\n    // parallel JM RE force-greet quest is not the owner, but package state alone\n    // never commits SSS. The exact reserved speaker must be on a live SSS-owned INFO.\n    static_assert(!ShouldAcceptSSSDialogueCommit(true, true, true));\n    static_assert(ShouldAcceptSSSDialogueCommit(false, true, true));\n    static_assert(!ShouldAcceptSSSDialogueCommit(false, true, false));\n    static_assert(!ShouldAcceptSSSDialogueCommit(false, false, true));\n'''
        policy=policy[:idx]+section+'}\n'
        policyp.write_text(policy,encoding='utf-8',newline='\n')
    else:
        print('SSS dialogue policy already strict-topic')

    test='''#include "../src/SSSEligibilityPolicy.h"\n\nusing JM::RoadEncounters::Eligibility::ShouldAcceptSSSDialogueCommit;\n\nstatic_assert(ShouldAcceptSSSDialogueCommit(false, true, true),\n    "Exact reserved speaker on SSS-owned INFO must commit.");\nstatic_assert(!ShouldAcceptSSSDialogueCommit(false, true, false),\n    "Package/approach state without an SSS-owned INFO must never commit.");\nstatic_assert(!ShouldAcceptSSSDialogueCommit(true, true, true),\n    "Foreign JM RE ownership must veto the commit.");\nstatic_assert(!ShouldAcceptSSSDialogueCommit(false, false, true),\n    "A different dialogue speaker must never commit the reserved SSS encounter.");\n\nint main()\n{\n    return 0;\n}\n'''
    testp.write_text(test,encoding='utf-8',newline='\n')
    print('Applied SSS C++ recovery: exact loaded INFO eligibility + no package-only commit')
    return 0

if __name__=='__main__':
    raise SystemExit(main())
