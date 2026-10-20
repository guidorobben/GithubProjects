page 80002 "Repositories GHP"
{
    AdditionalSearchTerms = 'GitHub Projects, GitHub repositories';
    ApplicationArea = All;
    Caption = 'Repositories';
    DeleteAllowed = true;
    InsertAllowed = false;
    RefreshOnActivate = true;
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
                field(Fork; Rec.Fork) { Editable = false; }
                field("Issues Enabled"; Rec."Issues Enabled") { Editable = false; }
                field("Issue Sync"; Rec."Issue Sync") { }
                field("No. of Issues"; Rec."No. of Issues") { }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(UpdateIssues)
            {
                Caption = 'Update Issues';
                Image = Refresh;
                ToolTip = 'Retrieve the issues of the selected repositories from GitHub. Repositories set to Ignore, with issues turned off, or of an owner set to Ignore are skipped.';

                trigger OnAction()
                var
                    Repository: Record "Repository GHP";
                begin
                    CurrPage.SetSelectionFilter(Repository);
                    Repository.UpdateIssues();
                    CurrPage.Update(false);
                end;
            }
            action(DeleteIssues)
            {
                Caption = 'Delete Issues';
                Image = Delete;
                ToolTip = 'Delete the stored issues of the selected repositories. The repositories themselves are kept.';

                trigger OnAction()
                var
                    Repository: Record "Repository GHP";
                begin
                    CurrPage.SetSelectionFilter(Repository);
                    Repository.DeleteIssuesWithConfirmation();
                    CurrPage.Update(false);
                end;
            }
        }
        area(Navigation)
        {
            action(Issues)
            {
                Caption = 'Issues';
                Image = List;
                RunObject = page "Issues GHP";
                RunPageLink = "Base URL Code" = field("Base URL Code"), "Repository Id" = field(Id);
                ToolTip = 'View the stored issues of the repository.';
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';

                actionref(UpdateIssues_Promoted; UpdateIssues) { }
                actionref(DeleteIssues_Promoted; DeleteIssues) { }
                actionref(Issues_Promoted; Issues) { }
            }
        }
    }
}
