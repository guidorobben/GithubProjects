page 80001 "Owners GHP"
{
    AdditionalSearchTerms = 'GitHub Projects, GitHub owners, organizations';
    ApplicationArea = All;
    Caption = 'Owners';
    DelayedInsert = true;
    PageType = List;
    SourceTable = "Owner GHP";
    UsageCategory = Lists;

    layout
    {
        area(Content)
        {
            repeater(Owners)
            {
                field("Base URL Code"; Rec."Base URL Code") { }
                field(Name; Rec.Name) { }
                field("Owner Type"; Rec."Owner Type") { }
                field("Repository Sync"; Rec."Repository Sync") { }
                field("No. of Repositories"; Rec."No. of Repositories") { }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(UpdateRepositories)
            {
                Caption = 'Update Repositories';
                Image = Refresh;
                ToolTip = 'Retrieve the repositories of the selected owners from GitHub. New repositories are added, changed ones are updated and repositories that GitHub no longer returns are deleted.';

                trigger OnAction()
                var
                    Owner: Record "Owner GHP";
                begin
                    CurrPage.SetSelectionFilter(Owner);
                    Owner.UpdateRepositories();
                    CurrPage.Update(false);
                end;
            }
        }
        area(Navigation)
        {
            action(Repositories)
            {
                Caption = 'Repositories';
                Image = List;
                RunObject = page "Repositories GHP";
                RunPageLink = "Base URL Code" = field("Base URL Code"), Owner = field(Name);
                ToolTip = 'View the stored repositories of the owner.';
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';

                actionref(UpdateRepositories_Promoted; UpdateRepositories) { }
                actionref(Repositories_Promoted; Repositories) { }
            }
        }
    }
}
