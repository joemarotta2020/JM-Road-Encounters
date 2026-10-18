from pathlib import Path
import sys

path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('src/main.cpp')
text = path.read_text(encoding='utf-8')

marker = 'JM_SSS_PLUGIN_LOCAL_RESOLVER_V1'
if marker in text:
    print('SSS plugin-local resolver patch already applied')
    raise SystemExit(0)

anchor = '''        bool IsSSSWhoringExcluded(RE::Actor* a_actor)\n        {\n            auto* base = a_actor ? a_actor->GetActorBase() : nullptr;\n            return g_sssWhoringExcludedActors && base &&\n                   g_sssWhoringExcludedActors->HasForm(base);\n        }\n\n        void LoadSSSWhoringExclusions()\n'''
replacement = '''        bool IsSSSWhoringExcluded(RE::Actor* a_actor)\n        {\n            auto* base = a_actor ? a_actor->GetActorBase() : nullptr;\n            return g_sssWhoringExcludedActors && base &&\n                   g_sssWhoringExcludedActors->HasForm(base);\n        }\n\n        // JM_SSS_PLUGIN_LOCAL_RESOLVER_V1\n        // CommonLibSSE-NG v3.7.0 LookupFormID() incorporates the light-plugin\n        // index field even for normal plugins on SE. Construct the runtime ID\n        // explicitly so INI plugin-local identities resolve exactly like\n        // Papyrus Game.GetFormFromFile(). Keep this helper private to the SSS\n        // exclusion loader so no established JM RE lookup behavior changes.\n        RE::TESForm* ResolveSSSExclusionForm(\n            RE::TESDataHandler* a_dataHandler,\n            std::uint32_t a_localFormID,\n            std::string_view a_plugin)\n        {\n            if (!a_dataHandler) {\n                return nullptr;\n            }\n\n            const auto* file = a_dataHandler->LookupModByName(a_plugin);\n            if (!file || file->compileIndex == 0xFF) {\n                return nullptr;\n            }\n\n            RE::FormID runtimeFormID = 0;\n            if (file->compileIndex == 0xFE) {\n                runtimeFormID = 0xFE000000u |\n                    (static_cast<RE::FormID>(file->smallFileCompileIndex) << 12) |\n                    (a_localFormID & 0x00000FFFu);\n            } else {\n                runtimeFormID =\n                    (static_cast<RE::FormID>(file->compileIndex) << 24) |\n                    (a_localFormID & 0x00FFFFFFu);\n            }\n\n            return RE::TESForm::LookupByID(runtimeFormID);\n        }\n\n        void LoadSSSWhoringExclusions()\n'''

if text.count(anchor) != 1:
    raise SystemExit(f'resolver insertion anchor count {text.count(anchor)}, expected 1')
text = text.replace(anchor, replacement, 1)

old = '''                auto* resolved = dataHandler->LookupForm<RE::TESForm>(\n                    parsed->localFormID, parsed->plugin);\n'''
new = '''                auto* resolved = ResolveSSSExclusionForm(\n                    dataHandler, parsed->localFormID, parsed->plugin);\n'''
if text.count(old) != 1:
    raise SystemExit(f'resolver call anchor count {text.count(old)}, expected 1')
text = text.replace(old, new, 1)

path.write_text(text, encoding='utf-8', newline='\n')
print('Applied deterministic SSS plugin-local resolver patch')
