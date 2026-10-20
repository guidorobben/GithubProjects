# Bluace: Table Procedures and Helper Codeunits

Business logic is reached through table and table extension procedures, and implemented in a helper codeunit per table. This keeps one obvious entry point per piece of logic (`Rec.ProcedureName()`), and separates the definition (on the table) from the implementation (in the codeunit).

## Rule 1: No management codeunits; logic is reached through the table

### Intent
Do not create "Mgt."/"Management" codeunits that callers use directly. Every procedure a caller needs (pages, other helpers, reports, tests) is declared on the table or table extension it belongs to, and called as `Rec.ProcedureName(...)` or `MyRecord.ProcedureName(...)`. This also applies to small UI helpers, such as opening a related document.

### Examples

```al
// Good example - the caller uses the table procedure
PaymentLink.CreateLinkForInvoice(InvoiceNo);
Rec.ArchiveLink();
Rec.OpenSalesInvoice();
```

```al
// Bad example (avoid calling a management codeunit directly)
PaymentLinkMgt.CreateLinkForInvoice(InvoiceNo);
PaymentLinkMgt.ArchiveLink(Rec);
```

## Rule 2: The table only defines; a helper codeunit implements

### Intent
A table or table extension procedure contains no logic. It calls the procedure with the same name on a helper codeunit, held in a global variable, and passes `Rec` by `var` when the record is needed. Field triggers (`OnValidate`, `OnAfterValidate` in `modify`) also call the helper. The helper codeunit holds the implementation, its labels and its `Permissions`.

- Name: `<Table name> Helper <suffix>`, e.g. "Payment Link Helper MPTE", "Setup Helper MPTE", "Payment Method Helper MPTE". Abbreviate the table name when the 30-character limit is reached (e.g. "Sales Inv. Header Helper MPTE").
- One helper codeunit per table or table extension.
- Within the helper, procedures call each other directly (not through the table), so state such as an API client instance is shared within one action.
- The helper is `Access = Internal`, unless another app must call it.
- Data that is not protected by table permissions, such as values in Isolated Storage, needs an explicit permission check in the helper (e.g. `WritePermission()` on the related setup table). Do not rely on execute permission of a page: users usually get execute on all pages through standard permission sets (verified in BC 29 with D365 BUS FULL ACCESS).

### Examples

```al
// Good example - definition on the table
table 90151 "Payment Link MPTE"
{
    // fields, keys ...

    var
        PaymentLinkHelper: Codeunit "Payment Link Helper MPTE";

    procedure ArchiveLink()
    begin
        PaymentLinkHelper.ArchiveLink(Rec);
    end;
}

// Good example - implementation in the helper
codeunit 90151 "Payment Link Helper MPTE"
{
    Access = Internal;

    var
        PaidLinkCannotBeArchivedErr: Label 'Payment link %1 cannot be archived because it has been paid.', Comment = '%1 = Mollie payment link id';

    procedure ArchiveLink(var PaymentLink: Record "Payment Link MPTE")
    begin
        // implementation
    end;
}
```

```al
// Bad example (avoid implementation code on the table)
procedure ArchiveLink()
begin
    if Rec.Paid then
        Error(PaidLinkCannotBeArchivedErr, Rec.Id);
    // ... more logic on the table
end;
```

## Rule 3: Suffix on table and page extension members

### Intent
Procedures and global variables in table extensions and page extensions carry the app suffix ("GHP" in GithubProjects; the examples below use "MPTE" from Mollie Integration), so they cannot collide with members of other extensions of the same base object. The app's own tables do not need suffixed members.

How field changes of an extended table are handled is described in `bluace-table-triggers.md`; how records are written in `bluace-run-trigger.md`.

### Examples

```al
// Good example - suffixed members, implementation in the helper
tableextension 90150 "Payment Method MPTE" extends "Payment Method"
{
    var
        PaymentMethodHelperMPTE: Codeunit "Payment Method Helper MPTE";

    local procedure CheckBalAccountNotUsedMPTE()
    begin
        PaymentMethodHelperMPTE.CheckBalAccountNotUsed(Rec);
    end;
}
```

```al
// Bad example (avoid unsuffixed members in extensions)
tableextension 90150 "Payment Method MPTE" extends "Payment Method"
{
    var
        PaymentMethodHelper: Codeunit "Payment Method Helper MPTE";

    local procedure CheckBalAccountNotUsed()
    begin
        PaymentMethodHelper.CheckBalAccountNotUsed(Rec);
    end;
}
```
