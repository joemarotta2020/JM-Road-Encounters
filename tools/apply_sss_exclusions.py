from pathlib import Path
import sys

path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('src/main.cpp')
text = path.read_text(encoding='utf-8')

if 'JM_SSS_EXCLUSION_CONFIG_V1' in text:
    print('SSS exclusion source patch already applied')
    raise SystemExit(0)

repls = []

repls.append((
'#include "PCH.h"\n#include "SSSEligibilityPolicy.h"\n',
'#include "PCH.h"\n#include "SSSEligibilityPolicy.h"\n#include "SSSExclusionConfig.h"\n\n#include <fstream>\n'))

repls.append((
'        std::shared_ptr<spdlog::logger> g_sssLogger;\n\n        struct Candidate\n',
'''        std::shared_ptr<spdlog::logger> g_sssLogger;\n\n        // JM_SSS_EXCLUSION_CONFIG_V1\n        constexpr std::uint32_t kSSSWhoringExcludedActorsFormID = 0x00000805;\n        RE::BGSListForm* g_sssWhoringExcludedActors = nullptr;\n\n        bool IsSSSWhoringExcluded(RE::Actor* a_actor)\n        {\n            auto* base = a_actor ? a_actor->GetActorBase() : nullptr;\n            return g_sssWhoringExcludedActors && base &&\n                   g_sssWhoringExcludedActors->HasForm(base);\n        }\n\n        void LoadSSSWhoringExclusions()\n        {\n            auto* dataHandler = RE::TESDataHandler::GetSingleton();\n            if (!dataHandler) {\n                if (g_sssLogger) {\n                    g_sssLogger->error("SSS exclusion load failed: TESDataHandler unavailable");\n                }\n                return;\n            }\n\n            g_sssWhoringExcludedActors = dataHandler->LookupForm<RE::BGSListForm>(\n                kSSSWhoringExcludedActorsFormID, "JM_SSS_Overhaul.esp");\n            if (!g_sssWhoringExcludedActors) {\n                if (g_sssLogger) {\n                    g_sssLogger->warn(\n                        "SSS exclusion FormList JM_SSS_WhoringExcludedActors not found; "\n                        "config exclusions disabled");\n                }\n                return;\n            }\n\n            std::ifstream input("Data/SKSE/Plugins/JM_RoadEncounters.ini");\n            if (!input) {\n                if (g_sssLogger) {\n                    g_sssLogger->warn(\n                        "SSS exclusion config not found: Data/SKSE/Plugins/JM_RoadEncounters.ini");\n                }\n                return;\n            }\n\n            bool inSection = false;\n            std::uint32_t added = 0;\n            std::uint32_t ignored = 0;\n            std::string line;\n            while (std::getline(input, line)) {\n                auto view = SSSExclusionConfig::TrimView(line);\n                if (!view.empty() && static_cast<unsigned char>(view.front()) == 0xEF) {\n                    if (view.size() >= 3 &&\n                        static_cast<unsigned char>(view[1]) == 0xBB &&\n                        static_cast<unsigned char>(view[2]) == 0xBF) {\n                        view.remove_prefix(3);\n                        view = SSSExclusionConfig::TrimView(view);\n                    }\n                }\n                if (view.empty() || view.front() == ';' || view.front() == '#') {\n                    continue;\n                }\n                if (view.front() == '[' && view.back() == ']') {\n                    inSection = (view == "[SSSWhoringExclusions]");\n                    continue;\n                }\n                if (!inSection) {\n                    continue;\n                }\n\n                const auto equals = view.find('=');\n                if (equals == std::string_view::npos) {\n                    ++ignored;\n                    continue;\n                }\n                const auto key = SSSExclusionConfig::TrimView(view.substr(0, equals));\n                if (!key.starts_with("Form")) {\n                    continue;\n                }\n                auto value = SSSExclusionConfig::TrimView(view.substr(equals + 1));\n                const auto comment = value.find_first_of(";#");\n                if (comment != std::string_view::npos) {\n                    value = SSSExclusionConfig::TrimView(value.substr(0, comment));\n                }\n\n                const auto parsed = SSSExclusionConfig::ParsePluginFormValue(value);\n                if (!parsed) {\n                    ++ignored;\n                    if (g_sssLogger) {\n                        g_sssLogger->warn("ignored malformed SSS exclusion entry: {}", value);\n                    }\n                    continue;\n                }\n\n                auto* resolved = dataHandler->LookupForm<RE::TESForm>(\n                    parsed->localFormID, parsed->plugin);\n                if (!resolved) {\n                    ++ignored;\n                    if (g_sssLogger) {\n                        g_sssLogger->warn(\n                            "ignored unresolved SSS exclusion {}|0x{:06X}",\n                            parsed->plugin, parsed->localFormID);\n                    }\n                    continue;\n                }\n\n                RE::TESForm* baseForm = resolved;\n                if (auto* reference = resolved->As<RE::TESObjectREFR>()) {\n                    baseForm = reference->GetBaseObject();\n                }\n                auto* npc = baseForm ? baseForm->As<RE::TESNPC>() : nullptr;\n                if (!npc) {\n                    ++ignored;\n                    if (g_sssLogger) {\n                        g_sssLogger->warn(\n                            "ignored non-NPC SSS exclusion {}|0x{:06X}",\n                            parsed->plugin, parsed->localFormID);\n                    }\n                    continue;\n                }\n\n                if (!g_sssWhoringExcludedActors->HasForm(npc)) {\n                    g_sssWhoringExcludedActors->AddForm(npc);\n                    ++added;\n                }\n                if (g_sssLogger) {\n                    g_sssLogger->info(\n                        "SSS exclusion active: npc={} base=0x{:08X} source={}|0x{:06X}",\n                        npc->GetName(), npc->GetFormID(),\n                        parsed->plugin, parsed->localFormID);\n                }\n            }\n\n            if (g_sssLogger) {\n                g_sssLogger->info(\n                    "SSS exclusion config loaded: added={} ignored={}", added, ignored);\n            }\n        }\n\n        struct Candidate\n'''))

repls.append((
'                !a_actor->Is3DLoaded() || !IsSSSHumanoidCandidate(a_actor) ||\n                !IsSSSBiologicalFemaleCandidate(a_actor)) {\n',
'                !a_actor->Is3DLoaded() || IsSSSWhoringExcluded(a_actor) ||\n                !IsSSSHumanoidCandidate(a_actor) ||\n                !IsSSSBiologicalFemaleCandidate(a_actor)) {\n'))

repls.append((
'                return { -1, "none", "invalid" };\n            }\n\n            // Hard species boundary: SSS_Whoring is for humanoid NPC races.\n',
'                return { -1, "none", "invalid" };\n            }\n            if (IsSSSWhoringExcluded(a_actor)) {\n                return { -1, "config", "excluded" };\n            }\n\n            // Hard species boundary: SSS_Whoring is for humanoid NPC races.\n'))

repls.append((
'            std::int32_t rejectedInvalid = 0;\n            std::int32_t rejectedSpecies = 0;\n',
'            std::int32_t rejectedInvalid = 0;\n            std::int32_t rejectedExcluded = 0;\n            std::int32_t rejectedSpecies = 0;\n'))

repls.append((
'                if (reason == "invalid") {\n                    ++rejectedInvalid;\n                } else if (reason == "non-humanoid-race") {\n',
'                if (reason == "invalid") {\n                    ++rejectedInvalid;\n                } else if (reason == "excluded") {\n                    ++rejectedExcluded;\n                } else if (reason == "non-humanoid-race") {\n'))

repls.append((
'                    "(tested={}, invalid={}, species={}, biologicalSex={}, child={}, teammate={}, "\n                    "combat={}, hostile={}, cannotTalk={}, radius={:.0f})",\n                    scan,\n                    tested,\n                    rejectedInvalid,\n                    rejectedSpecies,\n',
'                    "(tested={}, invalid={}, excluded={}, species={}, biologicalSex={}, child={}, teammate={}, "\n                    "combat={}, hostile={}, cannotTalk={}, radius={:.0f})",\n                    scan,\n                    tested,\n                    rejectedInvalid,\n                    rejectedExcluded,\n                    rejectedSpecies,\n'))

repls.append((
'            if (!a_actor || !IsSSSHumanoidCandidate(a_actor) ||\n                !IsSSSBiologicalFemaleCandidate(a_actor)) {\n',
'            if (!a_actor || IsSSSWhoringExcluded(a_actor) ||\n                !IsSSSHumanoidCandidate(a_actor) ||\n                !IsSSSBiologicalFemaleCandidate(a_actor)) {\n'))

repls.append((
'            if (a_message->type == SKSE::MessagingInterface::kPostLoadGame ||\n                a_message->type == SKSE::MessagingInterface::kNewGame) {\n                JM::RoadEncounters::WakePapyrusScanner();\n            }\n',
'            if (a_message->type == SKSE::MessagingInterface::kDataLoaded) {\n                JM::RoadEncounters::LoadSSSWhoringExclusions();\n                return;\n            }\n\n            if (a_message->type == SKSE::MessagingInterface::kPostLoadGame ||\n                a_message->type == SKSE::MessagingInterface::kNewGame) {\n                JM::RoadEncounters::WakePapyrusScanner();\n            }\n'))

for old, new in repls:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'patch anchor count {count}, expected 1:\n{old[:160]}')
    text = text.replace(old, new, 1)

path.write_text(text, encoding='utf-8', newline='\n')
print('Applied JM SSS exclusion source patch')
