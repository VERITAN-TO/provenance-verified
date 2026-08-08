from __future__ import annotations
import json, urllib.request, urllib.error, urllib.parse, uuid
class ProvenanceError(RuntimeError):
    def __init__(self, code:str, status:int, message:str|None=None, receipt_id:str|None=None): super().__init__(message or code); self.code=code; self.status=status; self.receipt_id=receipt_id
class ProvenanceClient:
    def __init__(self, base_url:str, token:str, tenant_id:str, timeout:float=30): self.base_url=base_url.rstrip('/'); self.token=token; self.tenant_id=tenant_id; self.timeout=timeout
    def _request(self,path:str,method:str='GET',payload:dict|None=None,idempotency_key:str|None=None):
        headers={'Authorization':f'Bearer {self.token}','x-provenance-tenant':self.tenant_id,'content-type':'application/json','x-request-id':str(uuid.uuid4())}
        if idempotency_key: headers['idempotency-key']=idempotency_key
        req=urllib.request.Request(self.base_url+path,data=None if payload is None else json.dumps(payload).encode(),headers=headers,method=method)
        try:
            with urllib.request.urlopen(req,timeout=self.timeout) as response: body=json.loads(response.read() or b'{}')
        except urllib.error.HTTPError as exc:
            body=json.loads(exc.read() or b'{}'); err=body.get('error',{}); raise ProvenanceError(err.get('code','request_failed'),exc.code,err.get('message'),err.get('receiptId')) from exc
        if 'data' not in body: raise ProvenanceError('invalid_response',200)
        return body['data']
    def verify(self,public_id:str): return self._request('/api/v1/verify','POST',{'publicId':public_id})
    def registry(self,public_id:str): return self._request('/api/v1/registry/'+urllib.parse.quote(public_id,safe=''))
    def authority_control_center(self): return self._request('/api/v1/authority/control-center')
    def operational_controls(self): return self._request('/api/v1/authority/operational-controls')
    def record_runtime_claim(self,payload:dict,idempotency_key:str|None=None): return self._request('/api/v1/authority/operational-controls/runtime-claims','POST',payload,idempotency_key or str(uuid.uuid4()))
    def issue(self,review_case_id:str,idempotency_key:str|None=None): return self._request('/api/v1/authority/reviews/'+urllib.parse.quote(review_case_id,safe='')+'/issue','POST',{},idempotency_key or str(uuid.uuid4()))
    def mcp(self,name:str,arguments:dict|None=None): return self._request('/api/v1/mcp','POST',{'name':name,'arguments':arguments or {}})
