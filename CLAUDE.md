# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a personal Python utility repository ("Automate the Boring Stuff" style) containing standalone scripts and one GUI desktop application. There is no build system, test suite, or package structure — each module/directory is self-contained and runs independently.

## Running Scripts

Each script is standalone. Run directly with Python 3:

```bash
python <script>.py
```

For scripts that take command-line arguments:
```bash
# Fixed-length file parser
python regularexpressions/files/readingFixedLengthFile.py <inputfile> <rejfile>
```

### excelUploadApp (PyQt5 GUI)

The only multi-file application. Run from inside its directory so that INI config files are found via relative paths:

```bash
cd excelUploadApp
python main.py
```

Dependencies: `PyQt5`, `openpyxl`. The UI class `Ui_MainWindow` is expected in `excelupload.py` (a PyQt5 designer-generated file not tracked in git).

## Architecture

### excelUploadApp

The only application with internal structure:

- `main.py` — Entry point. Reads `appSettings.ini` (falls back to `defaultSetting.ini` if absent) via `app_settings()`, constructs `MainWindow`, starts the Qt event loop.
- `csvFileCreator.py` — `CsvFileCreator` class: loads an `.xlsx` workbook with `openpyxl`, iterates all sheets skipping the header row, returns row data as a list of lists, then writes it to CSV with a configurable delimiter.
- `recordObj.py` — Simple data class `recordObj` (currently unused by `csvFileCreator.py`).
- `excelupload.py` — PyQt5 designer-generated UI file (defines `Ui_MainWindow`); must exist for `main.py` to import.

**Config loading**: `app_settings('Coreappsetting')` reads the INI and returns a dict. `appSettings.ini` takes precedence over `defaultSetting.ini`. Keys: `enableexcel`, `enablecsv`, `delimiter`, `columns`, `outputfile`.

**Logging**: Date-stamped log file (`excel_parser_YYYYMMDD`) created in the working directory at startup via `logging.basicConfig`.

### shell_to_python_migration

Python rewrite of Oracle/shell ETL jobs. `ascena_mass_tsf_cre.py` follows a pattern:
1. `init()` — sets globals from environment variables (`$IN`, `$MMHOME`, `$ARCHIVE_IN`, `$REJECT`) and reads `app.Config` for the Oracle connection string.
2. `logon()` — connects via `cx_Oracle` using the connection string from `app.Config`.
3. Scans the working directory for files matching a regex pattern, validates each with `check_files()`, then processes.

`app.Config` holds the Oracle DSN under `[appSettings] → connectionString`.

### regularexpressions

Standalone learning/utility scripts. Notable:
- `files/readingFixedLengthFile.py` — `FileHandling` class with fixed-width positional parsing (field offsets hardcoded); raises `InvalidDataFormat` if the record type header is not `FHEAD`.
- `makeConnection.py` — `DB` class wrapping `cx_Oracle`; connection string is assembled from a `CONN_INFO` dict at module level (credentials are placeholders).

## Key Dependencies

| Package | Used in |
|---|---|
| `cx_Oracle` | `organize_files.py`, `regularexpressions/`, `shell_to_python_migration/` |
| `openpyxl` | `excelUploadApp/`, `openpyxl/` |
| `PyQt5` | `excelUploadApp/` |
| `pyperclip` | `regularexpressions/phoneNumberemailAddressExtractor.py` |

## Conventions

- **INI config via `configparser`**: Section names are `[Coreappsetting]` (excelUploadApp) and `[appSettings]` (shell migration). Values are read with typed getters (`getboolean`, `get`).
- **Logging pattern**: All non-trivial scripts configure `logging.basicConfig` with a file handler, `DEBUG` level, and a format including `%(filename)s`, `%(funcName)s`, `%(lineno)d`.
- **Oracle connections**: Connection strings come from config files or environment variables — never hardcoded in production scripts (though some learning scripts contain placeholder credentials).
- **Windows paths**: Several scripts contain hardcoded `C:\Users\alaskar\...` paths from the original development environment; update these before running on a different machine.
