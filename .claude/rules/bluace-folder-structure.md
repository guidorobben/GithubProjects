# Bluace: Folder Structure

Objects are grouped by feature under `src/`, with two extra folders: `General` for everything that depends directly on another app, and `Reports` for reports and report extensions. This extends Rule 2 (Feature-Based Folder Organization) in `al-code-style.md`.

## Rule 1: Feature folders without number prefixes

### Intent
Folder names under `src/` describe the feature in PascalCase and have no number prefix. Numbered folders (`01-setup`, `99-permissionsets`) are an old way of working and are not used for new code.

- One folder per feature, containing that feature's own objects: tables, pages, enums, and the helper codeunits of its own tables (e.g. `Setup/`, `PaymentLink/`).
- `PermissionSets/` for permission sets.
- File names follow `<ObjectNameWithoutSuffix>.<ObjectType>.al` (see `al-naming-conventions.md`).

## Rule 2: General folder for everything that depends on another app

### Intent
`src/General/` holds all functionality that depends directly on another app (the Base Application or other dependencies):
- table extensions, page extensions and enum extensions (report extensions go in `Reports/`, see rule 3);
- the helper codeunits of those table extensions;
- all subscriber codeunits (`<publisher> Subscr. <suffix>`).

This keeps a clear border between the app's own features and the places where it hooks into other apps.

### Examples

```
// Good example
Mollie Integration/src/
├── General/
│   ├── EnvTriggerSubscr.Codeunit.al
│   ├── PaymentMethod.TableExt.al
│   ├── PaymentMethodHelper.Codeunit.al
│   ├── PaymentMethods.PageExt.al
│   ├── PostedSalesInvoice.PageExt.al
│   ├── SalesInvHeaderHelper.Codeunit.al
│   └── SalesInvoiceHeader.TableExt.al
├── PaymentLink/
│   ├── APIClient.Codeunit.al
│   ├── EnvironmentType.Enum.al
│   ├── PaymentLink.Table.al
│   ├── PaymentLinkHelper.Codeunit.al
│   └── PaymentLinks.Page.al
├── PermissionSets/
│   ├── Mollie.PermissionSet.al
│   └── MollieAdmin.PermissionSet.al
└── Setup/
    ├── Setup.Page.al
    ├── Setup.Table.al
    └── SetupHelper.Codeunit.al
```

```
// Bad example (avoid number prefixes and extensions mixed into feature folders)
src/
├── 01-setup/
│   ├── PaymentMethod.TableExt.al
│   └── Setup.Table.al
└── 99-permissionsets/
```

## Rule 3: Reports folder for reports and report extensions

### Intent
`src/Reports/` holds reports and report extensions, together with their helper codeunits and their layout files. A report extension gets a helper codeunit like a table extension does: the report extension only calls it, and the helper holds the logic.

Naming:
- A report extension is named after the base report, without the base app's suffix and with the app's own suffix: "Sales - Invoice PTE" extends "Sales - Invoice RBLC". Its helper codeunit has the same base name: "Sales - Invoice Helper PTE".
- A layout file has exactly the same name as its report or report extension file, with the layout extension, so both sort next to each other: `SalesInvoice.ReportExt.al` + `SalesInvoice.ReportExt.rdlc`, `MyReport.Report.al` + `MyReport.Report.rdlc`.

### Examples

```
// Good example
GithubProjects/src/
└── Reports/
    ├── SalesInvoice.ReportExt.al
    ├── SalesInvoice.ReportExt.rdlc
    └── SalesInvoiceHelper.Codeunit.al
```

## Rule 4: Test apps mirror the feature folders

### Intent
Test apps use the same feature folder names (`Setup/`, `PaymentLink/`, ...) for their test codeunits, plus `Common/` for shared libraries and mocks. Tests for objects in `General/` go in the feature folder whose behaviour they test.
