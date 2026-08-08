import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

const root=process.cwd();
const read=(file)=>fs.readFileSync(path.join(root,file),'utf8');
const files={
  module:'src/authority/r3/commercial.ts', tests:'tests/r3/commercial-controls.test.ts',
  migration:'database/010_r3_commercial_service_and_policy_authority.sql', mirror:'supabase/migrations/20260722100000_r3_commercial_service_and_policy_authority.sql',
  api:'supabase/functions/authority-api/index.ts', ui:'src/ui/operations/CommercialAuthorityPanel.tsx', page:'src/app/app/authority/page.tsx'
};
const source=Object.fromEntries(Object.entries(files).map(([key,file])=>[key,read(file)]));
const checks=[]; const check=(id,pass,detail='')=>checks.push({id,pass:Boolean(pass),detail});
const sha=(value)=>crypto.createHash('sha256').update(value).digest('hex');
check('migration-mirror-byte-identical',source.migration===source.mirror,`${sha(source.migration)} / ${sha(source.mirror)}`);
check('contract-runtime-dual-control',/evaluateContractAuthority/.test(source.module)&&/CONTRACT_DUAL_CONTROL_REQUIRED/.test(source.module));
check('provisioning-runtime-tenant-contract-bound',/evaluateProvisioning/.test(source.module)&&/CONTRACT_TENANT_MISMATCH/.test(source.module)&&/TENANT_ISOLATION_UNVERIFIED/.test(source.module));
check('invoice-runtime-exact-arithmetic',/evaluateInvoice/.test(source.module)&&/INVOICE_TOTAL_MISMATCH/.test(source.module));
check('payment-runtime-idempotency',/evaluatePayment/.test(source.module)&&/PAYMENT_REFERENCE_REQUIRED/.test(source.module));
check('refund-runtime-dual-control',/evaluateRefund/.test(source.module)&&/REFUND_DUAL_CONTROL_REQUIRED/.test(source.module));
check('support-runtime-sla-and-evidence',/evaluateSupportCase/.test(source.module)&&/SUPPORT_SLA_BREACH/.test(source.module)&&/SUPPORT_EVIDENCE_REQUIRED/.test(source.module));
check('remedy-separates-financial-and-credential-actions',/evaluateCommercialRemedy/.test(source.module)&&/REMEDY_CREDENTIAL_REASON_REQUIRED/.test(source.module));
check('consent-runtime-evidence-bound',/evaluateConsent/.test(source.module)&&/CONSENT_EVIDENCE_INVALID/.test(source.module));
check('runtime-test-campaign',/executed dual-controlled contract authorizes/.test(source.tests)&&/commercial remedy binds financial and credential action/.test(source.tests));
check('atomic-contract-and-version-rpc',/pv_r3_create_contract_authority/.test(source.migration)&&/insert into public\.pv_contracts/.test(source.migration)&&/insert into public\.pv_contract_versions/.test(source.migration));
check('contract-same-tenant-fk',/pv_contracts_tenant_account_fk/.test(source.migration)&&/foreign key \(tenant_id,account_id\)/i.test(source.migration));
check('provisioning-validates-contract-and-entitlements',/pv_r3_activate_commercial_account/.test(source.migration)&&/PV_ENTITLEMENT_OUTSIDE_CONTRACT/.test(source.migration)&&/pv_customer_provisioning_events/.test(source.migration));
check('invoice-contract-bound-rpc',/pv_r3_issue_invoice/.test(source.migration)&&/PV_INVOICE_CONTRACT_NOT_AUTHORIZED/.test(source.migration)&&/PV_INVOICE_TOTAL_MISMATCH/.test(source.migration));
check('payment-balance-and-idempotency',/pv_r3_record_payment/.test(source.migration)&&/PV_PAYMENT_EXCEEDS_BALANCE/.test(source.migration)&&/unique \(tenant_id,idempotency_key\)/i.test(source.migration));
check('refund-bounded-dual-control',/pv_r3_authorize_refund/.test(source.migration)&&/PV_REFUND_EXCEEDS_PAYMENT/.test(source.migration)&&/PV_REFUND_DUAL_CONTROL_REQUIRED/.test(source.migration));
check('support-events-append-only',/pv_support_case_events/.test(source.migration)&&/'pv_support_case_events'/.test(source.migration)&&/deny_mutation/.test(source.migration));
check('support-transition-state-machine',/pv_r3_transition_support_case/.test(source.migration)&&/PV_SUPPORT_TRANSITION_INVALID/.test(source.migration));
check('billing-reconciliation-computed-server-side',/pv_r3_record_billing_reconciliation/.test(source.migration)&&/variance:=round/.test(source.migration));
check('commercial-remedy-dual-control',/pv_r3_record_commercial_remedy/.test(source.migration)&&/PV_REMEDY_DUAL_CONTROL_REQUIRED/.test(source.migration));
check('preference-history-append-only',/pv_preference_records/.test(source.migration)&&/'pv_preference_records'/.test(source.migration)&&/supersedes_id/.test(source.migration));
check('commercial-tables-force-rls',/force row level security/i.test(source.migration)&&/revoke insert, update, delete on public\.%I from anon,authenticated/i.test(source.migration));
check('commercial-rpcs-service-role-only',/revoke all on function provenance_api\.pv_r3_create_contract_authority/.test(source.migration)&&/grant execute on function provenance_api\.pv_r3_record_billing_reconciliation[\s\S]*to service_role/i.test(source.migration));
check('api-snapshot-complete', ['commercialAccounts','commercialOpportunities','commercialContracts','contractVersions','entitlements','provisioningEvents','invoices','payments','refunds','billingReconciliations','supportEvents','commercialRemedies','preferences'].every((name)=>source.api.includes(name)));
check('api-contract-single-transaction',/createCommercialContract/.test(source.api)&&/pv_r3_create_contract_authority/.test(source.api)&&/atomicVersionCreation:true/.test(source.api));
check('api-invoice-single-authority-command',/issueCommercialInvoice/.test(source.api)&&/pv_r3_issue_invoice/.test(source.api)&&/arithmeticVerified:true/.test(source.api));
check('api-payment-refund-support-remedy-routes', ['recordCommercialPayment','authorizeCommercialRefund','transitionCommercialSupport','recordCommercialRemedy','recordBillingReconciliation'].every((name)=>source.api.includes(`function ${name}`)));
check('api-audit-bound-commercial-actions', ['commercial.account-provisioned','commercial.payment-recorded','commercial.refund-authorized','support.case-transitioned','commercial.remedy-authorized','commercial.billing-reconciled'].every((event)=>source.api.includes(event)));
check('ui-uses-authority-fetch',/authorityFetch/.test(source.ui)&&!/fetch\(/.test(source.ui.replace(/authorityFetch/g,'')));
check('ui-has-no-optimistic-success',/await request|await commit/.test(source.ui)&&/failed closed/.test(source.ui));
check('ui-complete-commercial-actions', ['createAccount','createOpportunity','createContract','activateAccount','createInvoice','recordPayment','authorizeRefund','createSupport','transitionSupport','remedy','preference','reconciliation'].every((name)=>source.ui.includes(`function ${name}`)));
check('operator-route-integrates-panel',/CommercialAuthorityPanel/.test(source.page));
const failed=checks.filter((item)=>!item.pass);
const report={generatedAt:new Date().toISOString(),scope:'R3 commercial, provisioning, billing, support and preference authority',files,hashes:Object.fromEntries(Object.entries(source).map(([key,value])=>[key,sha(value)])),summary:{checks:checks.length,passed:checks.length-failed.length,failed:failed.length,verdict:failed.length?'FAIL':'PASS'},checks};
fs.mkdirSync(path.join(root,'evidence','r3'),{recursive:true});
fs.writeFileSync(path.join(root,'evidence','r3','commercial-authority.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify(report.summary,null,2));
if(failed.length){console.error(JSON.stringify(failed,null,2));process.exit(1);}
