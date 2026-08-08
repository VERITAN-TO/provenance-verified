import React from 'react';
import { createRoot } from 'react-dom/client';
import '@/app/site.css';
import '@/app/caliber-r2.css';
import '@/app/phase2.css';
import '@/app/phase3.css';
import '@/app/phase4.css';
import './standalone.css';
import { installCanonicalApiBridge } from './apiBridge';
import { StandaloneApplication } from './StandaloneApplication';
import { useProvenanceStore } from '@/store/useProvenanceStore';
declare global { interface Window { __PV_FORCE_NO_WEBGL__?: boolean } }
installCanonicalApiBridge();
if (window.__PV_FORCE_NO_WEBGL__) useProvenanceStore.getState().setNoWebGL(true);
const root = document.getElementById('root');
if (!root) throw new Error('STANDALONE_ROOT_MISSING');
createRoot(root).render(<React.StrictMode><StandaloneApplication /></React.StrictMode>);
