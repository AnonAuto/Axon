# Static Analysis Report — t7_handle_v2.0.6.bin

**Size:** 673,576 bytes  
**SHA-256:** `4284d9cceabad5cdaeeab708d6cacadd95708f2e6b1a9f65e49399f4bc15b923`

## Header Peek (first 256 bytes)
```
00000000  54 41 53 45 52 00 bf 01 01 02 00 06 30 52 2c 67   TASER.......0R,g
00000010  ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff   ................
00000020  ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff   ................
00000030  ff ff ff ff ff ff ff ff ff ff ff ff ff ff 33 a9   ..............3.
00000040  00 01 00 00 20 e0 01 00 01 01 d3 7c 15 e6 69 c5   .... ......|..i.
00000050  40 bf 03 00 40 b7 04 00 01 01 2a 37 00 a9 ea 9b   @...@.....*7....
00000060  40 af 05 00 40 a7 07 00 01 01 7f 5d f1 0e c2 6d   @...@......]...m
00000070  40 9f 09 00 38 ef 09 00 01 01 ac c0 80 75 bc c0   @...8........u..
00000080  ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff   ................
00000090  ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff   ................
000000a0  ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff   ................
000000b0  ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff   ................
000000c0  ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff   ................
000000d0  ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff   ................
000000e0  ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff   ................
000000f0  ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff ff   ................
```

## Magic & Notable Strings
- Occurrences of **"TASER"**: 11 at offsets [0, 82244, 89036, 89404, 204900, 211692, 212060, 471098, 600122, 647681]...
- Occurrences of **"Signature"**: 2 at offsets [473668, 602692]

All ASCII strings (min len 5) saved to: `t7_strings.txt`.

## Cryptographic Manifests (ASN.1 DER)
Detected 2 DER block(s) containing EC key OIDs near:
- Block 0: 469,031–500,285 (size 31,254) → `t7_derblock_0.der`
- Block 1: 598,055–629,309 (size 31,254) → `t7_derblock_1.der`

## Entropy Scan (window 4096 bytes)
CSV at `t7_entropy.csv` with per-window entropy (0–8 bits). Look for high-entropy regions indicative of compressed/encrypted data.

## Compression Candidates
- zlib-like markers at offsets: [4099, 4343, 6365, 8151, 8161, 8171, 22675, 27795, 27903, 29383, 31987, 32393, 36553, 36561, 36599, 36607, 36625, 36633, 38251, 38517]
- gzip markers at offsets: []
- LZMA markers (heuristic) at offsets: []

Extracted 0 zlib stream(s):  
(none successfully decompressed within heuristic bounds)

## Potential Cortex-M Vector Tables
Found 0 candidate vector table(s) at offsets: []

Heuristic: SP ~ 0x2000xxxx, Reset ~ 0x0001xxxx|0x0100xxxx (Thumb). Presence suggests embedded nRF52-style application images in the container.

## UUID-like Strings
Found 0 UUID-formatted strings.
