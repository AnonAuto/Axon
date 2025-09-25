# Firmware Segmentation Report — t7_handle_v2.0.6.bin

- **Size:** 673,576 bytes
- **SHA-256:** `4284d9cceabad5cdaeeab708d6cacadd95708f2e6b1a9f65e49399f4bc15b923`

## Heuristic TOC Rows (from header)

| RowOff | Type | Offset | Length | End | Flags/CRC |
|--:|--:|--:|--:|--:|--:|
| 0x0120 | 0x00000000 | 0x00000000 | 0x00000000 | 0x00000000 | 0x0000414d |
| 0x0130 | 0x00004151 | 0x00000000 | 0x00004155 | 0x00004155 | 0x00011b39 |
| 0x0124 | 0x00000000 | 0x00000000 | 0x0000414d | 0x0000414d | 0x00004151 |
| 0x003c | 0xa933ffff | 0x00000100 | 0x0001e020 | 0x0001e120 | 0x7cd30101 |
| 0x0104 | 0x00004195 | 0x00004139 | 0x0000b991 | 0x0000faca | 0x00004141 |
| 0x010c | 0x0000b991 | 0x00004141 | 0x00004145 | 0x00008286 | 0x00004149 |
| 0x0110 | 0x00004141 | 0x00004145 | 0x00004149 | 0x0000828e | 0x00000000 |
| 0x0114 | 0x00004145 | 0x00004149 | 0x00000000 | 0x00004149 | 0x00000000 |
| 0x0128 | 0x00000000 | 0x0000414d | 0x00004151 | 0x0000829e | 0x00000000 |
| 0x012c | 0x0000414d | 0x00004151 | 0x00000000 | 0x00004151 | 0x00004155 |
| 0x0134 | 0x00000000 | 0x00004155 | 0x00011b39 | 0x00015c8e | 0x0000415d |
| 0x0140 | 0x0000415d | 0x0000415d | 0x0000415d | 0x000082ba | 0x0000415d |
| 0x0154 | 0x0000415d | 0x0000415d | 0x0000fbad | 0x00013d0a | 0x0000fbc9 |
| 0x01b4 | 0x0000415d | 0x0000415d | 0x0000e211 | 0x0001236e | 0x0000415d |
| 0x01c8 | 0x0000415d | 0x0000415d | 0x0000e2e1 | 0x0001243e | 0x0000415d |
| 0x0100 | 0x02008000 | 0x00004195 | 0x00004139 | 0x000082ce | 0x0000b991 |
| 0x0108 | 0x00004139 | 0x0000b991 | 0x00004141 | 0x0000fad2 | 0x00004145 |
| 0x01b8 | 0x0000415d | 0x0000e211 | 0x0000415d | 0x0001236e | 0x0000415d |
| 0x01cc | 0x0000415d | 0x0000e2e1 | 0x0000415d | 0x0001243e | 0x0000415d |
| 0x0158 | 0x0000415d | 0x0000fbad | 0x0000fbc9 | 0x0001f776 | 0x0000fbf9 |
| 0x015c | 0x0000fbad | 0x0000fbc9 | 0x0000fbf9 | 0x0001f7c2 | 0x0000fc29 |
| 0x0160 | 0x0000fbc9 | 0x0000fbf9 | 0x0000fc29 | 0x0001f822 | 0x0000fc4d |
| 0x0164 | 0x0000fbf9 | 0x0000fc29 | 0x0000fc4d | 0x0001f876 | 0x0000fca1 |
| 0x0168 | 0x0000fc29 | 0x0000fc4d | 0x0000fca1 | 0x0001f8ee | 0x0000fcd9 |
| 0x016c | 0x0000fc4d | 0x0000fca1 | 0x0000fcd9 | 0x0001f97a | 0x0000fcfd |
| 0x0170 | 0x0000fca1 | 0x0000fcd9 | 0x0000fcfd | 0x0001f9d6 | 0x0000415d |
| 0x0174 | 0x0000fcd9 | 0x0000fcfd | 0x0000415d | 0x00013e5a | 0x0000415d |
| 0x0138 | 0x00004155 | 0x00011b39 | 0x0000415d | 0x00015c96 | 0x0000415d |
| 0x004c | 0xc569e615 | 0x0003bf40 | 0x0004b740 | 0x00087680 | 0x372a0101 |

## Carved Segments (heuristics + padding + DER anchors)

| # | Start | End | Size | Type | SHA-256 | MD5 |
|--:|--:|--:|--:|--|--|--|
| 000 | 0x000000 | 0x014000 |   81920 | code/data-mix | `d107c9bcf1d754fe…` | `9f23fd462dd32f3283e6d928e8afaddf` |
| 001 | 0x014000 | 0x016000 |    8192 | ASCII-rich/manifest/meta | `30bfe5e822cbf515…` | `13ef39783c91b0dfe5c1d146b7c27f90` |
| 002 | 0x016000 | 0x016bbc |    3004 | other | `d5a21f6b7e90eabd…` | `db07c6ca09207a89525e5470e2beba7f` |
| 003 | 0x016bbc | 0x01e000 |   29764 | pad(0x00) | `98401c46f8e8d6a5…` | `2782e9d8328673958d489fb4a5eccebe` |
| 004 | 0x01e000 | 0x032000 |   81920 | code/data-mix | `7d0909806fc73d52…` | `1b51b4a8d362e93fcb5b78bee0afd9e8` |
| 005 | 0x032000 | 0x034000 |    8192 | ASCII-rich/manifest/meta | `5ee3764ed191cc0f…` | `a8461101e988c5f378a2d456691225ff` |
| 006 | 0x034000 | 0x034adc |    2780 | other | `ee8628b724932c9e…` | `124352d9912e5c1df0fde8c4b0d272e9` |
| 007 | 0x034adc | 0x03bf20 |   29764 | pad(0x00) | `98401c46f8e8d6a5…` | `2782e9d8328673958d489fb4a5eccebe` |
| 008 | 0x03bf20 | 0x03c000 |     224 | ASCII-rich/manifest/meta | `4fcc9653087b8899…` | `2339106aced2b1f45863a86c19262677` |
| 009 | 0x03c000 | 0x042000 |   24576 | code/data-mix | `3bf4be3d970978b7…` | `eef91dd0c22e1886b3bc70081c6c0fa0` |
| 010 | 0x042000 | 0x044000 |    8192 | ASCII-rich/manifest/meta | `6dcfe2fc8e5fa86e…` | `ecdbfca03eaafa1d32b2f5aac40da266` |
| 011 | 0x044000 | 0x044e90 |    3728 | ASCII-rich/manifest/meta | `2636c58cc32d408f…` | `e329080dc3d6ea3c6bb077ddcdb8d33f` |
| 012 | 0x044e90 | 0x046000 |    4464 | pad(0x00) | `298d45b23b606d92…` | `6102f1b68c97d7fb9e07caaf0c07280e` |
| 013 | 0x046000 | 0x04a000 |   16384 | pad(0x00) | `4fe7b59af6de3b66…` | `ce338fe6899778aacfc28414f2d9498b` |
| 014 | 0x04a000 | 0x04b640 |    5696 | pad(0x00) | `8127d66ebb730846…` | `fc4e4b9f61f0e9cbf78f87d24c55c03a` |
| 015 | 0x04b640 | 0x04c000 |    2496 | ASCII-rich/manifest/meta | `f2e56aaa4907526a…` | `146862fd5b7487e96540ddd9396a505a` |
| 016 | 0x04c000 | 0x052000 |   24576 | code/data-mix | `68fc48d60abf08cf…` | `778ffa4211089d6acaf643d1b9111740` |
| 017 | 0x052000 | 0x054000 |    8192 | ASCII-rich/manifest/meta | `417fc36b889be18d…` | `a9b71f6794c37d5ff9c26ea6681bb98c` |
| 018 | 0x054000 | 0x054690 |    1680 | ASCII-rich/manifest/meta | `2f0415685499dc7e…` | `95b4cc181e61e877b28cad1ce0c49639` |
| 019 | 0x054690 | 0x056000 |    6512 | pad(0x00) | `8f28c51469bac643…` | `ffd83ed0e99837a1d07217a99a6f33e4` |
| 020 | 0x056000 | 0x05a000 |   16384 | pad(0x00) | `4fe7b59af6de3b66…` | `ce338fe6899778aacfc28414f2d9498b` |
| 021 | 0x05a000 | 0x05ae40 |    3648 | pad(0x00) | `301efe9642b0328c…` | `58c2fbd3e75260331ac50a635877b15c` |
| 022 | 0x05ae40 | 0x05c000 |    4544 | ASCII-rich/manifest/meta | `8fa6187c62323fc8…` | `98f802738f632b821b95ab00590f2311` |
| 023 | 0x05c000 | 0x072827 |   92199 | code/data-mix | `65121b77018a74e9…` | `09ac9598ea30534cad90025d30ae125b` |
| 024 | 0x072827 | 0x073f5d |    5942 | DER/ASN1? | `bd80bc4690f28791…` | `f31b1a88b892dd051f131c75417064b5` |
| 025 | 0x073f5d | 0x074000 |     163 | pad(0x00) | `7e0dc3a13324b067…` | `eb8faf6b2c22464c49898a38d634afe4` |
| 026 | 0x074000 | 0x07a000 |   24576 | pad(0x00) | `de676bae28a48001…` | `91ff0dac5df86e798bfef5e573536b08` |
| 027 | 0x07a000 | 0x07a23d |     573 | pad(0x00) | `dc8c44856f7c315f…` | `ecd0f02b413c556a1402880dd4e4fe79` |
| 028 | 0x07a23d | 0x07a640 |    1027 | pad(0x00) | `241f676dc4eb5ac7…` | `9b9c1a243b5f18c65e58ab4a83059c9f` |
| 029 | 0x07a640 | 0x092000 |   96704 | code/data-mix | `ed3602fd4a643e20…` | `592dde544657db9437480986b3e20bef` |
| 030 | 0x092000 | 0x092027 |      39 | ASCII-rich/manifest/meta | `d55b281e78f26336…` | `9040416d9ec7b2733a499ba59610e875` |
| 031 | 0x092027 | 0x09375d |    5942 | DER/ASN1? | `f9968d4ab2ebc4e0…` | `4b0c9a17a0d25472d9f39592ffd2f274` |
| 032 | 0x09375d | 0x094000 |    2211 | pad(0x00) | `df359da11552491d…` | `16a42de533d0166721a72f631f5c6f43` |
| 033 | 0x094000 | 0x099a3d |   23101 | pad(0x00) | `037110eba75a0101…` | `4c2ddf96a46afaa172d0d971a332d5f5` |
| 034 | 0x099a3d | 0x099e40 |    1027 | pad(0x00) | `241f676dc4eb5ac7…` | `9b9c1a243b5f18c65e58ab4a83059c9f` |
| 035 | 0x099e40 | 0x09a000 |     448 | other | `55782d53e43c6c54…` | `d3d4c873b1a4ce9ba308b7bd29851f4c` |
| 036 | 0x09a000 | 0x09e000 |   16384 | ASCII-rich/manifest/meta | `b79e3bdd7fe39a43…` | `ae06e0367e1501e310dd8ebf15ff36ec` |
| 037 | 0x09e000 | 0x09e23a |     570 | ASCII-rich/manifest/meta | `151fbc1a3542ec81…` | `3473767a3a10ad41e31c62b2da335c4d` |
| 038 | 0x09e23a | 0x09ef35 |    3323 | pad(0x00) | `1ae625f71399449a…` | `74952db70d858b001e4acad096575e75` |
| 039 | 0x09ef35 | 0x0a0000 |    4299 | code/data-mix | `a78bdef228ce94bd…` | `7a45f5d4208eb7094a7b97274410136d` |
| 040 | 0x0a0000 | 0x0a4000 |   16384 | code/data-mix | `f0ac968f54a0ed53…` | `9cef4c0f044b01ff24203ffe6cdedae2` |
| 041 | 0x0a4000 | 0x0a40f0 |     240 | other | `41d101fe21657bf3…` | `5f77fe8da7bd8c30851ff80ba8816359` |
| 042 | 0x0a40f0 | 0x0a4724 |    1588 | pad(0x00) | `318e9e1df845c413…` | `79b9e09ca5f8f8ebd840da4c96afeccc` |
| 043 | 0x0a4724 | 0x0a4728 |       4 | other | `57c59d17338aa748…` | `d0e500a2355cf3c01c51dfaf989f6f12` |

### Notes
- `DER(manifest)` rows are the verified signature/certificate containers.
- `pad(0xFF)` / `pad(0x00)` are container padding gaps; they act as natural cut boundaries.
- `code/data-mix` vs `high-entropy` is heuristic (entropy + ASCII density). The true code image will be in one of these blocks; follow TOC rows whose offset/length equal the block bounds to pin it down.

## Files Written

- Segment binaries: `/mnt/data/segments/seg_XXX_0xSTART_0xEND.bin`
- This report: `/mnt/data/firmware_segments_report.md`

---
Generated automatically.
