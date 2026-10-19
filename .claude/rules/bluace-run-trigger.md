# Bluace: Always Specify RunTrigger

Record writes always state whether triggers run, so the choice is visible and deliberate.

## Rule 1: Pass RunTrigger explicitly on every write

### Intent
Every `Insert`, `Modify`, `Rename`, `Delete`, `DeleteAll` and `ModifyAll` call passes the `RunTrigger` parameter explicitly, in application code and in test code. Never rely on the default.

- Default to `true`, so table triggers, table extension triggers and other extensions' event subscribers run.
- Use `false` only on purpose, with a comment that explains why (for example to bypass checks in test data setup).
- Temporary records are the exception to the default: write them with `false` (e.g. `TempSalesInvoiceHeader.Insert(false)`), because table triggers and validation must not run on temporary record variables (ALCops PC0027). Still pass the parameter explicitly.
- `ModifyAll` takes the parameter as its third argument: `ModifyAll(Field, Value, true)`.
- `Rename` has no `RunTrigger` parameter; its only parameters are the new primary key values (`Record.Rename(Value1 [, Value2, ...])`, see [Record.Rename](https://learn.microsoft.com/dynamics365/business-central/dev-itpro/developer/methods-auto/record/record-rename-method)). A rename does not call `OnModify`, so use `Rename` and `Modify(true)` separately when both are needed.

### Examples

```al
// Good example
PaymentLink.Insert(true);
PaymentLink.Modify(true);
PaymentLink.DeleteAll(true);
PaymentMethod.ModifyAll("Mollie Payment Links MPTE", false, true);

// Without triggers, like standard Codeunit "Sales-Get Shipment" deletes its temporary invoice headers.
TempSalesInvoiceHeader.Delete(false);
```

```al
// Bad example (avoid relying on the default)
PaymentLink.Insert();
PaymentLink.Modify();
PaymentLink.DeleteAll();
PaymentMethod.ModifyAll("Mollie Payment Links MPTE", false);
```
