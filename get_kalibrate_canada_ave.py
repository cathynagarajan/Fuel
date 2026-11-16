#!/usr/bin/env python3
"""Fetch weekly Kalibrate Retail Diesel Excel and extract Row 81: Canada Ave(V)."""

import datetime
import re
import urllib.request
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

NS = {"main": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}


def main() -> None:
    year = datetime.date.today().year
    url = (
        f"https://charting.kalibrate.com/WPPS/Diesel/"
        f"Retail%20(Incl.%20Tax)/WEEKLY/{year}/"
        f"Diesel_Retail%20(Incl.%20Tax)_WEEKLY_{year}.xlsx"
    )
    out_file = Path(__file__).resolve().parent / f"Kalibrate_Diesel_Weekly_{year}.xlsx"

    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        out_file.write_bytes(resp.read())

    with zipfile.ZipFile(out_file, "r") as zf:
        ss_root = ET.fromstring(zf.read("xl/sharedStrings.xml"))
        shared_strings = [
            "".join(si.itertext()) for si in ss_root.findall("main:si", NS)
        ]
        sheet_root = ET.fromstring(zf.read("xl/worksheets/sheet1.xml"))

    rows = sheet_root.findall(".//main:sheetData/main:row", NS)
    header_map: dict[str, str] = {}
    if len(rows) >= 3:
        for cell in rows[2].findall("main:c", NS):
            col = re.sub(r"\d+", "", cell.attrib.get("r", ""))
            v_el = cell.find("main:v", NS)
            val = v_el.text if v_el is not None and v_el.text is not None else ""
            if cell.attrib.get("t") == "s" and val.isdigit():
                val = shared_strings[int(val)]
            header_map[col] = val

    for row in rows:
        cells = row.findall("main:c", NS)
        if not cells or cells[0].attrib.get("t") != "s":
            continue
        v0 = cells[0].find("main:v", NS)
        if v0 is None or not v0.text or not v0.text.isdigit():
            continue
        name = shared_strings[int(v0.text)]
        if name == "Canada Ave(V)":
            numeric_cells = []
            for c in cells:
                if c.attrib.get("t") == "s":
                    continue
                v_el = c.find("main:v", NS)
                if v_el is not None and v_el.text and v_el.text.strip():
                    numeric_cells.append((c.attrib.get("r", ""), v_el.text.strip()))
            if numeric_cells:
                last_ref, last_val = numeric_cells[-1]
                col = re.sub(r"\d+", "", last_ref)
                print(f"Metric: {name} | Week: {header_map.get(col, col)} | Value: {last_val}")


if __name__ == "__main__":
    main()
