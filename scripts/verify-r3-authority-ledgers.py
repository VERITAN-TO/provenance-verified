#!/usr/bin/env python3
import csv,json,sys
from pathlib import Path
root=Path(__file__).resolve().parents[1]
ledgers=root/'ledgers'
errors=[]
allowed={'NOT STARTED','IN PROGRESS','IMPLEMENTED','LOCALLY VERIFIED','STAGING VERIFIED','PRODUCTION VERIFIED','EXTERNALLY BLOCKED','FAILED','PASS'}
with (ledgers/'ORIGINAL_159_GAP_COMPLETION_REGISTER.csv').open(encoding='utf-8') as f: gaps=list(csv.DictReader(f))
if len(gaps)!=159: errors.append(f'gap count {len(gaps)} != 159')
if len({r['identifier'] for r in gaps})!=159: errors.append('gap identifiers not unique')
if sum(r['severity']=='P0' for r in gaps)!=54: errors.append('P0 count mismatch')
if sum(r['severity']=='P1' for r in gaps)!=104: errors.append('P1 count mismatch')
if sum(r['severity']=='P2' for r in gaps)!=1: errors.append('P2 count mismatch')
for r in gaps:
  if r['current_status'] not in allowed: errors.append(f"{r['identifier']} invalid status")
  for k in ['governing_source','implementation_location','service_or_module','test_evidence','current_status','remaining_dependency','final_verdict']:
    if not r[k].strip(): errors.append(f"{r['identifier']} missing {k}")
wo=json.loads((ledgers/'ORIGINAL_32_WORK_ORDER_COMPLETION_REGISTER.json').read_text())
if wo.get('count')!=32 or len(wo.get('work_orders',[]))!=32: errors.append('work-order count mismatch')
if len({r['id'] for r in wo['work_orders']})!=32: errors.append('work-order identifiers not unique')
with (ledgers/'R3_SURGICAL_DEFECT_CLOSURE_REGISTER.csv').open(encoding='utf-8') as f: defects=list(csv.DictReader(f))
if len(defects)!=20: errors.append('surgical defect count mismatch')
gates=json.loads((ledgers/'FIFTEEN_GATE_ACTIVATION_REGISTER.json').read_text())
if gates.get('count')!=15 or len(gates.get('gates',[]))!=15: errors.append('gate count mismatch')
result={'passed':not errors,'counts':{'gaps':len(gaps),'work_orders':len(wo['work_orders']),'defects':len(defects),'gates':len(gates['gates'])},'errors':errors}
(root/'evidence/r3/authority-ledger-verification.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
sys.exit(1 if errors else 0)
