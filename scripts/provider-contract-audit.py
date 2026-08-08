#!/usr/bin/env python3
"""R3 isolated provider-boundary acceptance campaign.

Exercises the real provider handlers with deterministic AWS service doubles. The doubles
preserve IAM caller context, SigV4-bound headers, KMS signature verification, DynamoDB
conditional writes/transactions, S3 object versions/Object Lock, Secrets Manager config,
request replay, idempotency, and receipt replay. No provider handler is replaced.
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from io import BytesIO
from pathlib import Path
import base64
import copy
import hashlib
import importlib.util
import json
import os
import sys
import tempfile
import types
import uuid

ROOT = Path.cwd()
PROVIDERS = ROOT / "services" / "provider-boundaries"
OUT = ROOT / "evidence" / "r3" / "provider-contract-audit.json"
OUT.parent.mkdir(parents=True, exist_ok=True)
TENANT = "tenant-r3-acceptance"
CALLER = "arn:aws:sts::123456789012:assumed-role/provenance-orchestrator/r3-acceptance"
WORKLOAD = "supabase-authority-api"
WORKLOAD_KEY = "oidc-sts"


def stable(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def sha256(value):
    if isinstance(value, bytes):
        data = value
    elif isinstance(value, str):
        data = value.encode()
    else:
        data = stable(value).encode()
    return "sha256:" + hashlib.sha256(data).hexdigest()


class FakeClientError(Exception):
    def __init__(self, code, message="conditional failure"):
        super().__init__(message)
        self.response = {"Error": {"Code": code, "Message": message}}


class FakeBody:
    def __init__(self, value: bytes):
        self.value = value
        self.position = 0

    def read(self, size=-1):
        if size is None or size < 0:
            size = len(self.value) - self.position
        chunk = self.value[self.position : self.position + size]
        self.position += len(chunk)
        return chunk


class FakeKMS:
    def __init__(self):
        self.disabled = set()
        self.encrypt_keys = set()

    @staticmethod
    def _signature(key_id, message):
        return hashlib.sha256((str(key_id) + "::").encode() + bytes(message)).digest()

    def sign(self, KeyId, Message, **_kwargs):
        if KeyId in self.disabled:
            raise FakeClientError("KMSInvalidStateException")
        return {
            "Signature": self._signature(KeyId, Message),
            "ResponseMetadata": {"RequestId": "kms-sign-" + hashlib.sha256(bytes(Message)).hexdigest()[:12]},
        }

    def verify(self, KeyId, Message, Signature, **_kwargs):
        valid = KeyId not in self.disabled and bytes(Signature) == self._signature(KeyId, Message)
        return {
            "SignatureValid": valid,
            "ResponseMetadata": {"RequestId": "kms-verify-" + hashlib.sha256(bytes(Message)).hexdigest()[:12]},
        }

    def describe_key(self, KeyId):
        usage = "ENCRYPT_DECRYPT" if KeyId in self.encrypt_keys or "vault" in str(KeyId) else "SIGN_VERIFY"
        return {
            "KeyMetadata": {
                "Enabled": KeyId not in self.disabled,
                "KeyState": "Disabled" if KeyId in self.disabled else "Enabled",
                "KeyUsage": usage,
                "Arn": str(KeyId),
            }
        }

    def encrypt(self, KeyId, Plaintext, EncryptionContext=None, **_kwargs):
        self.encrypt_keys.add(KeyId)
        envelope = stable({
            "key": KeyId,
            "context": EncryptionContext or {},
            "plaintext": base64.b64encode(bytes(Plaintext)).decode(),
        }).encode()
        return {
            "CiphertextBlob": b"PVKMS1:" + base64.b64encode(envelope),
            "KeyId": KeyId,
            "ResponseMetadata": {"RequestId": "kms-encrypt-local"},
        }

    def decrypt(self, KeyId, CiphertextBlob, EncryptionContext=None, **_kwargs):
        raw = bytes(CiphertextBlob)
        if not raw.startswith(b"PVKMS1:"):
            raise FakeClientError("InvalidCiphertextException")
        envelope = json.loads(base64.b64decode(raw[7:]))
        if envelope["key"] != KeyId or envelope["context"] != (EncryptionContext or {}):
            raise FakeClientError("InvalidCiphertextException")
        return {
            "Plaintext": base64.b64decode(envelope["plaintext"]),
            "KeyId": KeyId,
            "ResponseMetadata": {"RequestId": "kms-decrypt-local"},
        }


class FakeSecrets:
    def __init__(self):
        self.values = {}

    def get_secret_value(self, SecretId):
        if SecretId not in self.values:
            raise FakeClientError("ResourceNotFoundException")
        return {"SecretString": stable(self.values[SecretId])}


class FakeTable:
    def __init__(self, name):
        self.name = name
        self.items = {}

    def _key(self, value):
        if "scope" in value and "requestKey" in value:
            return value["scope"], value["requestKey"]
        if "tenantId" in value and "recordKey" in value:
            return value["tenantId"], value["recordKey"]
        if "publicId" in value and "sequence" in value:
            return value["publicId"], int(value["sequence"])
        if "publicId" in value and "credentialId" in value and "mark" in self.name:
            return value["publicId"], value["credentialId"]
        if "publicId" in value:
            return value["publicId"]
        if "tenantId" in value:
            return value["tenantId"]
        return tuple(sorted(value.items()))

    def get_item(self, Key, **_kwargs):
        item = self.items.get(self._key(Key))
        return {"Item": copy.deepcopy(item)} if item is not None else {}

    def put_item(self, Item, ConditionExpression=None, ExpressionAttributeValues=None, **_kwargs):
        key = self._key(Item)
        current = self.items.get(key)
        if ConditionExpression and "attribute_not_exists" in ConditionExpression and current is not None:
            raise FakeClientError("ConditionalCheckFailedException")
        if ConditionExpression and "latestSequence = :currentSequence" in ConditionExpression:
            values = ExpressionAttributeValues or {}
            if not current or current.get("latestSequence") != values.get(":currentSequence") or current.get("latestEventHash") != values.get(":currentHash"):
                raise FakeClientError("ConditionalCheckFailedException")
        self.items[key] = copy.deepcopy(Item)
        return {}

    def update_item(self, Key, ExpressionAttributeValues=None, **_kwargs):
        key = self._key(Key)
        item = self.items.setdefault(key, copy.deepcopy(Key))
        values = ExpressionAttributeValues or {}
        if ":completed" in values:
            item.update({
                "status": values.get(":completed"),
                "result": copy.deepcopy(values.get(":result")),
                "resultDigest": values.get(":digest"),
                "completedAt": values.get(":completedAt"),
            })
        else:
            for name, token in {
                "lifecycle": ":l", "updatedAt": ":u", "lifecycleReceiptId": ":r",
                "lifecycleReason": ":reason", "successorId": ":s",
            }.items():
                if token in values:
                    item[name] = copy.deepcopy(values[token])
        return {"Attributes": copy.deepcopy(item)}


class FakeDynamoResource:
    def __init__(self):
        self.tables = {}

    def Table(self, name):
        return self.tables.setdefault(name, FakeTable(name))


class FakeDynamoClient:
    def __init__(self, resource):
        self.resource = resource

    def transact_write_items(self, TransactItems, **_kwargs):
        staged = []
        for action in TransactItems:
            put = action["Put"]
            table = self.resource.Table(put["TableName"])
            item = copy.deepcopy(put["Item"])
            key = table._key(item)
            condition = put.get("ConditionExpression", "")
            current = table.items.get(key)
            if "attribute_not_exists" in condition and current is not None:
                raise FakeClientError("TransactionCanceledException")
            if "latestSequence = :previousSequence" in condition:
                values = put.get("ExpressionAttributeValues") or {}
                if not current:
                    raise FakeClientError("TransactionCanceledException")
                if (
                    current.get("latestSequence") != values.get(":previousSequence")
                    or current.get("latestEventHash") != values.get(":previousHash")
                    or current.get("tenantId") != values.get(":tenantId")
                ):
                    raise FakeClientError("TransactionCanceledException")
            staged.append((table, key, item))
        for table, key, item in staged:
            table.items[key] = item
        return {"ResponseMetadata": {"RequestId": "ddb-transaction-local"}}

    def query(self, TableName, ExpressionAttributeValues, **_kwargs):
        table = self.resource.Table(TableName)
        public_id = ExpressionAttributeValues.get(":publicId")
        if isinstance(public_id, dict):
            public_id = public_id.get("S")
        items = [copy.deepcopy(value) for key, value in table.items.items() if isinstance(key, tuple) and key[0] == public_id]
        items.sort(key=lambda value: int(value.get("sequence", 0)))
        return {"Items": items, "Count": len(items)}


class FakeS3:
    def __init__(self):
        self.objects = {}

    def seed(self, bucket, key, version, data, content_type="application/pdf", retention=None, legal_hold="OFF"):
        self.objects[(bucket, key, version)] = {
            "data": bytes(data), "ContentType": content_type,
            "retention": retention or {"Mode": "COMPLIANCE", "RetainUntilDate": datetime.now(timezone.utc) + timedelta(days=365)},
            "legalHold": {"Status": legal_hold},
        }

    def generate_presigned_url(self, _operation, Params, **_kwargs):
        return "https://custody.invalid/" + Params["Key"]

    def get_object(self, Bucket, Key, VersionId=None, **_kwargs):
        item = self.objects.get((Bucket, Key, VersionId))
        if item is None:
            raise FakeClientError("NoSuchKey")
        return {
            "Body": FakeBody(item["data"]), "ContentLength": len(item["data"]),
            "ContentType": item["ContentType"], "VersionId": VersionId,
        }

    def get_object_retention(self, Bucket, Key, VersionId=None):
        return {"Retention": copy.deepcopy(self.objects[(Bucket, Key, VersionId)]["retention"])}

    def get_object_legal_hold(self, Bucket, Key, VersionId=None):
        return {"LegalHold": copy.deepcopy(self.objects[(Bucket, Key, VersionId)]["legalHold"])}


class FakeTypeSerializer:
    def serialize(self, value):
        return copy.deepcopy(value)

class FakeTypeDeserializer:
    def deserialize(self, value):
        return copy.deepcopy(value)


class FakeAWS:
    def __init__(self):
        self.kms = FakeKMS()
        self.secrets = FakeSecrets()
        self.ddb = FakeDynamoResource()
        self.ddb_client = FakeDynamoClient(self.ddb)
        self.s3 = FakeS3()

    def client(self, name, **_kwargs):
        return {"kms": self.kms, "secretsmanager": self.secrets, "dynamodb": self.ddb_client, "s3": self.s3}[name]

    def resource(self, name, **_kwargs):
        if name != "dynamodb":
            raise KeyError(name)
        return self.ddb


AWS = FakeAWS()

# Install import-compatible AWS modules before loading the real handlers.
boto3_mod = types.ModuleType("boto3")
boto3_mod.client = AWS.client
boto3_mod.resource = AWS.resource
sys.modules["boto3"] = boto3_mod
botocore_mod = types.ModuleType("botocore")
botocore_exceptions = types.ModuleType("botocore.exceptions")
botocore_exceptions.ClientError = FakeClientError
botocore_mod.exceptions = botocore_exceptions
sys.modules["botocore"] = botocore_mod
sys.modules["botocore.exceptions"] = botocore_exceptions
boto3_ddb = types.ModuleType("boto3.dynamodb")
boto3_types = types.ModuleType("boto3.dynamodb.types")
boto3_types.TypeSerializer = FakeTypeSerializer
boto3_types.TypeDeserializer = FakeTypeDeserializer
sys.modules["boto3.dynamodb"] = boto3_ddb
sys.modules["boto3.dynamodb.types"] = boto3_types

SERVICES = {
    "activation-authority": ("pv-activation-authority", ["activation.synchronize", "activation.authorize-signing"]),
    "attestation-signer": ("pv-attestation-signer", ["attestation.sign"]),
    "canonical-authority": ("pv-canonical-authority", ["tenant.bootstrap", "canonical.claim.write", "canonical.assignment.write", "canonical.review.write", "canonical.credential.authorize", "canonical.credential.finalize"]),
    "claim-validator": ("pv-claim-validator", ["claim-validate"]),
    "conflict-engine": ("pv-conflict-engine", ["conflict-evaluate"]),
    "custos": ("pv-custos", ["custos-authorize"]),
    "evidence-custody": ("pv-evidence-custody", ["evidence.upload.begin", "evidence.upload.finalize", "evidence.custody.transfer"]),
    "evidence-eligibility": ("pv-evidence-eligibility", ["evidence-eligibility"]),
    "mark-authority": ("pv-mark-authority", ["mark.authorize"]),
    "registry": ("pv-registry", ["registry.write", "registry.rebuild"]),
    "reviewer-authority": ("pv-reviewer-authority", ["reviewer.decide"]),
    "scanner": ("pv-evidence-scanner", ["evidence.scan"]),
    "secret-vault": ("pv-secret-vault", ["secret.custody"]),
    "signer": ("pv-signer", ["credential-sign", "credential.verify"]),
}

POLICIES = {
    "pv-activation-authority": "activation-r3.1", "pv-attestation-signer": "attestation-r3.1",
    "pv-canonical-authority": "canonical-r3.1", "pv-claim-validator": "claim-protocol-r3.1",
    "pv-conflict-engine": "conflict-r3.1", "pv-custos": "custos-r3.1",
    "pv-evidence-custody": "custody-r3.1", "pv-evidence-eligibility": "eligibility-r3.1",
    "pv-mark-authority": "mark-r3.1", "pv-registry": "registry-r3.1",
    "pv-reviewer-authority": "reviewer-r3.1", "pv-evidence-scanner": "scanner-r3.1",
    "pv-secret-vault": "vault-r3.1", "pv-signer": "signer-r3.1",
}


def receipt_key(service_identity):
    return "arn:aws:kms:us-east-1:123456789012:key/receipt-" + service_identity


def config_for(service_identity, operations):
    trusted = {
        identity: {"keyId": receipt_key(identity), "keyVersion": 1, "status": "active"}
        for identity, _ops in SERVICES.values()
    }
    approvers = {
        "legal-approver": {"keyId": "kms-approver-legal", "status": "active"},
        "security-approver": {"keyId": "kms-approver-security", "status": "active"},
        "operations-approver": {"keyId": "kms-approver-operations", "status": "active"},
    }
    return {
        "allowedServiceIdentities": [WORKLOAD],
        "allowedCallerArns": [],
        "allowedCallerArnPrefixes": ["arn:aws:sts::123456789012:assumed-role/provenance-orchestrator/"],
        "allowedTenantIds": [TENANT],
        "allowedOperations": ["authority.health", *operations],
        "allowedWorkloadKeyIds": [WORKLOAD_KEY],
        "maximumReceiptLifetimeSeconds": 600,
        "receiptKeyVersion": 1,
        "policyVersion": POLICIES[service_identity],
        "trustedReceiptKeys": trusted,
        "allowedPolicyVersions": {identity: [POLICIES[identity]] for identity in POLICIES},
        "trustedActivationApproverKeys": approvers,
        "minimumActivationApprovals": 3,
    }


@dataclass
class LoadedProvider:
    slug: str
    service_identity: str
    handler: object
    authority: object
    environment: dict


PROVIDER_ENV = {
    "REQUEST_CONTROL_TABLE": "r3-request-control",
    "CANONICAL_TABLE_NAME": "r3-canonical",
    "CUSTOS_TABLE_NAME": "r3-custos-independent",
    "REGISTRY_EVENT_TABLE_NAME": "r3-registry-events",
    "REGISTRY_PROJECTION_TABLE_NAME": "r3-registry-projection",
    "REGISTRY_TABLE_NAME": "r3-registry-projection",
    "MARK_TABLE_NAME": "r3-mark-authorizations",
    "EVIDENCE_BUCKET_NAME": "r3-evidence-object-lock",
    "EVIDENCE_BUCKET": "r3-evidence-object-lock",
    "CREDENTIAL_KEY_ID": "kms-credential-signing-r3",
    "ATTESTATION_KEY_ID": "kms-attestation-signing-r3",
    "KEY_ID": "kms-vault-r3",
    "ENVIRONMENT": "pilot",
    "REGISTRY_READY": "true",
    "REVOCATION_READY": "true",
    "ALLOWED_CLOCK_SKEW_SECONDS": "120",
}


def load_provider(slug):
    service_identity, operations = SERVICES[slug]
    secret_id = "secret-config-" + slug
    AWS.secrets.values[secret_id] = config_for(service_identity, operations)
    provider_environment = {**PROVIDER_ENV,
        "SERVICE_IDENTITY": service_identity,
        "SERVICE_CONFIG_SECRET_ARN": secret_id,
        "RECEIPT_KEY_ID": receipt_key(service_identity),
    }
    os.environ.update(provider_environment)
    # Encryption keys are modeled separately from signing keys.
    AWS.kms.encrypt_keys.add(PROVIDER_ENV["KEY_ID"])
    authority_name = "_authority"
    sys.modules.pop(authority_name, None)
    auth_spec = importlib.util.spec_from_file_location(authority_name, PROVIDERS / slug / "_authority.py")
    authority = importlib.util.module_from_spec(auth_spec)
    sys.modules[authority_name] = authority
    assert auth_spec.loader
    auth_spec.loader.exec_module(authority)
    module_name = "pv_provider_" + slug.replace("-", "_") + "_" + uuid.uuid4().hex
    spec = importlib.util.spec_from_file_location(module_name, PROVIDERS / slug / "handler.py")
    module = importlib.util.module_from_spec(spec)
    assert spec.loader
    spec.loader.exec_module(module)
    return LoadedProvider(slug, service_identity, module, authority, provider_environment)


LOADED = {slug: load_provider(slug) for slug in SERVICES}


def operation_event(path, operation, subject, payload=None, *, idem=None, nonce=None, tenant=TENANT, service=WORKLOAD, caller=CALLER, timestamp=None):
    body = payload or {}
    request_digest = sha256(body)
    ts = timestamp or datetime.now(timezone.utc).isoformat()
    nonce = nonce or uuid.uuid4().hex
    idem = idem or uuid.uuid4().hex
    signed_headers = ";".join(sorted({
        "host", "x-amz-content-sha256", "x-amz-date", "x-pv-idempotency-key",
        "x-pv-nonce", "x-pv-operation", "x-pv-request-digest",
        "x-pv-service-identity", "x-pv-subject", "x-pv-tenant",
    }))
    return {
        "rawPath": path,
        "requestContext": {"http": {"method": "POST"}, "identity": {"userArn": caller}},
        "headers": {
            "host": "authority.internal.example",
            "authorization": "AWS4-HMAC-SHA256 Credential=LOCAL/acceptance, SignedHeaders=" + signed_headers + ", Signature=deterministic",
            "x-amz-date": datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ"),
            "x-amz-content-sha256": request_digest.split(":", 1)[1],
            "x-pv-service-identity": service,
            "x-pv-timestamp": ts,
            "x-pv-nonce": nonce,
            "x-pv-request-digest": request_digest,
            "x-pv-operation": operation,
            "x-pv-tenant": tenant,
            "x-pv-subject": subject,
            "x-pv-idempotency-key": idem,
            "x-pv-key-id": WORKLOAD_KEY,
        },
        "body": stable(body),
    }


def activate(slug):
    os.environ.update(LOADED[slug].environment)

def invoke(slug, path, operation, subject, payload=None, **kwargs):
    activate(slug)
    event = operation_event(path, operation, subject, payload, **kwargs)
    response = LOADED[slug].handler.handler(event, None)
    try:
        parsed = json.loads(response.get("body") or "{}")
    except Exception:
        parsed = {"raw": response.get("body")}
    return response["statusCode"], parsed, event


def expect(condition, message="assertion failed"):
    if not condition:
        raise AssertionError(message)


RESULTS = []


def test(name, fn):
    started = datetime.now(timezone.utc)
    try:
        fn()
        RESULTS.append({"name": name, "status": "pass", "durationMs": int((datetime.now(timezone.utc) - started).total_seconds() * 1000)})
    except Exception as exc:
        RESULTS.append({"name": name, "status": "fail", "error": f"{type(exc).__name__}: {exc}", "durationMs": int((datetime.now(timezone.utc) - started).total_seconds() * 1000)})


def call_ok(slug, path, operation, subject, payload=None, **kwargs):
    status, body, event = invoke(slug, path, operation, subject, payload, **kwargs)
    expect(status == 200, f"{slug} {path}: {status} {body}")
    return body, event


def approval_signature(key_id, record_digest):
    return base64.b64encode(AWS.kms.sign(KeyId=key_id, Message=bytes.fromhex(record_digest.split(":", 1)[1]))["Signature"]).decode()


# Every service requires IAM/SigV4 even for health.
for slug, (identity, _operations) in SERVICES.items():
    def health_test(slug=slug, identity=identity):
        body, _ = call_ok(slug, "/health", "authority.health", "health", {})
        expect(body["iamAuthenticated"] is True and body["staticBearerTokens"] is False, body)
        expect(body["serviceIdentity"] == identity, body)
    test(f"{slug}: authenticated health", health_test)

    def unauth_test(slug=slug):
        event = operation_event("/health", "authority.health", "health", {})
        event["headers"].pop("authorization")
        activate(slug)
        response = LOADED[slug].handler.handler(event, None)
        expect(response["statusCode"] == 403, response)
    test(f"{slug}: unauthenticated health denied", unauth_test)

# Tenant bootstrap and organization attestation.
tenant_result, _ = call_ok("canonical-authority", "/v1/tenants/bootstrap", "tenant.bootstrap", TENANT, {"tenantId": TENANT, "organizationId": "org-r3", "environment": "pilot"})
expect(tenant_result["status"] == "active")

attestation_payload = {"tenantId": TENANT, "signerId": "user-r3", "statement": "authorized organization attestation"}
attestation_digest = sha256(attestation_payload)
attestation, _ = call_ok("attestation-signer", "/v1/attestations/sign", "attestation.sign", "user-r3", {"payload": attestation_payload, "payloadDigest": attestation_digest, "purpose": "organization-attestation"})
test("attestation: non-exportable KMS signature", lambda: expect(attestation["nonExportableKey"] is True and attestation["payloadDigest"] == attestation_digest, attestation))

# Immutable custody -> scanner -> eligibility.
evidence_bytes = b"R3 immutable evidence bytes\n" * 32
evidence_digest = sha256(evidence_bytes)
evidence_id = "evidence-r3-1"
begin, _ = call_ok("evidence-custody", "/v1/uploads/begin", "evidence.upload.begin", evidence_id, {
    "evidenceId": evidence_id, "assetOrLotId": "asset-r3", "declaredSha256": evidence_digest,
    "byteSize": len(evidence_bytes), "mimeType": "application/pdf",
    "contentChecksumBase64": base64.b64encode(hashlib.sha256(evidence_bytes).digest()).decode(),
})
version = "version-r3-1"
AWS.s3.seed(begin["bucket"], begin["storageKey"], version, evidence_bytes)
custody, _ = call_ok("evidence-custody", "/v1/uploads/finalize", "evidence.upload.finalize", evidence_id, {
    "evidenceId": evidence_id, "storageKey": begin["storageKey"], "objectVersionId": version,
    "declaredSha256": evidence_digest, "mimeType": "application/pdf",
})
test("custody: full bytes and Object Lock confirmed", lambda: expect(custody["objectSha256"] == evidence_digest and custody["retentionMode"] == "COMPLIANCE" and custody["custodyContinuous"] is True, custody))

with tempfile.TemporaryDirectory() as td:
    scanner_path = Path(td) / "clamscan"
    scanner_path.write_text("#!/bin/sh\nexit 0\n")
    scanner_path.chmod(0o755)
    LOADED["scanner"].handler.CLAMSCAN = str(scanner_path)
    scan, _ = call_ok("scanner", "/v1/scan", "evidence.scan", evidence_id, {
        "storageKey": begin["storageKey"], "objectVersionId": version,
        "objectSha256": evidence_digest, "mimeType": "application/pdf",
    })
test("scanner: version-bound object passed", lambda: expect(scan["status"] == "PASSED" and scan["objectSha256"] == evidence_digest, scan))

eligibility, _ = call_ok("evidence-eligibility", "/v1/evaluate", "evidence-eligibility", evidence_id, {
    "evidence": {
        "bucket": begin["bucket"], "storageKey": begin["storageKey"], "objectVersion": version,
        "declaredSha256": evidence_digest, "declaredSize": len(evidence_bytes), "ownerId": "owner-r3",
        "assetOrLotId": "asset-r3", "claimIds": ["claim-r3"], "sourceAccredited": True,
        "custodyContinuous": True, "protocolEligible": True,
    },
    "scannerReceipt": scan["receipt"], "scannerServiceIdentity": SERVICES["scanner"][0],
})
test("eligibility: full digest and signed scanner receipt accepted", lambda: expect(eligibility["status"] == "eligible" and eligibility["computedSha256"] == evidence_digest, eligibility))

# Claim protocol and canonical claim custody.
review_case = "review-r3"
claim_body = {
    "claim": {"id": "claim-r3", "type": "origin", "tier": 4},
    "protocol": {
        "protocolId": "protocol-origin-r3", "version": "claim-protocol-r3.1", "claimType": "origin",
        "eligibleTiers": [4], "requiredEvidenceClasses": ["laboratory"], "maxEvidenceAgeDays": 365,
        "measurementRequirements": ["country", "mine"], "minimumEvidenceCount": 1,
        "accreditedSourcesRequired": True, "contradictionPolicy": "deny",
    },
    "evidence": [{
        "evidenceId": evidence_id, "eligible": True, "evidenceClass": "laboratory", "sourceAccredited": True,
        "capturedAt": datetime.now(timezone.utc).isoformat(), "measurementFields": ["country", "mine"],
        "supports": True, "contradicts": False, "objectSha256": evidence_digest,
        "eligibilityReceipt": eligibility["receipt"], "eligibilityServiceIdentity": SERVICES["evidence-eligibility"][0],
    }],
}
claim, _ = call_ok("claim-validator", "/v1/validate", "claim-validate", review_case, claim_body)
test("claim: versioned protocol passes", lambda: expect(claim["status"] == "pass" and claim["protocolVersion"] == "claim-protocol-r3.1", claim))
canonical_claim, _ = call_ok("canonical-authority", "/v1/claims/write", "canonical.claim.write", review_case, {
    "reviewCaseId": review_case, "claimId": "claim-r3", "claimReceipt": claim["receipt"], "claimDecision": claim,
})
test("canonical: claim receipt stored", lambda: expect(canonical_claim["status"] == "stored", canonical_claim))

# Two independently cleared reviewers, assignments, decisions and canonical review.
reviewer_receipts = []
reviewer_decisions = []
for stage, reviewer_id in (("primary", "reviewer-a"), ("secondary", "reviewer-b")):
    conflict, _ = call_ok("conflict-engine", "/v1/evaluate", "conflict-evaluate", review_case, {
        "reviewer": {"id": reviewer_id, "relationships": []},
        "case": {"submittingOrganizationId": "org-r3", "assetId": "asset-r3", "claimIds": ["claim-r3"], "accreditationScope": "origin"},
        "primaryReviewerId": "reviewer-a", "secondaryReviewerId": "reviewer-b",
    })
    expect(conflict["status"] == "clear", conflict)
    assignment, _ = call_ok("canonical-authority", "/v1/reviewer-assignments/write", "canonical.assignment.write", review_case, {
        "reviewCaseId": review_case, "reviewerId": reviewer_id, "reviewRound": 1, "stage": stage,
        "accreditationValid": True, "conflictReceipt": conflict["receipt"],
    })
    expect(assignment["status"] == "stored", assignment)
    decision, _ = call_ok("reviewer-authority", "/v1/decisions", "reviewer.decide", review_case, {
        "reviewCaseId": review_case, "reviewerId": reviewer_id, "reviewRound": 1, "stage": stage,
        "decision": "approve", "evidenceSetDigest": sha256([evidence_digest]),
        "conflictReceiptId": conflict["receipt"]["receiptId"],
    })
    expect(decision["status"] == "accepted", decision)
    reviewer_receipts.append(decision["receipt"])
    reviewer_decisions.append({"reviewerId": reviewer_id, "decision": "approve", "independent": True, "stage": stage})

credential_id = "credential-r3"
credential_version = 1
canonical_payload = {"credentialId": credential_id, "version": credential_version, "tier": 4, "claimId": "claim-r3"}
canonical_digest = sha256(canonical_payload)
canonical_review, _ = call_ok("canonical-authority", "/v1/reviews/write", "canonical.review.write", review_case, {
    "reviewCaseId": review_case,
    "reviewerReceipts": reviewer_receipts,
    "reviewerDecisions": reviewer_decisions,
    "canonicalPayload": canonical_payload,
    "canonicalPayloadDigest": canonical_digest,
    "actor": {"authenticated": True, "tenantId": TENANT, "actorId": "operator-r3"},
    "organizationActive": True, "registryReady": True, "revocationReady": True, "signingKeyEligible": True,
    "credentialId": credential_id, "credentialVersion": credential_version,
    "releasePackageHash": "sha256:" + "b" * 64, "evidenceIds": ["evidence-r3"],
})
test("canonical: two independent approvals stored", lambda: expect(canonical_review["status"] == "stored" and canonical_review["canonicalPayloadDigest"] == canonical_digest, canonical_review))

custos, _ = call_ok("custos", "/v1/authorize", "custos-authorize", credential_id, {
    "reviewCaseId": review_case, "credentialVersion": credential_version,
    "canonicalReviewReceipt": canonical_review["receipt"], "canonicalServiceIdentity": SERVICES["canonical-authority"][0],
    "canonicalPayloadDigest": canonical_digest,
})
test("CUSTOS: independent canonical facts authorized", lambda: expect(custos["status"] == "pass" and custos["canonicalPayloadDigest"] == canonical_digest and custos["sampleSize"] == 1, custos))
independent_custos_run = AWS.ddb.Table(PROVIDER_ENV["CUSTOS_TABLE_NAME"]).get_item(
    Key={"tenantId": TENANT, "recordKey": f"custos-run:{custos['runId']}"}, ConsistentRead=True
).get("Item")
test("CUSTOS: verdict persisted in independent store", lambda: expect(
    independent_custos_run and independent_custos_run["decision"] == "pass" and independent_custos_run["canonicalPayloadDigest"] == canonical_digest,
    independent_custos_run,
))
test("CUSTOS: deterministic sample and reproduction retained", lambda: expect(
    independent_custos_run["sampledEvidenceIds"] == custos["sampledEvidenceIds"]
    and independent_custos_run["reproducedPayloadDigest"] == canonical_digest
    and independent_custos_run["authoritativeFactsDigest"] == custos["authoritativeFactsDigest"],
    independent_custos_run,
))
canonical_authorized, _ = call_ok("canonical-authority", "/v1/credentials/authorize", "canonical.credential.authorize", credential_id, {
    "credentialId": credential_id, "credentialVersion": credential_version, "reviewCaseId": review_case,
    "custosReceipt": custos["receipt"], "custosServiceIdentity": SERVICES["custos"][0], "custosRunId": custos["runId"],
})
test("canonical: CUSTOS receipt creates signer-readable credential state", lambda: expect(canonical_authorized["state"] == "CUSTOS_AUTHORIZED", canonical_authorized))

# Signed G1-G5 production activation and credential-bound signing authorization.
activation_id = "activation-r3"
activation_record = {
    "id": activation_id, "environment": "production", "issuerIdentity": "provenance-cx-issuer",
    "releaseCommit": "a" * 40, "releasePackageHash": "sha256:" + "b" * 64,
    "infrastructureVersion": "infra-r3.1", "databaseMigrationVersion": "003-r3",
    "signingKeyId": PROVIDER_ENV["CREDENTIAL_KEY_ID"], "signingKeyVersion": 1,
    "custosAuthorityVersion": "custos-r3.1", "registryVersion": "registry-r3.1",
    "activationTime": (datetime.now(timezone.utc) - timedelta(minutes=1)).isoformat(),
    "expiresAt": (datetime.now(timezone.utc) + timedelta(hours=1)).isoformat(),
    "rollbackAuthority": "operations-approver", "keyCeremonyReference": "ceremony-r3",
    "gates": {f"G{i}": {"state": "approved", "evidenceFresh": True} for i in range(1, 6)},
}
activation_digest = sha256(activation_record)
activation_record["approvals"] = [
    {"identity": identity, "keyId": key_id, "algorithm": "ES256", "signature": approval_signature(key_id, activation_digest)}
    for identity, key_id in (
        ("legal-approver", "kms-approver-legal"),
        ("security-approver", "kms-approver-security"),
        ("operations-approver", "kms-approver-operations"),
    )
]
activation_sync, _ = call_ok("activation-authority", "/v1/records/synchronize", "activation.synchronize", activation_id, {"activationRecord": activation_record})
test("activation: G1-G5 approval quorum verified", lambda: expect(activation_sync["status"] == "active" and activation_sync["approvalCount"] == 3, activation_sync))
activation_auth, _ = call_ok("activation-authority", "/v1/signing-authorizations", "activation.authorize-signing", credential_id, {
    "releaseCommit": activation_record["releaseCommit"], "releasePackageHash": activation_record["releasePackageHash"],
    "infrastructureVersion": activation_record["infrastructureVersion"], "databaseMigrationVersion": activation_record["databaseMigrationVersion"],
    "signingKeyId": activation_record["signingKeyId"], "signingKeyVersion": 1,
    "custosAuthorityVersion": activation_record["custosAuthorityVersion"], "registryVersion": activation_record["registryVersion"],
    "canonicalPayloadDigest": canonical_digest,
})
test("activation: credential-bound signing authorization", lambda: expect(activation_auth["status"] == "authorized" and activation_auth["canonicalPayloadDigest"] == canonical_digest, activation_auth))

signed, _ = call_ok("signer", "/v1/sign", "credential-sign", credential_id, {
    "credentialVersion": credential_version, "canonicalPayloadDigest": canonical_digest,
    "authorizedKeyId": PROVIDER_ENV["CREDENTIAL_KEY_ID"], "authorizedKeyVersion": 1,
    "activationReceipt": activation_auth["receipt"], "activationAuthorization": activation_auth,
    "activationServiceIdentity": SERVICES["activation-authority"][0],
    "canonicalAuthorizationReceipt": canonical_authorized["receipt"],
    "canonicalAuthorizationReceiptId": canonical_authorized["receipt"]["receiptId"],
    "canonicalServiceIdentity": SERVICES["canonical-authority"][0],
})
test("signer: canonical digest signed by non-exportable key", lambda: expect(signed["status"] == "signed" and signed["nonExportableKey"] is True and signed["payloadDigest"] == canonical_digest, signed))
verified, _ = call_ok("signer", "/v1/verify", "credential.verify", credential_id, {
    "keyId": signed["keyId"], "payloadDigest": canonical_digest, "signature": signed["signature"],
})
test("signer: independent verification passes", lambda: expect(verified["valid"] is True, verified))

public_id = "PV-R3-0001"
registry, _ = call_ok("registry", "/v1/records/publish", "registry.write", credential_id, {
    "publicId": public_id, "credentialId": credential_id, "credentialVersion": credential_version,
    "credentialDigest": canonical_digest,
    "credential": {"tier": 4, "signature": {"payloadDigest": canonical_digest, "signature": signed["signature"], "valid": verified["valid"]}},
    "signerReceipt": signed["receipt"], "signerServiceIdentity": SERVICES["signer"][0],
    "revocationCapabilityRequired": True,
})
test("registry: atomic event and projection publication", lambda: expect(registry["lifecycle"] == "ACTIVE" and registry["eventSequence"] == 1 and registry["revocationCapabilityConfirmed"] is True, registry))

finalized, _ = call_ok("canonical-authority", "/v1/credentials/finalize", "canonical.credential.finalize", credential_id, {
    "credentialId": credential_id, "credentialVersion": credential_version,
    "registryReceipt": registry["receipt"], "registryServiceIdentity": SERVICES["registry"][0],
})
test("canonical: registry receipt finalizes credential", lambda: expect(finalized["state"] == "ACTIVE", finalized))

mark_payload = {
    "publicId": public_id, "credentialId": credential_id, "credentialDigest": canonical_digest,
    "action": "authorize", "tier": 4, "credentialType": "provenance-verified",
    "issuingAuthority": "PROVENANCE.CX", "organizationLicense": "license-r3",
    "locationAuthorization": "location-r3", "artworkVersion": "art-r3.1",
    "permittedMedia": ["web", "qr", "nfc"], "permittedGeography": ["US"],
    "expiry": (datetime.now(timezone.utc) + timedelta(days=365)).isoformat(),
    "policyVersion": "mark-r3.1", "activationRecordDigest": activation_sync["recordDigest"],
}
mark, _ = call_ok("mark-authority", "/v1/marks/authorize", "mark.authorize", credential_id, mark_payload)
test("mark: active credential authorized separately", lambda: expect(mark["status"] == "AUTHORIZED" and mark["mediaSuppressed"] is False, mark))

lifecycle, _ = call_ok("registry", "/v1/records/lifecycle", "registry.write", credential_id, {
    "publicId": public_id, "credentialId": credential_id, "credentialVersion": credential_version,
    "credentialDigest": canonical_digest, "action": "revoke", "reason": "acceptance test",
})
test("registry: append-only revocation event", lambda: expect(lifecycle["lifecycle"] == "REVOKED" and lifecycle["eventSequence"] == 2, lifecycle))

rebuilt, _ = call_ok("registry", "/v1/projection/rebuild", "registry.rebuild", credential_id, {"publicId": public_id, "commit": False})
test("registry: independent projection rebuild", lambda: expect(rebuilt["consistent"] is True and rebuilt["eventCount"] == 2 and rebuilt["latestSequence"] == 2, rebuilt))

def registry_tamper_rebuild_test():
    events = AWS.ddb.Table(PROVIDER_ENV["REGISTRY_EVENT_TABLE_NAME"])
    item = events.items[(public_id, 2)]
    original = item["previousHash"]
    item["previousHash"] = "sha256:" + "0" * 64
    try:
        call_ok("registry", "/v1/projection/rebuild", "registry.rebuild", credential_id, {"publicId": public_id, "commit": False})
    except Exception as exc:
        expect("REGISTRY_CHAIN_INVALID" in str(exc) or "REGISTRY_EVENT_HASH_INVALID" in str(exc), str(exc))
        item["previousHash"] = original
        return
    item["previousHash"] = original
    raise AssertionError("tampered registry event accepted")
test("registry: rebuild rejects tampered chain", registry_tamper_rebuild_test)
mark_after_revoke, _ = call_ok("mark-authority", "/v1/marks/authorize", "mark.authorize", credential_id, mark_payload)
test("mark: revoked credential suppresses seal", lambda: expect(mark_after_revoke["status"] == "DENIED" and mark_after_revoke["mediaSuppressed"] is True, mark_after_revoke))

# KMS secret custody with encryption-context binding.
vault_body = {"endpointId": "webhook-r3", "purpose": "webhook-signing-secret", "plaintext": "S" * 48}
sealed, _ = call_ok("secret-vault", "/v1/seal", "secret.custody", "webhook-r3", vault_body)
opened, _ = call_ok("secret-vault", "/v1/open", "secret.custody", "webhook-r3", {"endpointId": "webhook-r3", "purpose": "webhook-signing-secret", "ciphertext": sealed["ciphertext"]})
test("vault: encryption context round trip", lambda: expect(opened["plaintext"] == "S" * 48 and sealed["nonExportableKey"] is True, opened))

# Transport, request replay, idempotency and tenant denial.
def request_replay_test():
    event = operation_event("/v1/attestations/sign", "attestation.sign", "user-replay", {"payload": {"tenantId": TENANT, "signerId": "user-replay"}, "payloadDigest": sha256({"tenantId": TENANT, "signerId": "user-replay"}), "purpose": "organization-attestation"})
    activate("attestation-signer")
    first = LOADED["attestation-signer"].handler.handler(event, None)
    activate("attestation-signer")
    second = LOADED["attestation-signer"].handler.handler(event, None)
    expect(first["statusCode"] == 200 and second["statusCode"] == 403 and json.loads(second["body"])["error"] == "REQUEST_REPLAYED", (first, second))
test("workload request: nonce replay denied", request_replay_test)


def idempotency_test():
    payload = {"payload": {"tenantId": TENANT, "signerId": "user-idem"}, "payloadDigest": sha256({"tenantId": TENANT, "signerId": "user-idem"}), "purpose": "organization-attestation"}
    idem = "idem-r3-fixed"
    first, _ = call_ok("attestation-signer", "/v1/attestations/sign", "attestation.sign", "user-idem", payload, idem=idem)
    second, _ = call_ok("attestation-signer", "/v1/attestations/sign", "attestation.sign", "user-idem", payload, idem=idem)
    expect(first == second, (first, second))
test("workload request: idempotency returns original result", idempotency_test)


def wrong_tenant_test():
    status, body, _ = invoke("attestation-signer", "/v1/attestations/sign", "attestation.sign", "user-x", {"payload": {"tenantId": "tenant-other", "signerId": "user-x"}, "payloadDigest": sha256({"tenantId": "tenant-other", "signerId": "user-x"}), "purpose": "organization-attestation"}, tenant="tenant-other")
    expect(status == 403 and body["error"] == "TENANT_DENIED", (status, body))
test("workload request: wrong tenant denied", wrong_tenant_test)

# Cryptographic receipt negative campaign using fresh attestation receipts.
def fresh_receipt(subject="receipt-subject"):
    payload = {"tenantId": TENANT, "signerId": subject}
    result, _ = call_ok("attestation-signer", "/v1/attestations/sign", "attestation.sign", subject, {"payload": payload, "payloadDigest": sha256(payload), "purpose": "organization-attestation"})
    return result["receipt"]


def verify_receipt_direct(receipt, expected_tenant=TENANT, expected_operation="attestation.sign", expected_subject="receipt-subject"):
    activate("canonical-authority")
    return LOADED["canonical-authority"].authority.verify_receipt(
        receipt, SERVICES["attestation-signer"][0], expected_tenant, expected_subject,
        expected_operation, receipt["requestDigest"], receipt["responseDigest"], ["attestation-r3.1"],
    )


def forged_receipt_test():
    receipt = fresh_receipt()
    receipt["signature"] = base64.b64encode(b"forged").decode()
    try:
        verify_receipt_direct(receipt)
    except PermissionError as exc:
        expect(str(exc) == "RECEIPT_SIGNATURE_INVALID", str(exc)); return
    raise AssertionError("forged receipt accepted")
test("receipt: forged signature denied", forged_receipt_test)


def wrong_receipt_tenant_test():
    receipt = fresh_receipt("receipt-tenant")
    activate("canonical-authority")
    try:
        LOADED["canonical-authority"].authority.verify_receipt(receipt, SERVICES["attestation-signer"][0], "other", "receipt-tenant", "attestation.sign", receipt["requestDigest"], receipt["responseDigest"], ["attestation-r3.1"])
    except PermissionError as exc:
        expect(str(exc) == "RECEIPT_WRONG_TENANT", str(exc)); return
    raise AssertionError("wrong tenant receipt accepted")
test("receipt: wrong tenant denied", wrong_receipt_tenant_test)


def wrong_receipt_operation_test():
    receipt = fresh_receipt("receipt-op")
    activate("canonical-authority")
    try:
        LOADED["canonical-authority"].authority.verify_receipt(receipt, SERVICES["attestation-signer"][0], TENANT, "receipt-op", "other.operation", receipt["requestDigest"], receipt["responseDigest"], ["attestation-r3.1"])
    except PermissionError as exc:
        expect(str(exc) == "RECEIPT_WRONG_OPERATION", str(exc)); return
    raise AssertionError("wrong operation receipt accepted")
test("receipt: wrong operation denied", wrong_receipt_operation_test)


def expired_receipt_test():
    receipt = fresh_receipt("receipt-expired")
    receipt["timestamp"] = (datetime.now(timezone.utc) - timedelta(minutes=10)).isoformat()
    receipt["expiresAt"] = (datetime.now(timezone.utc) - timedelta(minutes=5)).isoformat()
    activate("canonical-authority")
    try:
        LOADED["canonical-authority"].authority.verify_receipt(receipt, SERVICES["attestation-signer"][0], TENANT, "receipt-expired", "attestation.sign", receipt["requestDigest"], receipt["responseDigest"], ["attestation-r3.1"])
    except PermissionError as exc:
        expect(str(exc) == "RECEIPT_EXPIRED", str(exc)); return
    raise AssertionError("expired receipt accepted")
test("receipt: expired receipt denied", expired_receipt_test)


def receipt_replay_test():
    receipt = fresh_receipt("receipt-replay")
    activate("canonical-authority")
    verifier = LOADED["canonical-authority"].authority
    verifier.verify_receipt(receipt, SERVICES["attestation-signer"][0], TENANT, "receipt-replay", "attestation.sign", receipt["requestDigest"], receipt["responseDigest"], ["attestation-r3.1"])
    try:
        verifier.verify_receipt(receipt, SERVICES["attestation-signer"][0], TENANT, "receipt-replay", "attestation.sign", receipt["requestDigest"], receipt["responseDigest"], ["attestation-r3.1"])
    except PermissionError as exc:
        expect(str(exc) == "RECEIPT_REPLAYED", str(exc)); return
    raise AssertionError("receipt replay accepted")
test("receipt: nonce replay denied", receipt_replay_test)

# Static independence evidence complements runtime handler execution.
terraform_text = (ROOT / "infra" / "terraform" / "provider-boundaries" / "main.tf").read_text()
custos_terraform = (ROOT / "infra" / "terraform" / "custos-independent" / "main.tf").read_text()
custos_variables = (ROOT / "infra" / "terraform" / "custos-independent" / "variables.tf").read_text()
custos_backend = (ROOT / "infra" / "terraform" / "custos-independent" / "backend.hcl.example").read_text()
custos_handler_text = (PROVIDERS / "custos" / "handler.py").read_text()
test("CUSTOS topology: excluded from primary deployable services", lambda: expect(
    'custos          = {' not in terraform_text
    and 'custos = ["custos-authorize"' not in terraform_text
    and 'resource "aws_dynamodb_table" "custos_store"' not in terraform_text
    and 'resource "aws_kms_key" "custos_store"' not in terraform_text,
    "CUSTOS still deploys inside the primary stack",
))
test("CUSTOS topology: separate account and Terraform state required", lambda: expect(
    'check "separate_aws_account"' in custos_terraform
    and 'data.aws_caller_identity.current.account_id != var.primary_authority_account_id' in custos_terraform
    and 'backend "s3"' in custos_terraform
    and 'use_lockfile = true' in custos_backend,
    "independent account/state boundary missing",
))
test("CUSTOS IAM: dedicated encrypted verdict and replay stores", lambda: expect(
    'resource "aws_dynamodb_table" "verdicts"' in custos_terraform
    and 'resource "aws_dynamodb_table" "request_control"' in custos_terraform
    and 'resource "aws_kms_key" "store"' in custos_terraform
    and 'kms_key_arn = aws_kms_key.store.arn' in custos_terraform,
    "dedicated store/key missing",
))
test("CUSTOS IAM: primary canonical table is read-only cross-account", lambda: expect(
    'resource "aws_dynamodb_resource_policy" "independent_custos_canonical_read"' in terraform_text
    and 'Action = ["dynamodb:GetItem"]' in terraform_text
    and 'IndependentCustosConsequentialWriteDeny' in terraform_text
    and 'Effect = "Deny"' in custos_terraform
    and 'Resource = var.primary_canonical_table_arn' in custos_terraform,
    "canonical cross-account read-only policy missing",
))
test("CUSTOS IAM: dedicated service, release and incident authority", lambda: expect(
    'name = local.service_role_name' in custos_terraform
    and 'OperationalOwner' in custos_terraform
    and 'ReleaseAuthority' in custos_terraform
    and 'IncidentAuthority' in custos_terraform
    and 'variable "operational_owner"' in custos_variables
    and 'variable "release_authority"' in custos_variables
    and 'variable "incident_authority"' in custos_variables,
    "independent operational authority metadata missing",
))
test("CUSTOS API: IAM SigV4, WAF, throttling and private Lambda", lambda: expect(
    'authorization = "AWS_IAM"' in custos_terraform
    and 'resource "aws_wafv2_web_acl" "custos"' in custos_terraform
    and 'throttling_rate_limit' in custos_terraform
    and 'vpc_config {' in custos_terraform
    and 'function_url_auth_type' not in custos_terraform
    and 'authorization_type = "NONE"' not in custos_terraform,
    "independent authenticated API boundary missing",
))
test("CUSTOS crypto: dedicated receipt key and canonical receipt verification", lambda: expect(
    'resource "aws_kms_key" "receipt"' in custos_terraform
    and 'primary_canonical_receipt_key_arn' in custos_terraform
    and 'kms:Verify' in custos_terraform
    and 'independent_custos_receipt_verify' in terraform_text
    and 'custos-r3.1' in terraform_text,
    "cross-account receipt trust missing",
))
authority_api_text = (ROOT / "supabase" / "functions" / "authority-api" / "index.ts").read_text()
sigv4_text = (ROOT / "supabase" / "functions" / "authority-api" / "aws-sigv4.ts").read_text()
test("CUSTOS invocation: separate API and cross-account role", lambda: expect(
    "PV_CUSTOS_PROVIDER_API_URL" in authority_api_text
    and "PV_CUSTOS_AWS_ROLE_ARN" in authority_api_text
    and "providerBoundary(name" in authority_api_text
    and "roleArn: boundary.roleArn" in authority_api_text,
    "authority API does not route CUSTOS to the independent boundary",
))
test("CUSTOS invocation: STS credentials cached per role, not globally", lambda: expect(
    "new Map<string, AwsCredentials>()" in sigv4_text
    and "assumeRole(roleArn: string)" in sigv4_text
    and "cachedCredentials.get(roleArn)" in sigv4_text
    and "cachedCredentials.set(roleArn, credentials)" in sigv4_text,
    "role-separated STS credential cache missing",
))
test("CUSTOS handler: independent store is the only verdict write", lambda: expect(
    "custos_store.put_item" in custos_handler_text
    and "canonical.put_item" not in custos_handler_text
    and "canonical.update_item" not in custos_handler_text,
    "CUSTOS handler writes canonical state",
))

# Scanner fail-closed when its engine is absent.
def scanner_unavailable_test():
    LOADED["scanner"].handler.CLAMSCAN = "/definitely/missing/clamscan"
    result, _ = call_ok("scanner", "/v1/scan", "evidence.scan", "evidence-unavailable", {"storageKey": begin["storageKey"], "objectVersionId": version, "objectSha256": evidence_digest})
    expect(result["status"] == "QUARANTINED" and "SCANNER_ENGINE_UNAVAILABLE" in result["reasonCodes"], result)
test("scanner: unavailable engine quarantines", scanner_unavailable_test)

failed = [item for item in RESULTS if item["status"] != "pass"]
report = {
    "generatedAt": datetime.now(timezone.utc).isoformat(),
    "scope": "R3 real provider handlers executed with deterministic IAM, KMS, DynamoDB, S3 Object Lock and Secrets Manager doubles; no deployment",
    "services": sorted(SERVICES),
    "summary": {"tests": len(RESULTS), "passed": len(RESULTS) - len(failed), "failed": len(failed), "verdict": "PASS" if not failed else "FAIL"},
    "tests": RESULTS,
}
OUT.write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report["summary"], indent=2))
if failed:
    print(json.dumps(failed, indent=2))
    raise SystemExit(1)
