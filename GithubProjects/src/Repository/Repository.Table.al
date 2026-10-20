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
}
