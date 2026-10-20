page 80003 "Issues GHP"
{
    AdditionalSearchTerms = 'GitHub Projects, GitHub issues';
    ApplicationArea = All;
    Caption = 'Issues';
    Editable = false;
    PageType = List;
    SourceTable = "Issue GHP";
    SourceTableView = sorting("Base URL Code", "Repository Id", Number);
    UsageCategory = Lists;

    layout
    {
        area(Content)
        {
            repeater(Issues)
            {
                field("Base URL Code"; Rec."Base URL Code") { Visible = false; }
                field("Source Type"; Rec."Source Type") { Visible = false; }
                field("Repository Name"; Rec."Repository Name") { }
                field(Number; Rec.Number) { }
                field(Description; Rec.Description) { }
                field(State; Rec.State) { }
                field(Type; Rec.Type) { }
            }
        }
    }
}
