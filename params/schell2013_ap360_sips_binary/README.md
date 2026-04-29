# Schell 2013 AP3-60 Sips Binary Pack

Purpose:
- primary two-bed H2/CO2 PSA validation.

Allowed sources:
- Schell 2013 paper;
- Schell 2013 supporting information;
- explicitly documented source-derived conversions.

Do not include:
- Casas detector/piping assumptions;
- Delgado BPL/13X constants;
- contaminant polishing constants.

Files:
- `schell_2013_source_pack.json`: canonical typed source pack.
- `schell_2013_source_pack.schema.json`: JSON schema for the canonical source pack.
- `schell_2013_sips_anchor_cases.json`: independent numerical anchors for Schell Sips equation-local tests.
- `schell_2013_sips_anchor_cases.csv`: tabular copy of the Sips anchors for inspection.

Canonical source pack SHA256:
- `b50eef14ce62bbe509c235e98f68983319bc0abe94fe2400d40f8c07d22ae0e7`

Status:
- canonical source pack and Sips anchor cases integrated from `C:/dev/psa/schell2013_implementation_pack`.
- no runnable Schell simulator case has been implemented yet.
