from pathlib import Path
import re, sys
root=Path(sys.argv[1])
cpp=(root/'src/main.cpp').read_text(encoding='utf-8')
policy=(root/'src/SSSEligibilityPolicy.h').read_text(encoding='utf-8')
ctl=(root/'papyrus/JM_SSS_WhoringController.psc').read_text(encoding='utf-8')
errors=[]
def req(c,m):
    if not c: errors.append(m)

# Exclusion and lifecycle fixes stay intact.
req('JM_SSS_EXCLUSION_CONFIG_V1' in cpp, 'exclusion loader missing')
req('JM_SSS_PLUGIN_LOCAL_RESOLVER_V1' in cpp, 'plugin-local resolver missing')
req('JM_SSS_QUEST_STARTUP_V1' in cpp, 'native quest startup reconciliation missing')

# Candidate selection must use the actual loaded SSS WhoringIdle INFO conditions.
m=re.search(r'std::int32_t ClassifySSSWhoringActor\([\s\S]*?\n\s*}\n\n\s*RE::Actor\* FindSSSWhoringActor', cpp)
req(m is not None,'classifier wrapper missing')
if m:
    req('ClassifySSSWhoringActorExactImpl(a_actor)' in m.group(0),'classifier wrapper not exact')
    req('ClassifySSSWhoringActorDetailed(a_actor)' not in m.group(0),'classifier wrapper still fallback')
m=re.search(r'RE::Actor\* FindSSSWhoringActor\([\s\S]*?\n\s*bool IsSSSWhoringPackageActive', cpp)
req(m is not None,'FindSSSWhoringActor missing')
if m:
    req('ClassifySSSWhoringActorExactImpl(actor)' in m.group(0),'scanner does not use exact INFO evaluator')
    req('ClassifySSSWhoringActorDetailed(actor)' not in m.group(0),'scanner still uses fallback classifier')
req('IsSSSWhoringExcluded(a_actor)' in cpp[cpp.find('ClassifySSSWhoringActorExactImpl'):cpp.find('SSSClassificationResult ClassifySSSWhoringActorDetailed')], 'exact classifier lost exclusions')

# Dialogue commitment: never accept package-only. Preserve the V2 stale/parallel JM RE
# handling, but require exact reserved speaker + live SSS-owned TopicInfo.
req('JM_SSS_DIALOGUE_OWNERSHIP_V2' in cpp,'V2 ownership disambiguation missing')
req('JM_SSS_DIALOGUE_OWNERSHIP_V3' not in cpp,'unsafe V3 package-only dialogue fallback still present')
req('accepted SSS dialogue by authoritative package fallback' not in cpp,'package-only acceptance log still present')
req('a_authoritativeSSSPackageActive' not in policy,'policy still accepts package-only ownership')
req('a_topicOwnedBySSS' in policy and 'a_speakerMatchesReservedActor' in policy,'strict topic/speaker policy missing')

# Controller must be known-working deterministic architecture plus restart self-heal.
m=re.search(r'Function NativeWakeScanner\(\)[\s\S]*?EndFunction', ctl)
req(m is not None,'NativeWakeScanner missing')
if m:
    req('If !IsRunning()' in m.group(0) and 'Start()' in m.group(0),'stopped quest self-heal missing')
m=re.search(r'Function JM_RunAcquisitionScan\(\)[\s\S]*?EndFunction', ctl)
req(m is not None,'JM_RunAcquisitionScan missing')
if m:
    s=m.group(0)
    req('FindSSSWhoringActor' in s,'native acquisition disabled')
    req('ForceRefTo(candidate)' in s,'original alias not force-filled')
    reservation=s[s.find('AcquisitionPending = True'):]
    req('JM_SetReady(True)' in reservation and reservation.find('JM_SetReady(True)') < reservation.find('candidate.EvaluatePackage()'),'ReadyGlobal not reopened before package evaluation')
    req('native acquisition disabled' not in s,'experimental native-disable path remains')
m=re.search(r'Function JM_UpdatePendingAcquisition\(\)[\s\S]*?EndFunction', ctl)
req(m is not None,'pending acquisition update missing')
if m:
    s=m.group(0)
    req('IsSSSWhoringDialogueActive(candidate)' in s and 'BeginEncounter(candidate)' in s,'verified dialogue no longer commits known-working encounter path')

for name in ['SSS_SoliciteforSex','SSS_AmuletSex','SSS_SoldierWhore','SSS_BanditApproach']:
    p=root/'papyrus'/f'{name}.psc'
    req(p.exists(),f'{name}.psc missing')
    if p.exists():
        t=p.read_text(encoding='utf-8')
        req('BeginEncounter(akSpeaker)' in t,f'{name}: original commit call missing')
        req('JM_TryReserveOriginalApproach' not in t,f'{name}: experimental reservation gate remains')

if errors:
    print('FAIL')
    for e in errors: print(' -',e)
    sys.exit(1)
print('PASS')
