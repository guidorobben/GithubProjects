table 80003 "Issue GHP"
{
    AllowInCustomizations = AsReadOnly;
    Caption = 'Issue';
    DataClassification = CustomerContent;
    DrillDownPageId = "Issues GHP";
    LookupPageId = "Issues GHP";

    fields
    {
        field(1; "Base URL Code"; Code[20])
        {
            Caption = 'Base URL Code';
            NotBlank = true;
            TableRelation = "Base URL GHP";
            ToolTip = 'Specifies the base URL the issue was retrieved from.';
        }
        field(2; Id; BigInteger)
        {
            Caption = 'Id';
            ToolTip = 'Specifies the id of the issue in GitHub, or of the work item in Azure DevOps.';
        }
        field(3; "Source Type"; Enum "Source Type GHP")
        {
            Caption = 'Source Type';
            ToolTip = 'Specifies whether the issue comes from GitHub or Azure DevOps.';
        }
        field(4; "Repository Id"; Code[50])
        {
            Caption = 'Repository Id';
            TableRelation = "Repository GHP".Id where("Base URL Code" = field("Base URL Code"));
            ToolTip = 'Specifies the id of the repository or project the issue belongs to.';
        }
        field(5; Number; Integer)
        {
            Caption = 'Number';
            ToolTip = 'Specifies the number of the issue in its repository, as in #123.';
        }
        field(6; Type; Enum "Issue Type GHP")
        {
            Caption = 'Type';
            ToolTip = 'Specifies whether this is a GitHub issue, an Azure DevOps user story or an Azure DevOps task.';
        }
        field(7; Description; Text[256])
        {
            Caption = 'Description';
            ToolTip = 'Specifies the title of the issue.';
        }
        field(8; State; Enum "Issue State GHP")
        {
            Caption = 'State';
            ToolTip = 'Specifies whether the issue is open or closed.';
        }
        field(9; "Parent Id"; BigInteger)
        {
            Caption = 'Parent Id';
            ToolTip = 'Specifies the id of the parent work item in Azure DevOps. It is 0 when there is none.';
        }
        field(10; "Parent Description"; Text[256])
        {
            CalcFormula = lookup("Issue GHP".Description where("Base URL Code" = field("Base URL Code"), Id = field("Parent Id")));
            Caption = 'Parent Description';
            Editable = false;
            FieldClass = FlowField;
            ToolTip = 'Specifies the title of the parent work item.';
        }
        field(11; "Tree Root Id"; BigInteger)
        {
            Caption = 'Tree Root Id';
            ToolTip = 'Specifies the work item under which this line is shown in the tree.';
        }
        field(12; Indentation; Integer)
        {
            Caption = 'Indentation';
            ToolTip = 'Specifies the level of the line in the tree.';
        }
        field(20; "Repository Name"; Text[100])
        {
            CalcFormula = lookup("Repository GHP".Name where("Base URL Code" = field("Base URL Code"), Id = field("Repository Id")));
            Caption = 'Repository Name';
            Editable = false;
            FieldClass = FlowField;
            ToolTip = 'Specifies the name of the repository the issue belongs to.';
        }
    }

    keys
    {
        key(PK; "Base URL Code", Id)
        {
            Clustered = true;
        }
        key(RepositoryNumber; "Base URL Code", "Repository Id", Number)
        {
        }
        key(Tree; "Base URL Code", "Repository Id", "Tree Root Id", Indentation, Id)
        {
        }
    }
}
