from pathlib import Path
import sys

path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("src/main.cpp")
text = path.read_text(encoding="utf-8")

marker = "JM_SSS_ORIGINAL_IDLE_API_V1"
if marker in text:
    print("Original-idle native API patch already applied")
    raise SystemExit(0)

anchor = '''        bool IsSSSWhoringPackageActive(
            RE::StaticFunctionTag*,
            RE::Actor* a_actor,
            std::int32_t a_aliasIndex)
'''
replacement = '''        // JM_SSS_ORIGINAL_IDLE_API_V1
        // Expose only the runtime exclusion decision needed by the original
        // SSS_WhoringIdle fragments. This does not select actors or fill aliases.
        bool IsSSSWhoringExcludedPapyrus(
            RE::StaticFunctionTag*,
            RE::Actor* a_actor)
        {
            return IsSSSWhoringExcluded(a_actor);
        }

''' + anchor
if text.count(anchor) != 1:
    raise SystemExit(f"native exclusion wrapper anchor count {text.count(anchor)}, expected 1")
text = text.replace(anchor, replacement, 1)

register_anchor = '''            a_vm->RegisterFunction(
                "IsSSSWhoringPackageActive",
                kScriptName,
                IsSSSWhoringPackageActive);
'''
register_replacement = '''            a_vm->RegisterFunction(
                "IsSSSWhoringExcluded",
                kScriptName,
                IsSSSWhoringExcludedPapyrus);
''' + register_anchor
if text.count(register_anchor) != 1:
    raise SystemExit(f"native exclusion registration anchor count {text.count(register_anchor)}, expected 1")
text = text.replace(register_anchor, register_replacement, 1)

path.write_text(text, encoding="utf-8", newline="\n")
print("Exposed in-memory SSS exclusion query to original idle fragments")
