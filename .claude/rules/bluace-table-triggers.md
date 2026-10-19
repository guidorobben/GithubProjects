# Bluace: Table Extension Triggers Before Event Subscribers

When the app reacts to changes of a table it extends, it uses triggers in its table extension, not event subscribers on that table in a separate codeunit. This keeps the reaction next to the table it belongs to, and the implementation in the table's helper codeunit (see `bluace-helper-codeunits.md`).

## Rule 1: Prefer table extension triggers over table event subscribers

### Intent
To react to a field change or a record change of a base table, extend the table (or use the existing table extension) and use its triggers:
- `modify("Field") { trigger OnBeforeValidate() / OnAfterValidate() }` instead of a subscriber to `OnBeforeValidateEvent` / `OnAfterValidateEvent`;
- the table extension's `OnInsert`, `OnModify`, `OnDelete`, `OnRename` (and their `OnBefore...`/`OnAfter...` variants) instead of subscribers to `OnBeforeInsertEvent`, `OnAfterDeleteEvent` and so on.

The trigger only calls a suffixed table extension procedure, which calls the helper codeunit.

Be aware of when table extension triggers run:
- `OnInsert`/`OnModify`/`OnDelete`/`OnRename` of a table extension only run when the base operation runs its triggers (`Insert(true)`, `Delete(true)`, ...). Verified in BC 29: the table extension `OnBeforeDelete` did not run for `Delete(false)`/`DeleteAll(false)`. When a scenario must also cover writes without triggers, check whether that happens in standard code before choosing a subscriber instead.
- Triggers also run for temporary records. Let the helper exit when `IsTemporary()` is true, and pass the record `var` so the temporary state is kept.

### Examples

```al
// Good example - field trigger in the table extension
tableextension 90150 "Payment Method MPTE" extends "Payment Method"
{
    fields
    {
        modify("Bal. Account No.")
        {
            trigger OnAfterValidate()
            begin
                CheckBalAccountNotUsedMPTE();
            end;
        }
    }
}

// Good example - record trigger in the table extension
tableextension 90151 "Sales Invoice Header MPTE" extends "Sales Invoice Header"
{
    trigger OnDelete()
    begin
        DeleteLinksOfInvoiceMPTE();
    end;
}
```

```al
// Bad example (avoid a subscriber codeunit for a table the app can extend)
codeunit 90152 "Payment Method Subscr. MPTE"
{
    [EventSubscriber(ObjectType::Table, Database::"Payment Method", OnAfterValidateEvent, "Bal. Account No.", false, false)]
    local procedure CheckOnAfterValidateBalAccountNo(var Rec: Record "Payment Method")
    begin
        // ...
    end;
}
```

## Rule 2: Remaining subscribers: one codeunit per publisher

### Intent
Event subscribers are still used for events that are not table triggers of an extended table, such as integration events and codeunit events (e.g. `OnAfterCopyEnvironmentPerCompany` of Codeunit "Environment Triggers"). Put them in a separate codeunit per publisher object, never in one shared "...Subscribers" codeunit.

- Name: `<publisher object name> Subscr. <suffix>`, abbreviated when the 30-character limit is reached (e.g. "Env. Trigger Subscr. MPTE").
- Folder: `src/General/` (see `bluace-folder-structure.md`).
- Subscriber parameter names must match the publisher's (e.g. `var Rec`); that is required for binding.

### Examples

```al
// Good example
codeunit 90154 "Env. Trigger Subscr. MPTE"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Environment Triggers", OnAfterCopyEnvironmentPerCompany, '', false, false)]
    local procedure DeleteApiTokenOnAfterCopyEnvironmentPerCompany()
    var
        MollieSetup: Record "Setup MPTE";
    begin
        MollieSetup.DeleteApiToken();
    end;
}
```
