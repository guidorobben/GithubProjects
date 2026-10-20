table 80002 "Repository GHP"
{
    AllowInCustomizations = AsReadOnly;
    Caption = 'Repository';
    DataClassification = CustomerContent;
    DrillDownPageId = "Repositories GHP";
    LookupPageId = "Repositories GHP";

    fields
    {
        field(1; "Base URL Code"; Code[20])
        {
            Caption = 'Base URL Code';
            NotBlank = true;
            TableRelation = "Base URL GHP";
            ToolTip = 'Specifies the base URL the repository was retrieved from.';
        }
        field(2; Id; Code[50])
        {
            Caption = 'Id';
            NotBlank = true;
            ToolTip = 'Specifies the id of the repository in GitHub.';
        }
        field(3; "Source Type"; Enum "Source Type GHP")
        {
            Caption = 'Source Type';
            ToolTip = 'Specifies whether the repository comes from GitHub or Azure DevOps.';
        }
        field(4; Owner; Text[100])
        {
            Caption = 'Owner';
            TableRelation = "Owner GHP".Name where("Base URL Code" = field("Base URL Code"));
            ToolTip = 'Specifies the GitHub user or organization the repository was retrieved for.';
        }
        field(5; Name; Text[100])
        {
            Caption = 'Name';
            ToolTip = 'Specifies the name of the repository.';
        }
        field(6; "Issues Enabled"; Boolean)
        {
            Caption = 'Issues Enabled';
            ToolTip = 'Specifies whether issues are turned on for the repository in GitHub.';
        }
        field(7; "Issue Sync"; Enum "Issue Sync GHP")
        {
            Caption = 'Issue Sync';
            InitValue = Include;
            ToolTip = 'Specifies whether issues are retrieved for the repository. Retrieving repositories again does not change this choice.';
        }
        field(8; "No. of Issues"; Integer)
        {
            CalcFormula = count("Issue GHP" where("Base URL Code" = field("Base URL Code"), "Repository Id" = field(Id)));
            Caption = 'No. of Issues';
            Editable = false;
            FieldClass = FlowField;
            ToolTip = 'Specifies how many issues of the repository are stored.';
        }
        field(9; Fork; Boolean)
        {
            Caption = 'Fork';
            ToolTip = 'Specifies whether the repository is a fork of another repository in GitHub. A fork that is retrieved for the first time gets Issue Sync set to Ignore.';
        }
    }

    keys
    {
        key(PK; "Base URL Code", Id)
        {
            Clustered = true;
        }
        key(OwnerName; "Base URL Code", Owner, Name)
        {
        }
    }

    trigger OnDelete()
    begin
        RepositoryHelper.DeleteIssues(Rec);
    end;

    var
        RepositoryHelper: Codeunit "Repository Helper GHP";

    /// <summary>
    /// Retrieves the issues of all repositories in the current filter from GitHub. Repositories that are not eligible are skipped.
    /// </summary>
    procedure UpdateIssues()
    begin
        RepositoryHelper.UpdateIssues(Rec);
    end;

    /// <summary>
    /// Asks for confirmation and deletes the stored issues of all repositories in the current filter.
    /// </summary>
    procedure DeleteIssuesWithConfirmation()
    begin
        RepositoryHelper.DeleteIssuesWithConfirmation(Rec);
    end;
}
