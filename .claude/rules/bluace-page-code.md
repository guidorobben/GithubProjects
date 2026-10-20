# Bluace: No Business Code on Pages

Pages only present data and pass user actions on to the table. All logic lives behind table or table extension procedures (see `bluace-helper-codeunits.md`), so it can be reused and tested without a page.

## Rule 1: Page triggers call table procedures

### Intent
Action triggers, field triggers (`OnDrillDown`, `OnValidate`, `OnLookup`) and page triggers (`OnOpenPage`, `OnAfterGetRecord`) call table or table extension procedures through `Rec` (or a record variable for a selection). They do not declare management or helper codeunits, and do not contain business rules, database writes or calls to external services.

What a page may still do itself is UI work only:
- `CurrPage.SetSelectionFilter(...)`, `CurrPage.Update(...)`, `CurrPage.Close()`;
- setting filters and filter groups on `Rec` (e.g. `FilterGroup(2)`), using a value returned by a table procedure;
- reading page-only variables (such as a masked input field) and passing them to a table procedure;
- setting page variables that control visibility or editability, using values returned by table procedures.

### Examples

```al
// Good example - the page only passes the action on
action(UpdateStatus)
{
    trigger OnAction()
    var
        PaymentLink: Record "Payment Link MPTE";
    begin
        CurrPage.SetSelectionFilter(PaymentLink);
        PaymentLink.RefreshLinks();
        CurrPage.Update(false);
    end;
}

field("Sales Invoice No."; Rec."Sales Invoice No.")
{
    trigger OnDrillDown()
    begin
        Rec.OpenSalesInvoice();
    end;
}

trigger OnOpenPage()
begin
    Rec.FilterGroup(2);
    Rec.SetRange("Environment Type", Rec.GetCurrentEnvironmentType());
    Rec.FilterGroup(0);
end;
```

```al
// Bad example (avoid codeunit variables and logic on the page)
trigger OnAction()
var
    PaymentLinkMgt: Codeunit "Payment Link Mgt. MPTE";
begin
    if Rec.Paid then
        Error(PaidLinkCannotBeArchivedErr);
    PaymentLinkMgt.ArchiveLink(Rec);
end;

local procedure OpenSalesInvoice()
var
    SalesInvoiceHeader: Record "Sales Invoice Header";
begin
    if SalesInvoiceHeader.Get(Rec."Sales Invoice No.") then
        Page.Run(Page::"Posted Sales Invoice", SalesInvoiceHeader);
end;
```

## Rule 2: Page extensions follow the same rule

### Intent
Page extensions also call table extension procedures instead of containing code. Their own procedures and global variables carry the app suffix (`...GHP` in GithubProjects; `...MPTE` in the Mollie Integration examples). Prefer `RunObject` with `RunPageLink` for actions that only open another page.

### Examples

```al
// Good example - no code needed
action(MolliePaymentLinksMPTE)
{
    Caption = 'Mollie Payment Links';
    RunObject = page "Payment Links MPTE";
    RunPageLink = "Sales Invoice No." = field("No.");
}
```
