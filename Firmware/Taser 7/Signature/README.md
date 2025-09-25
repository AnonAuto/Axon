# Axon Taser 7 Firmware Signature Findings

**Firmware file:** `t7_handle_v2.0.6.bin`  
**Size:** 673,576 bytes  
**SHA-256 (firmware):** `4284d9cceabad5cdaeeab708d6cacadd95708f2e6b1a9f65e49399f4bc15b923`

Detected two ASN.1 DER sequences that contain EC public key metadata (OID `ecPublicKey` + curve `prime256v1`) and the ECDSA with SHA-256 algorithm OID. These are strong indicators of a signed firmware container or embedded certificate/manifest structures.

| Index | Offset (start-end) | Size | Block SHA-256 | EC Public Key SHA-256 |
|------:|---------------------|------:|---------------|-----------------------|
| 0 | 469,031–500,285 | 31,254 | `704c12156b491f6deff122bb40a3efebe2c885166e9c1b6553d433c3b57cb4d2` | `a62c50fa61c286a693f7355de51b503f3057edfe096e82157451da51e1816b54` |
| 1 | 598,055–629,309 | 31,254 | `b4aef0b731ce8fc0f1e6c5eb4fa9cedf1045b464579a8f60a243338525d7e4dd` | `a62c50fa61c286a693f7355de51b503f3057edfe096e82157451da51e1816b54` |

## Extracted Artifacts
- `axon_sig_block_0.der`  
- `axon_sig_block_1.der`  
- `axon_pubkey_0.bin` (raw 64-byte EC P-256 uncompressed XY)  
- `axon_pubkey_0.hex` (hex view)  
- `axon_pubkey_1.bin`  
- `axon_pubkey_1.hex`  

> Note: Both extracted public keys are identical (same SHA-256), suggesting duplicate or mirrored signature blocks.

## Next Steps (Manual Verification)
- Use `openssl asn1parse -inform DER -in axon_sig_block_0.der -i` to inspect structure.
- Try CMS/PKCS#7 and custom ASN.1 decoders; the presence of `ecPublicKey` and `ecdsa-with-SHA256` OIDs indicates ECDSA signatures over a manifest.
- Compare public key against trusted Axon update keys if available.

