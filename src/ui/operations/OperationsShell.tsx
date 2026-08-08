'use client';
import type {ReactNode} from 'react';import {getPublicEnvironment} from '@/authority/public-mode';
export function OperationsShell({children}:{title:string;eyebrow:string;children:ReactNode;actions?:ReactNode}){const environment=getPublicEnvironment();if(environment!=='sandbox')return null;return <>{children}</>}
