#!/usr/bin/env python3
# SPDX-License-Identifier: MPL-2.0
"""Independent scaled-gradient and embedded-image textbox fill controls.

Uses the paint probe's source-hashed, sequential native measurement harness.
The authored source packages do not use the parser's model or writer.
"""
import json
import struct
import zipfile
import zlib

import textbox_paint_probe as probe


CASES = {
    "gradient-zero": '<v:fill type="gradient" color2="#CC6633" angle="0" focus="0%" rotate="t"/>',
    "gradient-hundred": '<v:fill type="gradient" color2="#CC6633" angle="0" focus="100%" rotate="t"/>',
    "gradient-diagonal": '<v:fill type="gradient" color2="#CC6633" angle="45" focus="0%" rotate="f"/>',
    "gradient-axial": '<v:fill type="gradient" color2="#CC6633" angle="-45" focus="-50%" rotate="f"/>',
    "gradient-opacity": '<v:fill type="gradient" color2="#CC6633" angle="0" focus="100%" opacity="32768f" o:opacity2="16384f"/>',
    "picture": '<v:fill type="frame" r:id="fillImage"/>',
    "texture": '<v:fill type="tile" r:id="fillImage"/>',
    "pattern": '<v:fill type="pattern" color="#6699CC" color2="#CC6633" r:id="patternImage"/>',
}

GRADIENT_PROPERTIES = {
    "gradient-zero": {"18b": 0, "18c": 0, "1bf": 0x00300030},
    "gradient-hundred": {"18b": 0, "18c": 100, "1bf": 0x00300030},
    "gradient-diagonal": {"18b": 45 * 65536, "18c": 0, "1bf": 0x00300010},
    "gradient-axial": {"18b": -45 * 65536, "18c": -50, "1bf": 0x00300010},
    "gradient-opacity": {"18b": 0, "18c": 100, "182": 32768, "184": 16384},
}


def prepare_binary(args, name, binary, directory):
    if name not in GRADIENT_PROPERTIES:
        return binary, {"applied": False}
    # The native DOC exporter flattens textbox gradients to a midpoint color.
    # Restore independently specified source operands, without using parser
    # output or changing layout/anchor bytes. Retain the unmodified export.
    properties = {"180": 7, "181": 0xCC9966, "183": 0x3366CC,
                  **GRADIENT_PROPERTIES[name]}
    definitions = directory / "source-properties.json"
    probe.write(definitions, properties)
    controlled = directory / "binary" / "controlled.doc"
    argv = [args.dart, "run", probe.ROOT / "tool/fidelity/textbox_property_control.dart",
            binary, controlled, definitions]
    receipt = json.loads(probe.command(argv, cwd=probe.ROOT))
    receipt.update(applied=True, inputSha256=probe.digest(binary),
                   outputSha256=probe.digest(controlled),
                   propertiesSha256=probe.digest(definitions),
                   command=[str(value) for value in argv])
    probe.write(directory / "source-control.json", receipt)
    return controlled, receipt


def png(pattern=False):
    """Small exact RGB control pixels, authored without an imaging library."""
    width, height = (8, 8) if pattern else (24, 16)
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        for x in range(width):
            if pattern:
                value = 0 if (x + y) % 4 == 0 else 255
                raw.extend((value, value, value))
            else:
                raw.extend((17 + 7 * x, 23 + 11 * y, 211 if x < 8 else 43))
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    return (b"\x89PNG\r\n\x1a\n" +
            chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)) +
            chunk(b"IDAT", zlib.compress(bytes(raw))) + chunk(b"IEND", b""))


_package = probe.package


def package(path, body):
    _package(path, body)
    media = {name: png(name == "patternImage")
             for name in ("fillImage", "patternImage") if f'r:id="{name}"' in body}
    if not media:
        return
    with zipfile.ZipFile(path) as original:
        parts = {item.filename: (item, original.read(item)) for item in original.infolist()}
    relationship_path = "word/_rels/document.xml.rels"
    info, relationships = parts[relationship_path]
    links = "".join(f'<Relationship Id="{name}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/{name}.png"/>' for name in media)
    parts[relationship_path] = (info, relationships.replace(b"</Relationships>", links.encode() + b"</Relationships>"))
    info, types = parts["[Content_Types].xml"]
    parts["[Content_Types].xml"] = (info, types.replace(b"</Types>", b'<Default Extension="png" ContentType="image/png"/></Types>'))
    for name, data in media.items():
        info = zipfile.ZipInfo(f"word/media/{name}.png", date_time=(2026, 1, 1, 0, 0, 0))
        info.compress_type = zipfile.ZIP_DEFLATED
        info.external_attr = 0o100644 << 16
        parts[info.filename] = (info, data)
    with zipfile.ZipFile(path, "w") as output:
        for _, (info, data) in sorted(parts.items()):
            output.writestr(info, data)


if __name__ == "__main__":
    if not __debug__:
        raise SystemExit("Measurements require normal Python without -O.")
    probe.CASES = CASES
    probe.package = package
    probe.PREPARE_BINARY = prepare_binary
    probe.main()
