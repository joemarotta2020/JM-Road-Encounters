# Production invariant audit; changing this comment intentionally triggers a canonical build.
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

cats=['ROGUE','REFUGEE','PILGRIM','VIGILANT','MERCHANT','MAGICIAN','BOUNTY_HUNTER','HYDRA_CARAVAN','HYDRA_SACRED_BAND','IMMERSIVE_WENCH','ASSASSIN','KNIGHT','MERCENARY','FAITH','ADVENTURER','HYDRA_SLAVER']
for cat in cats:
    ck(f'CATEGORY_{cat}' in core,'missing category '+cat)
for cat,num in [('ROGUE',1),('REFUGEE',2),('PILGRIM',3),('VIGILANT',4),('MERCHANT',5),('MAGICIAN',6),('BOUNTY_HUNTER',7),('HYDRA_CARAVAN',8),('HYDRA_SACRED_BAND',9),('IMMERSIVE_WENCH',10),('ASSASSIN',11),('KNIGHT',12),('MERCENARY',13),('FAITH',14),('ADVENTURER',15),('HYDRA_SLAVER',16)]:
    ck(f'Int CATEGORY_{cat} = {num}' in core,'category ID changed '+cat)

catblock=core[core.find('Int Function GetEncounterCategory'):core.find('Bool Function IsLiveCategoryConfigured')]
for token in ['ROLE_ASSASSIN','ROLE_WANDERING_KNIGHT','ROLE_MERCENARY_WIZARD','ROLE_MERCENARY_WARRIOR','ROLE_MERCENARY_MISSILE','ROLE_KNIGHT_OF_FAITH','CATEGORY_ADVENTURER','CATEGORY_HYDRA_SLAVER','ROLE_MERCHANT_BODYGUARD']:
    ck(token in catblock,'missing category mapping '+token)

canobserve=core[core.find('Bool Function CanObserve'):core.find('EndFunction',core.find('Bool Function CanObserve'))]
ck('If !ProviderLoaded\n\t\tReturn False' not in canobserve,'PLRP remains master provider gate')
usable=core[core.find('Bool Function IsUsableCandidate'):core.find('EndFunction',core.find('Bool Function IsUsableCandidate'))]
ck('IsPlayerTeammate()' in usable,'followers/teammates can independently trigger')

cfg=core[core.find('Bool Function IsLiveCategoryConfigured'):core.find('Float Function GetCategoryNextRollDay')]
ck('Message != None' not in cfg,'optional Message binding suppresses force-greet eligibility')
start=core[core.find('Bool Function CanStartDirectEncounter'):core.find('EndFunction',core.find('Bool Function CanStartDirectEncounter'))]
ck('Message != None' not in start and 'GetItemCount' not in start,'follow-up prerequisite suppresses force-greet action')

hours=core[core.find('Float Function GetHoursSinceSuccessfulEncounter'):core.find('Event OnUpdateGameTime')]
ck('Return GuaranteedEncounterHours' in hours,'first contact time gate')
chance=core[core.find('Float Function GetCadenceOpportunityChance'):core.find('Float Function GetOpportunityRadiusForCategory')]
ck('If !HasSuccessfulEncounter\n\t\tReturn 100.0' in chance,'first contact chance gate')

ck('0x000B3292' in plrp and 'IsInFaction(vigilantFaction)' in plrp,'Vigilant not faction-classified')
ck('Return 7' in plrp,'generic adventurer still discarded')
ck('Return 4' in hydra,'unknown caravan faction members discarded')
ck('Bool Function IsOtherSlaver' in hydra and 'GetSlaverFaction' in hydra,'other Hydra slavers not structurally classified')
ck('0x0020D4D5' in wench and 'IsInFaction(' in wench,'Wench not faction-classified')
ck('GetName()' not in wench,'Wench classifier depends on display name')

ck('apply_jm_re_forcegreet.py' not in workflow,'CI still overwrites canonical Core')
for pex in ['JM_RE_Core.pex','JM_RE_Native.pex','JM_RE_PLRPProvider.pex','JM_RE_HydraProvider.pex','JM_RE_ImmersiveWenchesProvider.pex']:
    ck(not workflow or pex in workflow,'CI does not require '+pex)

ck(core.count('HasSuccessfulEncounter = True')==1,'HasSuccessfulEncounter must have exactly one true writer')
ck(core.count('LastSuccessfulEncounterDay = afNowDay')==1,'success timestamp must have exactly one runtime writer')
onopen=core[core.find('Event OnMenuOpen'):core.find('EndEvent',core.find('Event OnMenuOpen'))+8]
ck('IsJM_RE_ForceGreetPackageActive' in onopen,'OnMenuOpen must verify JM RE target package before cadence commit')
ck('GetEncounterSpeakerPriority' in core,'group speaker priority helper missing')

native=core[core.find('Bool Function EvaluateNativeCandidatesIndexed'):core.find('Bool Function RunCurrentCellSearch')]
cell=core[core.find('Bool Function RunCurrentCellSearch'):core.find('Function RunFallbackSearch')]
fallback=core[core.find('Function RunFallbackSearch'):core.find('Bool Function CanStartDirectEncounter')]
ck('bestPriority' in native and 'bestActor' in native,'native scan does not arbitrate best group speaker')
ck('bestPriority' in cell,'current-cell scan does not arbitrate best group speaker')
ck('bestPriority' in fallback,'fallback scan does not arbitrate best group speaker')
ck('Bool Function CommitEncounter' in core,'CommitEncounter must return Bool')
ck('Bool Function RollCadenceOpportunity' in core,'RollCadenceOpportunity must return Bool')

resolver=core[core.find('Function ResolveJM_RE_ForceGreetAction'):core.find('EndFunction',core.find('Function ResolveJM_RE_ForceGreetAction'))]
for cat in ['CATEGORY_ASSASSIN','CATEGORY_KNIGHT','CATEGORY_MERCENARY','CATEGORY_FAITH','CATEGORY_ADVENTURER','CATEGORY_HYDRA_SLAVER']:
    ck(cat in resolver,'new category has no resolved action '+cat)

ck('Bool Int Function' not in core and 'EndIfEndFunction' not in core,'obvious malformed Papyrus syntax')
print('\n'.join('FAIL: '+x for x in fail))
print('JM_RE_AUDIT_FAILURES='+str(len(fail)))
sys.exit(1 if fail else 0)
