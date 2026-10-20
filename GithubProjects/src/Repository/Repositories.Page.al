page 80002 "Repositories GHP"
{
    AdditionalSearchTerms = 'GitHub Projects, GitHub repositories';
    ApplicationArea = All;
    Caption = 'Repositories';
    DeleteAllowed = true;
    InsertAllowed = false;
    PageType = List;
    SourceTable = "Repository GHP";
    SourceTableView = sorting("Base URL Code", Owner, Name);
    UsageCategory = Lists;

    layout
    {
        area(Content)
        {
            repeater(Repositories)
            {
                field("Base URL Code"; Rec."Base URL Code") { Editable = false; Visible = false; }
                field("Source Type"; Rec."Source Type") { Editable = false; Visible = true; }
                field(Owner; Rec.Owner) { Editable = false; Visible = false; }
                field(Name; Rec.Name) { Editable = false; }
                field("Issues Enabled"; Rec."Issues Enabled") { Editable = false; }
                field("Issue Sync"; Rec."Issue Sync") { }
            }
        }
    }
}
