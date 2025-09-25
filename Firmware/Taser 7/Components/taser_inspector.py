#!/usr/bin/env python3
# taser_inspector.py
# Usage: python taser_inspector.py t7_handle_v2.0.6.bin
# Requires: cryptography, pyasn1, pyasn1-modules

import sys, struct, binascii, hashlib, re
from pathlib import Path
from pyasn1.codec.der import decoder as der_decoder
from pyasn1.type import univ
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.exceptions import InvalidSignature

F = Path(sys.argv[1])
data = F.read_bytes()
N = len(data)
print(f"File: {F.name}  Size: {N:,} bytes  SHA256: {hashlib.sha256(data).hexdigest()}")

# 1) find TASER magic
magic = b"TASER"
mpos = data.find(magic)
if mpos < 0:
    print("No TASER magic found. Aborting.")
    sys.exit(1)
print("TASER magic at offset", mpos)

# Dump a short header window to inspect manually
print("\nHeader (hex) 0x00..0x80:")
print(data[mpos:mpos+128].hex())
print("\nHeader (ascii):")
print(''.join(chr(b) if 32<=b<127 else '.' for b in data[mpos:mpos+128]))

# 2) Heuristics: container may include a small header with an entry count and table entries.
# We'll search for candidate TOC-like patterns: sequences of (type, offset, length) with plausible offsets.
# Many vendor containers use little-endian 32-bit offsets and lengths. We'll scan forward and test entries that point into file bounds.

def plausible_offset(v):
    return 0 <= v < N

def scan_for_toc_candidates(search_start=0, max_entries=64):
    hits = []
    # look for a region where there are many dword pairs that look like offsets/lengths
    for off in range(search_start, min(search_start+4096, N-16)):
        # read a small window of dwords
        try:
            dwords = struct.unpack_from('<' + 'I'*8, data, off)
        except Exception:
            continue
        # if several of these dwords point into the file at plausible offsets, it's a candidate
        points = [d for d in dwords if plausible_offset(d)]
        if len(points) >= 4:
            hits.append(off)
    return sorted(set(hits))

cands = scan_for_toc_candidates(mpos, )
print("\nTOC candidate offsets (first 20):", cands[:20])

# 3) Look for DER blocks (we know there are ecPublicKey OIDs). We'll find 0x30 ... length ... that contain OID for ecPublicKey.
ec_oid = bytes.fromhex("06072A8648CE3D0201")  # 1.2.840.10045.2.1
hits = [m.start() for m in re.finditer(re.escape(ec_oid), data)]
print("\nFound ecPublicKey OID occurrences at:", hits)

# 4) function to find an enclosing DER SEQUENCE that includes a given index
def find_seq_bounds(buf, idx, backmax=8192):
    for i in range(max(0, idx-backmax), idx):
        if buf[i] != 0x30: continue
        # read length bytes
        if i+1 >= len(buf): continue
        lb = buf[i+1]
        pos = i+2
        if lb < 0x80:
            length = lb
        else:
            cnt = lb & 0x7F
            if cnt == 1 and i+2 < len(buf):
                length = buf[i+2]
                pos += 1
            elif cnt == 2 and i+3 < len(buf):
                length = (buf[i+2]<<8) | buf[i+3]; pos += 2
            elif cnt == 3 and i+4 < len(buf):
                length = (buf[i+2]<<16)|(buf[i+3]<<8)|buf[i+4]; pos += 3
            else:
                continue
        end = pos + length
        if end <= len(buf) and end > idx:
            return i, end
    return None, None

der_blocks = []
for h in hits:
    s,e = find_seq_bounds(data, h, backmax=8192)
    if s is not None:
        der_blocks.append((s,e))
der_blocks = sorted(set(der_blocks))
print("\nExtracted DER blocks:", der_blocks)
for i,(s,e) in enumerate(der_blocks):
    out = Path(f"t7_der_extract_{i}.der")
    out.write_bytes(data[s:e])
    print("Wrote", out, "size", e-s, "offsets", s, e)

# 5) parse DER block to extract any manifest fields and signature container
def parse_der_file(path):
    raw = path.read_bytes()
    try:
        asn1obj, rest = der_decoder.decode(raw)
    except Exception as ex:
        print("ASN.1 decode failed for", path, ex)
        return None
    return asn1obj

# We'll also do a raw search for 'Signature' ascii strings near DERs
for i,(s,e) in enumerate(der_blocks):
    window = data[s:e]
    si = window.find(b"Signature")
    print(f"DER {i} contains 'Signature' at {si if si>=0 else 'not found'} relative offset (absolute {s+si if si>=0 else 'NA'})")
    # raw dump of ascii area around it
    if si >= 0:
        snippet = window[max(0,si-64):si+256]
        print("Snippet around Signature (ascii):")
        print(''.join(chr(b) if 32<=b<127 else '.' for b in snippet))
        # write snippet
        Path(f"der_{i}_sig_snippet.bin").write_bytes(snippet)

# 6) Try to find which bytes are referenced in the DER manifest as the signed hash.
# Many vendor manifests include an OCTET STRING of a hash or an OCTET STRING containing the digest.
# We'll search inside the DER for any raw 32-byte sequences that look like SHA-256 digest of some region of the firmware.
def extract_32b_values(b):
    out = []
    for i in range(len(b)-32):
        cand = b[i:i+32]
        # will accept any 32 bytes; we can later test whether it matches sha256 of some region
        out.append((i,cand))
    return out

# to be efficient, look for 32B sequences that also appear in the rest of the file as a digest of a region
candidates = []
for i,(s,e) in enumerate(der_blocks):
    blk = data[s:e]
    # find 32-byte aligned candidate sequences that look like sha256 outputs (random high entropy)
    for off in range(0, len(blk)-32):
        cand = blk[off:off+32]
        # heuristic: candidate must not be ascii-like
        if all(32<=b<127 for b in cand):
            continue
        candidates.append((i, s+off, cand.hex()))

print("\nDER candidate 32-byte values found (first 8):", candidates[:8])

# 7) For each candidate digest, try to find a matching region in the firmware whose sha256 equals it.
def find_region_for_digest(digest_bytes):
    # brute force candidate: check some plausible ranges: e.g., everything before first DER block, excluding manifest itself
    # We'll check:
    regions_to_check = [
        (0, der_blocks[0][0]) if der_blocks else (0, N),
        # additional region guesses
        (der_blocks[0][1], der_blocks[1][0]) if len(der_blocks)>1 else None,
        (0, N)
    ]
    matches = []
    for r in regions_to_check:
        if not r: continue
        start, end = r
        # compute SHA256 of the entire region
        h = hashlib.sha256(data[start:end]).digest()
        if h == digest_bytes:
            matches.append((start,end))
        # Also try a few offsets: e.g. maybe signed region is [0 : der_start) or [header..some offset]
    return matches

# Try a few candidate digests
found = []
for i,(s,e) in enumerate(der_blocks):
    blk = data[s:e]
    for off in range(0, len(blk)-32):
        cand = blk[off:off+32]
        matches = find_region_for_digest(cand)
        if matches:
            print("Found digest match for DER", i, "at der-relative offset", off)
            found.append((i, s+off, matches))
            break

print("\nDigest->region matches (if any):", found)

# 8) Try to extract any ECDSA signature fields (r,s). ECDSA signatures in vendor manifests are sometimes stored as BIT STRING containing DER SEQUENCE (r, s) or raw concat.
from pyasn1.codec.der import decoder as derdecoder
def try_extract_signature(derpath):
    raw = derpath.read_bytes()
    try:
        obj, rest = derdecoder.decode(raw)
    except Exception as e:
        return None
    # Walk the ASN.1 tree looking for BIT STRING or OCTET STRING that could contain R,S sequence
    results = []
    def walk(x, path=""):
        t = type(x).__name__
        # if it's an OctetString or BitString, try to parse inner as DER
        if t in ("OctetString", "BitString", "OctetStringType"):
            try:
                inner, r = derdecoder.decode(bytes(x))
                if inner is not None:
                    # attempt to decode as sequence of two integers (r,s)
                    if type(inner).__name__ == "Sequence":
                        # attempt parse
                        try:
                            r_v = int(inner.getComponentByPosition(0))
                            s_v = int(inner.getComponentByPosition(1))
                            results.append((r_v, s_v))
                        except Exception:
                            pass
            except Exception:
                pass
        # iterate children if sequence
        if hasattr(x, 'getComponentByPosition'):
            for i in range(0, 10):
                try:
                    child = x.getComponentByPosition(i)
                    walk(child, path + f".{i}")
                except Exception:
                    break
    walk(obj)
    return results

for i,(s,e) in enumerate(der_blocks):
    path = Path(f"t7_der_extract_{i}.der")
    sigs = try_extract_signature(path)
    print("DER", i, "extracted signature candidates:", sigs[:3])

# 9) If we find (r,s) and pubkey, attempt verification (example expects uncompressed pubkey bytes somewhere near the DER)
def find_uncompressed_pubkey_near(derrange):
    s,e = derrange
    window = data[s:e]
    # look for pattern 0x04 || 64 bytes (uncompressed ECDSA P-256 key)
    idx = window.find(b'\x04')
    while idx >= 0:
        # ensure enough bytes after idx
        if idx + 1 + 64 <= len(window):
            cand = window[idx+1:idx+1+64]
            if len(cand) == 64:
                return cand
        idx = window.find(b'\x04', idx+1)
    return None

for i,dr in enumerate(der_blocks):
    pk = find_uncompressed_pubkey_near(dr)
    print("DER", i, "pubkey found:", bool(pk))
    if pk:
        Path(f"t7_pubkey_der_{i}.bin").write_bytes(pk)
        print("Wrote t7_pubkey_der_%d.bin" % i)

print("\nDone. Artifacts written: t7_der_extract_*.der, t7_pubkey_der_*.bin, der_*_sig_snippet.bin")
print("If you want, run 'openssl asn1parse -in t7_der_extract_0.der -inform DER -i' to inspect.")
print("Next: parse the DER with openssl/asn1parse to find the signed digest and the signature (r,s).")
