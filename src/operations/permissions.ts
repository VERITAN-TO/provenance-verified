import type { OperationalPermission, OrganizationRole } from './types';

const rolePermissions: Record<OrganizationRole, OperationalPermission[]> = {
  owner: ['tenant.manage', 'location.manage', 'inventory.manage', 'batch.create', 'batch.edit', 'batch.submit', 'asset.create', 'asset.edit', 'evidence.manage', 'attestation.sign', 'correction.resolve', 'credential.lifecycle', 'label.generate', 'operations.search', 'audit.read'],
  administrator: ['location.manage', 'inventory.manage', 'batch.create', 'batch.edit', 'batch.submit', 'asset.create', 'asset.edit', 'evidence.manage', 'attestation.sign', 'correction.resolve', 'credential.lifecycle', 'label.generate', 'operations.search', 'audit.read'],
  'intake-operator': ['batch.create', 'batch.edit', 'asset.create', 'asset.edit', 'evidence.manage', 'operations.search'],
  'evidence-manager': ['batch.edit', 'asset.edit', 'evidence.manage', 'operations.search', 'audit.read'],
  'inventory-manager': ['inventory.manage', 'batch.create', 'batch.edit', 'asset.create', 'asset.edit', 'operations.search', 'audit.read'],
  'authorized-attestor': ['batch.edit', 'batch.submit', 'attestation.sign', 'correction.resolve', 'label.generate', 'operations.search', 'audit.read'],
  reviewer: ['review.assign', 'review.decide', 'review.approve-tier4', 'correction.request', 'operations.search', 'audit.read'],
  'compliance-officer': ['review.assign', 'review.decide', 'review.approve-tier4', 'custos.decide', 'credential.issue', 'credential.lifecycle', 'correction.request', 'correction.resolve', 'mark.authorize', 'label.generate', 'operations.search', 'audit.read'],
  auditor: ['operations.search', 'audit.read'],
};

export function permissionsForRole(role: OrganizationRole): OperationalPermission[] {
  return rolePermissions[role];
}

export function can(role: OrganizationRole, permission: OperationalPermission): boolean {
  return rolePermissions[role].includes(permission);
}
