import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

const root = process.cwd();
const files = {
  base: 'database/001_phase4_operations.sql',
  r2: 'database/002_r8_1_production_authority.sql',
  r2Mirror: 'supabase/migrations/20260722000000_r8_1_production_authority.sql',
  r3: 'database/003_r3_full_corrective_authority.sql',
  r3Mirror: 'supabase/migrations/20260722030000_r3_full_corrective_authority.sql',
  r3Operational: 'database/004_r3_operational_completion.sql',
  r3OperationalMirror: 'supabase/migrations/20260722040000_r3_operational_completion.sql',
  r3Freshness: 'database/005_r3_freshness_regression.sql',
  r3FreshnessMirror: 'supabase/migrations/20260722050000_r3_freshness_regression.sql',
  r3Sandbox: 'database/006_r3_developer_sandbox_lifecycle.sql',
  r3SandboxMirror: 'supabase/migrations/20260722060000_r3_developer_sandbox_lifecycle.sql',
  r3Inquiry: 'database/007_r3_public_inquiry_delivery.sql',
  r3InquiryMirror: 'supabase/migrations/20260722070000_r3_public_inquiry_delivery.sql',
  r3Operations: 'database/008_r3_observability_delivery_and_exports.sql',
  r3OperationsMirror: 'supabase/migrations/20260722080000_r3_observability_delivery_and_exports.sql',
  r3ReviewerCustos: 'database/009_r3_reviewer_custos_and_evidence_quality.sql',
  r3ReviewerCustosMirror: 'supabase/migrations/20260722090000_r3_reviewer_custos_and_evidence_quality.sql',
  r3Commercial: 'database/010_r3_commercial_service_and_policy_authority.sql',
  r3CommercialMirror: 'supabase/migrations/20260722100000_r3_commercial_service_and_policy_authority.sql',
  terraform: 'infra/terraform/provider-boundaries/main.tf',
  custody: 'services/provider-boundaries/evidence-custody/handler.py',
  authorityApi: 'supabase/functions/authority-api/index.ts',
};
const read = (key) => fs.readFileSync(path.join(root, files[key]), 'utf8');
const base = read('base'); const r2 = read('r2'); const r2Mirror = read('r2Mirror');
const r3 = read('r3'); const r3Mirror = read('r3Mirror');
const r3Operational = read('r3Operational'); const r3OperationalMirror = read('r3OperationalMirror');
const r3Freshness = read('r3Freshness'); const r3FreshnessMirror = read('r3FreshnessMirror');
const r3Sandbox = read('r3Sandbox'); const r3SandboxMirror = read('r3SandboxMirror');
const r3Inquiry = read('r3Inquiry'); const r3InquiryMirror = read('r3InquiryMirror');
const r3Operations = read('r3Operations'); const r3OperationsMirror = read('r3OperationsMirror');
const r3ReviewerCustos = read('r3ReviewerCustos'); const r3ReviewerCustosMirror = read('r3ReviewerCustosMirror');
const r3Commercial = read('r3Commercial'); const r3CommercialMirror = read('r3CommercialMirror');
const combined = `${base}\n${r2}\n${r3}\n${r3Operational}\n${r3Freshness}\n${r3Sandbox}\n${r3Inquiry}\n${r3Operations}\n${r3ReviewerCustos}\n${r3Commercial}`;
const terraform = read('terraform'); const custody = read('custody'); const api = read('authorityApi');
const sha = (s) => crypto.createHash('sha256').update(s).digest('hex');
const checks = []; const check = (id, pass, detail='') => checks.push({id,pass:Boolean(pass),detail});
const tableNames = [...combined.matchAll(/create\s+table\s+(?:if\s+not\s+exists\s+)?(?:public\.)?([a-z0-9_]+)/gi)].map((m)=>m[1]);
const trustTables = [
  'pv_evidence_objects','pv_evidence_scan_receipts','pv_evidence_custody_events',
  'pv_reviewer_decisions','pv_conflict_clearances','pv_claim_validation_receipts',
  'pv_claim_validation_decisions','pv_custos_receipts','pv_signing_receipts',
  'pv_credentials','pv_credential_lifecycle_events','pv_mark_authorizations',
  'pv_authority_operations','pv_authority_events','pv_authority_receipts',
  'pv_credential_versions','pv_registry_versions','pv_registry_events'
];
const normalizedR2 = r2.replace(/\s+/g,' ').toLowerCase();
const normalizedR3 = r3.replace(/\s+/g,' ').toLowerCase();
const protectionLoop = normalizedR3.slice(normalizedR3.indexOf('-- remove generic authenticated mutation policies'), normalizedR3.indexOf('-- tenant-scoped read-only access'));
const protectedByLoopOrExplicit = (table) => protectionLoop.includes(`'${table}'`) || normalizedR3.includes(`alter table public.${table} enable row level security`);
const writesRevokedByLoopOrExplicit = (table) => protectionLoop.includes(`'${table}'`) || normalizedR3.includes(`revoke insert,update,delete on public.${table} from anon,authenticated`);

check('r2-mirror-byte-identical', r2===r2Mirror, `${sha(r2)} / ${sha(r2Mirror)}`);
check('r3-mirror-byte-identical', r3===r3Mirror, `${sha(r3)} / ${sha(r3Mirror)}`);
check('r3-operational-mirror-byte-identical', r3Operational===r3OperationalMirror, `${sha(r3Operational)} / ${sha(r3OperationalMirror)}`);
check('r3-freshness-mirror-byte-identical', r3Freshness===r3FreshnessMirror, `${sha(r3Freshness)} / ${sha(r3FreshnessMirror)}`);
check('r3-sandbox-mirror-byte-identical', r3Sandbox===r3SandboxMirror, `${sha(r3Sandbox)} / ${sha(r3SandboxMirror)}`);
check('r3-inquiry-mirror-byte-identical', r3Inquiry===r3InquiryMirror, `${sha(r3Inquiry)} / ${sha(r3InquiryMirror)}`);
check('r3-operations-mirror-byte-identical', r3Operations===r3OperationsMirror, `${sha(r3Operations)} / ${sha(r3OperationsMirror)}`);
check('r3-reviewer-custos-mirror-byte-identical', r3ReviewerCustos===r3ReviewerCustosMirror, `${sha(r3ReviewerCustos)} / ${sha(r3ReviewerCustosMirror)}`);
check('r3-commercial-mirror-byte-identical', r3Commercial===r3CommercialMirror, `${sha(r3Commercial)} / ${sha(r3CommercialMirror)}`);
check('commercial-contract-version-authority', /pv_contract_versions/.test(r3Commercial) && /CONTRACT_DUAL_CONTROL_REQUIRED/.test(r3Commercial) && /document_digest/.test(r3Commercial) && /product_codes/.test(r3Commercial));
check('commercial-tenant-bound-provisioning', /pv_r3_activate_commercial_account/.test(r3Commercial) && /PV_PROVISIONING_PREREQUISITE_FAILED/.test(r3Commercial) && /pv_customer_provisioning_events/.test(r3Commercial) && /foreign key \(tenant_id,account_id\)/i.test(r3Commercial));
check('commercial-payment-idempotency-and-balance', /pv_r3_record_payment/.test(r3Commercial) && /PV_PAYMENT_EXCEEDS_BALANCE/.test(r3Commercial) && /unique \(tenant_id,idempotency_key\)/i.test(r3Commercial));
check('commercial-refund-dual-control', /pv_r3_authorize_refund/.test(r3Commercial) && /PV_REFUND_DUAL_CONTROL_REQUIRED/.test(r3Commercial) && /PV_REFUND_EXCEEDS_PAYMENT/.test(r3Commercial));
check('commercial-support-append-only-transitions', /pv_support_case_events/.test(r3Commercial) && /pv_r3_transition_support_case/.test(r3Commercial) && /PV_SUPPORT_TRANSITION_INVALID/.test(r3Commercial) && /'pv_support_case_events'/.test(r3Commercial) && /create trigger %I_immutable/.test(r3Commercial));
check('commercial-remedy-separates-finance-credential-truth', /pv_r3_record_commercial_remedy/.test(r3Commercial) && /PV_REMEDY_CREDENTIAL_REASON_REQUIRED/.test(r3Commercial) && /dual_control_receipt_ids/.test(r3Commercial));
check('commercial-service-only-and-tenant-read', /revoke all on function provenance_api\.pv_r3_activate_commercial_account/i.test(r3Commercial) && /grant execute on function provenance_api\.pv_r3_record_billing_reconciliation[\s\S]*to service_role/i.test(r3Commercial) && /force row level security/i.test(r3Commercial));
check('reviewer-assignment-scope-and-workload', /pv_r3_assign_reviewer/.test(r3ReviewerCustos) && /PV_REVIEWER_NOT_ELIGIBLE/.test(r3ReviewerCustos) && /PV_REVIEWER_WORKLOAD_LIMIT/.test(r3ReviewerCustos) && /PV_DISTINCT_REVIEWER_REQUIRED/.test(r3ReviewerCustos));
check('reviewer-queue-claim-concurrency', /pv_r3_claim_reviewer_assignment/.test(r3ReviewerCustos) && /for update skip locked/i.test(r3ReviewerCustos) && /order by priority asc,due_at asc/i.test(r3ReviewerCustos));
check('reviewer-assignment-signed-completion', /pv_r3_complete_reviewer_assignment/.test(r3ReviewerCustos) && /PV_REVIEW_DECISION_RECEIPT_REQUIRED/.test(r3ReviewerCustos) && /decision_receipt_id/.test(r3ReviewerCustos) && /state='completed'/.test(r3ReviewerCustos));
check('custos-independent-reproduction-model', /pv_custos_runs/.test(r3ReviewerCustos) && /pv_custos_samples/.test(r3ReviewerCustos) && /pv_custos_reproductions/.test(r3ReviewerCustos) && /pv_custos_verdict_events/.test(r3ReviewerCustos));
check('custos-reproduction-and-verdict-append-only', /pv_custos_runs_immutable/.test(r3ReviewerCustos) && /pv_custos_samples_immutable/.test(r3ReviewerCustos) && /pv_custos_reproductions_immutable/.test(r3ReviewerCustos) && /pv_custos_verdict_events_immutable/.test(r3ReviewerCustos));
check('evidence-dedupe-tenant-bound', /primary key\(tenant_id,object_digest\)/i.test(r3ReviewerCustos) && /on conflict\(tenant_id,object_digest\)/i.test(r3ReviewerCustos) && /array_agg\(distinct x\)/i.test(r3ReviewerCustos));
check('evidence-redaction-dual-control-and-lineage', /PV_REDACTION_DERIVATIVE_LINEAGE_INVALID/.test(r3ReviewerCustos) && /PV_REDACTION_DUAL_CONTROL_REQUIRED/.test(r3ReviewerCustos) && /cardinality\(reviewer_identities\)>=2/i.test(r3ReviewerCustos));
check('reviewer-custos-evidence-service-only-rpcs', /revoke all on function provenance_api\.pv_r3_assign_reviewer/i.test(r3ReviewerCustos) && /grant execute on function provenance_api\.pv_r3_record_redaction_review[\s\S]*to service_role/i.test(r3ReviewerCustos));
check('notification-claim-retry-dlq-runtime', /pv_r3_claim_notifications/.test(r3Operations) && /pv_r3_complete_notification/.test(r3Operations) && /dead-letter/.test(r3Operations) && /for update skip locked/i.test(r3Operations));
check('notification-attempts-append-only', /pv_notification_attempts_immutable/.test(r3Operations) && /request_digest/.test(r3Operations) && /provider_receipt/.test(r3Operations));
check('audit-export-dual-control-encrypted-custody', /PV_AUDIT_EXPORT_DUAL_CONTROL_REQUIRED/.test(r3Operations) && /encrypted_object_reference/.test(r3Operations) && /encryption_key_id/.test(r3Operations) && /pv_audit_export_events_immutable/.test(r3Operations));
check('audit-export-service-only-rpcs', /pv_r3_request_audit_export/.test(r3Operations) && /pv_r3_claim_audit_exports/.test(r3Operations) && /pv_r3_complete_audit_export/.test(r3Operations) && /grant execute[\s\S]*to service_role/i.test(r3Operations));
check('service-health-and-alert-evidence', /pv_service_health_samples/.test(r3Operations) && /pv_alert_events/.test(r3Operations) && /trace_id/.test(r3Operations) && /receipt_id/.test(r3Operations));
check('freshness-append-only-and-launch-blocking', /pv_freshness_findings_immutable/.test(r3Freshness) && /PV_LAUNCH_BLOCKED_BY_STALE_EVIDENCE/.test(r3Freshness) && /security_invoker=true/.test(r3Freshness));
check('freshness-service-only-execution', /grant execute[\s\S]*to service_role/i.test(r3Freshness) && /revoke all[\s\S]*from public,anon,authenticated/i.test(r3Freshness));
check('sandbox-isolated-lifecycle', /environment='sandbox'/.test(r3Sandbox) && /PV_SANDBOX_OWNER_DENIED/.test(r3Sandbox) && /PV_SANDBOX_EXPIRY_INVALID/.test(r3Sandbox) && /deletion_receipt/.test(r3Sandbox));
check('sandbox-service-only-execution', /pv_r3_create_sandbox/.test(r3Sandbox) && /grant execute[\s\S]*to service_role/i.test(r3Sandbox));
check('inquiry-encrypted-immutable-and-atomic', /pv_public_inquiries_immutable/.test(r3Inquiry) && /encrypted_payload/.test(r3Inquiry) && /vault_receipt_id/.test(r3Inquiry) && /insert into public\.pv_notifications/i.test(r3Inquiry));
check('inquiry-rate-limited-service-only', /PV_INQUIRY_RATE_LIMITED/.test(r3Inquiry) && /grant execute[\s\S]*to service_role/i.test(r3Inquiry) && /revoke all on public\.pv_public_inquiries/i.test(r3Inquiry));
check('r3-operational-force-rls', /force row level security/i.test(r3Operational));
check('r3-operational-revokes-client-mutation', /revoke insert, update, delete[\s\S]*from anon, authenticated/i.test(r3Operational));
check('r3-operational-immutable-histories', /pv_audit_runs[\s\S]*pv_authority_key_lifecycle[\s\S]*pv_status_lists/i.test(r3Operational) && /deny_mutation/i.test(r3Operational));
check('r3-operational-locked-quota-and-batch-rpcs', /PV_QUOTA_EXCEEDED/.test(r3Operational) && /PV_BATCH_DUAL_CONTROL_REQUIRED/.test(r3Operational) && /for update/i.test(r3Operational));
check('canonical-tenant-key-type-consistent', !/tenant_id\s+uuid[^;\n]*references\s+public\.pv_tenants\(id\)/i.test(combined) && !/platform_tenant_id\s+uuid/i.test(combined) && !/p_tenant(?:_id)?\s+uuid/i.test(combined), 'pv_tenants.id is text across canonical migrations');
check('schema-inventory', new Set(tableNames).size >= 55, `${new Set(tableNames).size} unique tables`);
check('no-destructive-table-ddl', !/\b(drop\s+table|truncate\s+table|drop\s+schema)\b/i.test(combined));
check('pgcrypto-schema-qualified', !/(^|[^.a-z0-9_])digest\(/im.test(combined) && /extensions\.digest\(/.test(combined));
check('strict-environment-controls', /authoritative_issuance_enabled\s+boolean\s+not\s+null\s+default\s+false/i.test(r2) && /certification_marks_enabled\s+boolean\s+not\s+null\s+default\s+false/i.test(r2));
check('signed-activation-record-fields', ['release_commit','release_package_hash','infrastructure_version','database_migration_version','signing_key_id','signing_key_version','custos_authority_version','registry_version','approval_identities','activation_time','expires_at','rollback_authority','algorithm','signature'].every((v)=>r3.includes(v)));
check('receipt-key-registry', /pv_authority_key_registry/.test(r3) && /key_version/.test(r3) && /status/.test(r3));
check('receipt-replay-store', /pv_receipt_nonces/.test(r3) && /nonce/.test(r3));
check('receipt-cryptographic-fields', ['issuer_service','request_digest','response_digest','policy_version','algorithm','signature','expires_at'].every((v)=>r3.includes(v)));
check('table-specific-rls', trustTables.every((t)=>r3.includes(`'${t}'`) || new RegExp(`alter\\s+table\\s+public\\.${t}\\s+enable\\s+row\\s+level\\s+security`,'i').test(r3)) && /enable row level security/.test(r3));
check('trust-writes-revoked', trustTables.every((t)=>r3.includes(`'${t}'`) || new RegExp(`revoke[^;]*on\\s+public\\.${t}[^;]*authenticated`,'i').test(r3)) && /revoke insert,update,delete/.test(r3));
check('immutable-trust-triggers', ['pv_evidence_custody_events','pv_credential_versions','pv_registry_events','pv_authority_events'].every((t)=>r3.includes(`'${t}'`) || new RegExp(`on\\s+public\\.${t}`,'i').test(r3)) && /deny_mutation/.test(r3));
check('append-lock-and-unique-chain', normalizedR3.includes('pg_advisory_xact_lock') && /unique\s*\(credential_id\s*,\s*sequence\)/.test(normalizedR3) && /unique\s*\(aggregate_type\s*,\s*aggregate_id\s*,\s*sequence\)/.test(normalizedR2));
check('durable-workflow-states', ['DRAFT','EVIDENCE_COMPLETE','REVIEW_COMPLETE','CUSTOS_AUTHORIZED','SIGNING_PENDING','SIGNED','REGISTRY_PENDING','ACTIVE','FAILED','COMPENSATION_REQUIRED','REVOKED'].every((v)=>r3.includes(v)));
check('transactional-outbox', /pv_transactional_outbox/.test(r3) && /pv_r3_prepare_issuance/.test(r3) && /pv_r3_require_compensation/.test(r3));
check('atomic-finalization', /pv_r3_finalize_registry/.test(r3) && /revocationCapabilityConfirmed/.test(r3));
check('append-only-registry-history', /pv_registry_versions/.test(r3) && /pv_registry_events/.test(r3) && /previous_event_hash/.test(r3));
check('protocol-claim-engine', /pv_claim_protocols/.test(r3) && /pv_claim_validation_decisions/.test(r3));
check('structured-conflict-model', /pv_reviewer_relationships/.test(r3) && /pv_conflict_clearances/.test(r3) && /relationship_type/.test(r3));
check('category-l-24-controls', /L-001/.test(r3) && /L-024/.test(r3) && /pv_category_l_controls/.test(r3));
check('qr-nfc-custody', /pv_media_identifiers/.test(r3) && /pv_media_custody_events/.test(r3));
check('governed-parties', /pv_governed_parties/.test(r3) && /accreditation_scopes/.test(r3));
check('customer-zero-one', /pv_customer_acceptance/.test(r3) && /customer-zero/.test(r3) && /customer-one/.test(r3));
check('g1-g5-launch', /pv_launch_gates/.test(r3) && ['G1','G2','G3','G4','G5'].every((v)=>r3.includes(v)));
check('days-1-90-stabilization', /pv_stabilization_daily_controls/.test(r3) && /day integer/.test(r3));
check('mark-governance', /pv_mark_licenses/.test(r3) && /pv_mark_artwork_versions/.test(r3) && /pv_mark_usage_events/.test(r3));
check('webhook-queue-dlq', /pv_webhook_delivery_queue/.test(r3) && /pv_dead_letters/.test(r3) && /pv_r3_claim_webhook_deliveries/.test(r3));
check('object-lock-custody', /object_lock_enabled\s*=\s*true/.test(terraform) && /mode\s*=\s*"COMPLIANCE"/.test(terraform) && /VersionId/.test(custody) && /get_object_retention/.test(custody));
check('private-crown-jewel-lambdas', !/aws_lambda_function_url/.test(terraform) && !/authorization_type\s*=\s*"NONE"/.test(terraform) && /authorization\s*=\s*"AWS_IAM"/.test(terraform));
check('separate-service-kms-keys', /aws_kms_key"\s+"receipt"/.test(terraform) && /for_each\s*=\s*local\.receipt_services/.test(terraform));
check('remote-state-locking', /backend\s+"s3"/.test(terraform) && fs.existsSync(path.join(root,'infra/terraform/provider-boundaries/backend.hcl.example')));
check('application-immutable-upload-path', /\/v1\/uploads\/begin/.test(api) && /\/v1\/uploads\/finalize/.test(api) && !/x-upsert/i.test(api));
check('controlled-security-definer', [...r3.matchAll(/security\s+definer/gi)].length > 0 && /revoke\s+all\s+on\s+function/i.test(r3) && /set\s+search_path/i.test(r3));
check('authenticated-grants-narrow', !/grant\s+all\s+on\s+all\s+tables/i.test(combined));
check('foreign-key-targets-resolve', [...r3.matchAll(/references\s+public\.([a-z0-9_]+)/gi)].every((m)=>new Set(tableNames).has(m[1])), 'all R3 public FK targets exist');

const failed=checks.filter((c)=>!c.pass);
const report={generatedAt:new Date().toISOString(),scope:'R8.1 R3 PostgreSQL/Supabase migration, RLS, immutability, workflow and custody contract audit',files,hashes:{base:sha(base),r2:sha(r2),r3:sha(r3),r3Operational:sha(r3Operational),r3Freshness:sha(r3Freshness),r3Sandbox:sha(r3Sandbox),r3Inquiry:sha(r3Inquiry),r3Operations:sha(r3Operations),r3ReviewerCustos:sha(r3ReviewerCustos),r3Commercial:sha(r3Commercial)},summary:{checks:checks.length,passed:checks.length-failed.length,failed:failed.length,verdict:failed.length?'FAIL':'PASS'},checks};
fs.mkdirSync(path.join(root,'evidence','r3'),{recursive:true});
fs.writeFileSync(path.join(root,'evidence','r3','migration-contract.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify(report.summary,null,2));
if(failed.length){console.error(JSON.stringify(failed,null,2));process.exit(1);}
