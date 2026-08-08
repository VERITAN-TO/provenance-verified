# ZIP integrity protocol

A ZIP cannot contain its own final byte-level hash without changing the bytes being hashed. The package therefore contains `SHA256SUMS.txt` for every submitted file except itself. The final ZIP SHA-256 is supplied beside the ZIP as:

`PROVENANCE_CX_R8_PRODUCTION_AUTHORITY_BUILD_R2_NO_DEPLOYMENT_COMPLETE.zip.sha256`

This follows the governing checksum protocol.
