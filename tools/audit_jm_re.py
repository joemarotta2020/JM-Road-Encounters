from pathlib import Path
import sys,re
root=Path(sys.argv[1]) if len(sys.argv)>1 else Path('.')
core=(root/'papyrus/JM_RE_Core.psc').read_text()
plrp=(root/'papyrus/JM_RE_PLRPProvider.psc').read_text()
hydra=(root/'papyrus/JM_RE_HydraProvider.psc').read_text()
wench=(root/'papyrus/JM_RE_ImmersiveWenchesProvider.psc').read_text()
workflow=(root/'.github/workflows/build-se.yml').read_text() if (root/'.github/workflows/build-se.yml').exists() else ''
fail=[]
def ck(cond,msg):
    if not cond: fail.append(msg)
for cat in ['ROGUE','REFUGEE','PILGRIM','VIGILANT','MERCHANT','MAGICIAN','BOUNTY_HUNTER','HYDRA_CARAVAN','HYDRA_SACRED_BAND','IMMERSIVE_WENCH','ASSASSIN','KNIGHT','MERCENARY','FAITH','ADVENTURER','HYDRA_SLAVER']:
    ck(f'CATEGORY_{cat}' in core,'missing category '+cat)
catblock=core[core.find('Int Function GetEncounterCategory'):core.find('Bool Function IsLiveCategoryConfigured')]
for token in ['ROLE_ASSASSIN','ROLE_WANDERING_KNIGHT','ROLE_MERCENARY_WIZARD','ROLE_MERCENARY_WARRIOR','ROLE_MERCENARY_MISSILE','ROLE_KNIGHT_OF_FAITH','CATEGORY_ADVENTURER','CATEGORY_HYDRA_SLAVER']:
    ck(token in catblock,'missing category mapping '+token)
ck('If !ProviderLoaded\n\t\tReturn False' not in core,'PLRP remains master provider gate')
cfg=core[core.find('Bool Function IsLiveCategoryConfigured'):core.find('Float Function GetCategoryNextRollDay')]
ck('Message != None' not in cfg,'message binding suppresses eligibility')
hours=core[core.find('Float Function GetHoursSinceSuccessfulEncounter'):core.find('Event OnUpdateGameTime')]
ck('Return GuaranteedEncounterHours' in hours,'first contact time gate')
chance=core[core.find('Float Function GetCadenceOpportunityChance'):core.find('Float Function GetOpportunityRadiusForCategory')]
ck('If !HasSuccessfulEncounter\n\t\tReturn 100.0' in chance,'first contact chance gate')
ck('0x000B3292' in plrp and 'IsInFaction(vigilantFaction)' in plrp,'Vigilant not faction-classified')
ck('Return 7' in plrp,'generic adventurer still discarded')
ck('Return 4' in hydra,'unknown caravan faction members discarded')
ck('Bool Function IsOtherSlaver' in hydra and not re.search(r'Bool Function IsOtherSlaver.*?Return False\s*EndFunction',hydra,re.S),'other Hydra slavers disabled')
ck('0x0020D4D5' in wench and 'IsInFaction(f)' in wench,'Wench not faction-classified')
ck('apply_jm_re_forcegreet.py' not in workflow,'CI still overwrites canonical Core')
for pex in ['JM_RE_Core.pex','JM_RE_Native.pex','JM_RE_PLRPProvider.pex','JM_RE_HydraProvider.pex','JM_RE_ImmersiveWenchesProvider.pex']:
    ck(not workflow or pex in workflow,'CI does not require '+pex)
ck(core.count('HasSuccessfulEncounter = True')==1,'HasSuccessfulEncounter must have exactly one true writer')
onopen=core[core.find('Event OnMenuOpen'):core.find('EndEvent',core.find('Event OnMenuOpen'))+8]
ck('IsJM_RE_ForceGreetPackageActive' in onopen,'OnMenuOpen must verify JM RE target package before cadence commit')
ck('GetEncounterSpeakerPriority' in core,'group speaker priority helper missing')
native=core[core.find('Function EvaluateNativeCandidatesIndexed'):core.find('Bool Function RunCurrentCellSearch')]
cell=core[core.find('Bool Function RunCurrentCellSearch'):core.find('Function RunFallbackSearch')]
ck('bestPriority' in native and 'bestActor' in native,'native scan does not arbitrate best group speaker')
ck('bestPriority' in cell,'current-cell scan does not arbitrate best group speaker')
ck('Bool Function CommitEncounter' in core,'CommitEncounter must return Bool')
ck('Bool Function RollCadenceOpportunity' in core,'RollCadenceOpportunity must return Bool')
print('\n'.join('FAIL: '+x for x in fail))
print('JM_RE_AUDIT_FAILURES='+str(len(fail)))
sys.exit(1 if fail else 0)
